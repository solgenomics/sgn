#!/usr/bin/env python3
"""R source-as-data, literal locations, privacy and explicit-gap regressions."""

import json
import os
import unittest

# Test names state their contracts; raw source fixtures retain exact line layouts.
# pylint: disable=missing-function-docstring
from types import SimpleNamespace
from unittest.mock import patch

from extract import ExtractionError
from inventory import r_candidates
from r_discovery import discover_r, source_position


class RDiscoveryTests(unittest.TestCase):
    """Exercise the r discovery tests contracts."""

    def parse(self, source, name="R/fixture.r"):
        return discover_r([{"file": name, "source": source}])[name]

    def test_real_parser_handles_raw_strings_unicode_tabs_multiline_and_comments(self):
        source = (
            '# "Comment is opaque"\nfirst <- "𝛂";\tmessage("Human label")\nraw <- r"(quote '
            '" and \' data)"\nmultiline <- "first\nsecond"\n'
        )
        row = self.parse(source)
        self.assertTrue(row["ok"])
        self.assertEqual(
            [record["value"] for record in row["records"]],
            ["𝛂", "Human label", "quote \" and ' data", "first\nsecond"],
        )
        for record in row["records"]:
            position = source_position(source, record["line"], record["column"])
            self.assertIn(source[position], '"r')
        self.assertEqual(
            source_position(source, row["records"][1]["line"], row["records"][1]["column"]),
            source.index('"Human label"'),
        )
        self.assertEqual(row["records"][-1]["line"], 4)

    def test_source_is_not_executed_or_resolved(self):
        source = 'stop("APPLICATION_SOURCE_EXECUTED"); library(package_that_does_not_exist); message("Human label")'
        row = self.parse(source)
        self.assertTrue(row["ok"])
        self.assertEqual(
            [record["value"] for record in row["records"]],
            ["APPLICATION_SOURCE_EXECUTED", "Human label"],
        )

    def test_sensitive_assignment_and_named_argument_values_never_leave_helper(self):
        source = (
            'password <- "suppressed assigned value"; dbConnect(user="public", '
            'password="suppressed argument", dbname="public database"); message("Human '
            'label")'
        )
        row = self.parse(source)
        sensitive = [record for record in row["records"] if record["sensitiveAssignment"]]
        self.assertEqual(len(sensitive), 2)
        self.assertTrue(all(record["value"] is None for record in sensitive))
        self.assertNotIn("suppressed", json.dumps(row))
        records, excluded = r_candidates("R/fixture.r", "a" * 64, source, row)
        self.assertEqual(excluded["sensitive_assignment_literal"], 2)
        self.assertTrue(any(record["text_excerpt"] == "Human label" for record in records))
        self.assertTrue(
            all(record["needs_review"] and not record["counts_as_coverage_denominator"] for record in records)
        )

    def test_reviewed_credential_call_protects_all_literal_subnodes(self):
        sentinel = "SENTINEL_CREDENTIAL_TOKEN"
        source = (
            'onaDownload("public identifier", "public folder", paste("'
            + sentinel
            + '", "suffix"), "'
            + sentinel
            + '"); message("Human label")'
        )
        row = self.parse(source)
        self.assertTrue(row["ok"])
        self.assertNotIn(sentinel, json.dumps(row))
        self.assertEqual(
            [record["value"] for record in row["records"] if not record["sensitiveAssignment"]],
            ["Human label"],
        )
        self.assertTrue(
            all(
                record["protectionReason"] == "external_credential_call_review"
                for record in row["records"]
                if record["sensitiveAssignment"]
            )
        )
        candidates, excluded = r_candidates("R/fixture.r", "a" * 64, source, row)
        self.assertEqual([candidate["text_excerpt"] for candidate in candidates], ["Human label"])
        self.assertEqual(excluded["credential_call_literal_review"], 5)
        invalid = self.parse(source + "; x <- (")
        self.assertFalse(invalid["ok"])
        self.assertNotIn(sentinel, json.dumps(invalid))

    def test_raw_helper_stderr_or_untrusted_error_text_cannot_enter_reports(self):
        sentinel = "SENTINEL_CREDENTIAL_TOKEN"
        with patch(
            "r_discovery.subprocess.run",
            return_value=SimpleNamespace(returncode=1, stdout="", stderr="source line: " + sentinel),
        ):
            with self.assertRaises(ExtractionError) as error:
                self.parse('message("Human label")')
        self.assertNotIn(sentinel, str(error.exception))
        bad = {
            "schema": 1,
            "parser": "R parseData",
            "parserVersion": "4.5.0",
            "jsonVersion": "2.0.0",
            "files": [
                {
                    "file": "R/fixture.r",
                    "ok": False,
                    "error": "bad source: " + sentinel,
                    "records": [],
                }
            ],
        }
        with patch(
            "r_discovery.subprocess.run",
            return_value=SimpleNamespace(returncode=0, stdout=json.dumps(bad), stderr=""),
        ):
            with self.assertRaises(ExtractionError) as error:
                self.parse('message("Human label")')
        self.assertNotIn(sentinel, str(error.exception))

    def test_syntax_errors_are_review_results_not_empty_success_or_source_dump(self):
        row = self.parse('password <- "do not echo this text"; x <- (')
        self.assertFalse(row["ok"])
        self.assertEqual(row["records"], [])
        self.assertEqual(row["error"], "R parser rejected source syntax")
        self.assertNotIn("do not echo", json.dumps(row))

    def test_both_r_spellings_keep_independent_file_identities(self):
        files = [
            {"file": "R/upper.R", "source": 'message("Upper message")'},
            {"file": "R/lower.r", "source": 'message("Lower message")'},
        ]
        rows = discover_r(files)
        self.assertEqual(set(rows), {"R/upper.R", "R/lower.r"})
        self.assertEqual(rows["R/upper.R"]["records"][0]["value"], "Upper message")
        self.assertEqual(rows["R/lower.r"]["records"][0]["value"], "Lower message")

    def test_source_mapping_does_not_split_unicode_separator_and_preserves_crlf(self):
        source = 'x <- "𝛂\u2028data";\ty <- "Second label"\r\nz <- "Third label"'
        row = self.parse(source)
        self.assertEqual(
            [source_position(source, record["line"], record["column"]) for record in row["records"]],
            [source.index('"𝛂'), source.index('"Second'), source.index('"Third')],
        )
        self.assertEqual([record["line"] for record in row["records"]], [1, 1, 2])

    def test_unavailable_or_invalid_argv_is_never_a_zero_record_fallback(self):
        for configured in [
            "Rscript helper.R",
            "[]",
            "[false]",
            '["nonexistent-R-discovery-command"]',
        ]:
            with (
                self.subTest(configured=configured),
                patch.dict(os.environ, {"SGN_I18N_R_DISCOVERY_COMMAND": configured}),
                self.assertRaises(ExtractionError),
            ):
                self.parse('message("Human text")')

    def test_incompatible_helper_and_bad_locations_fail_closed(self):
        good = {
            "schema": 1,
            "parser": "R parseData",
            "parserVersion": "4.5.0",
            "jsonVersion": "2.0.0",
            "files": [
                {
                    "file": "R/fixture.r",
                    "ok": True,
                    "records": [
                        {
                            "line": 1,
                            "column": 1,
                            "value": "Text",
                            "sensitiveAssignment": False,
                        }
                    ],
                }
            ],
        }
        for change in [
            ("schema", True),
            ("parserVersion", "unknown"),
            ("files", []),
            (
                "files",
                [
                    {
                        "file": "R/fixture.r",
                        "ok": True,
                        "records": [
                            {
                                "line": 99,
                                "column": 1,
                                "value": "Text",
                                "sensitiveAssignment": False,
                            }
                        ],
                    }
                ],
            ),
        ]:
            payload = {**good, change[0]: change[1]}
            with (
                self.subTest(change=change),
                patch(
                    "r_discovery.subprocess.run",
                    return_value=SimpleNamespace(returncode=0, stdout=json.dumps(payload), stderr=""),
                ),
                self.assertRaises(ExtractionError),
            ):
                self.parse('"Text"')
        with self.assertRaises(ExtractionError):
            source_position("text", 1, 999)


if __name__ == "__main__":
    unittest.main()
