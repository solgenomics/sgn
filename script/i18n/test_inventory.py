#!/usr/bin/env python3
"""Meaningful pinned-source census, route uncertainty and evidence tests."""

import hashlib
import json
import subprocess
import tempfile
import unittest

# Test names state their contracts; raw source fixtures retain exact line layouts.
# pylint: disable=missing-function-docstring
from pathlib import Path
from unittest.mock import patch

from extract import ExtractionError
from inventory import audit, category, pot_messages, routes, scan_code


def command(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.DEVNULL).decode().strip()


class InventoryTests(unittest.TestCase):
    """Exercise the inventory tests contracts."""

    def fixture(self, root):
        command(root, "init", "-q")
        sources = {
            ("mason/page.mas"): (
                "<label>Trial name</label>\n<%init>\nmy "
                "$label=$c->i18n->p('trial.name','Trial name');\nmy $sql='SELECT name FROM "
                "project WHERE project_id=?';\n</%init>\n"
            ),
            ("lib/SGN/Controller/Test.pm"): (
                "package SGN::Controller::Test;\n__PACKAGE__->config(namespace=>'ajax');\nsub "
                "direct :Path('/native') :Args(0) { }\nsub relative :Path('trial') :Args(1) "
                "{ }\nsub dynamic :Path($route) { }\nsub chained :Chained('/') "
                ":PathPart('trial') :CaptureArgs(1) { }\nsub internal :Private { }\n"
            ),
            "cgi-bin/help.pl": "print 'User help';\n",
            "js/source/legacy/jquery/vendor.js": "alert('Vendor text');\n",
            "docs/help.md": "# Help for field trials\nTechnical body needs manual classification.\n",
            "sgn.conf": "dbpass example-only-never-a-candidate\n",
            "static/img/logo.png": b"\x89PNG\x00binary",
            "locale/sgn.pot": 'msgid ""\nmsgstr ""\n\nmsgctxt "trial.name"\nmsgid "Trial name"\nmsgstr ""\n',
        }
        for name, content in sources.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content if isinstance(content, bytes) else content.encode())
        command(root, "add", ".")
        command(
            root,
            "-c",
            "user.name=Inventory test",
            "-c",
            "user.email=inventory@example.invalid",
            "commit",
            "-qm",
            "fixture",
        )
        return command(root, "rev-parse", "HEAD"), sources

    def test_exact_special_mason_root_classification_and_markup_discovery(self):
        for path in ("mason/autohandler", "mason/site/error/dhandler"):
            self.assertEqual(category(path, "100644")[0], "mason_template")
        for path in (
            "script/autohandler",
            "assets/mason/dhandler",
            "mason/Autohandler",
            "features/example/mason/autohandler",
        ):
            self.assertEqual(category(path, "100644")[0], "asset")
        self.assertEqual(category("features/gbrowse2/mason/autohandler", "100644")[0], "vendor")
        text = "<button>Save</button>\n<%init>\nmy $label=$c->i18n->p('special.save','Save');\n</%init>\n"
        found, marks, _gaps, _ = scan_code("mason/search/autohandler", "a" * 64, text)
        self.assertTrue(any(row["kind"] == "markup_text" and row["text_excerpt"] == "Save" for row in found))
        self.assertEqual(marks[0]["line"], 3)
        self.assertEqual(marks[0]["context"], "special.save")
        self.assertTrue(all(row["counts_as_coverage_denominator"] is False for row in found))

    def test_pinned_r_spellings_have_ast_candidates_and_invalid_source_review(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            root.mkdir()
            _, _sources = self.fixture(root)
            added = {
                "R/upper.R": 'message("Upper human label")\n',
                "R/lower.r": 'message("Lower human label")\n',
                "R/invalid.r": 'password <- "not echoed"; x <- (\n',
            }
            for name, text in added.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
            command(root, "add", ".")
            command(
                root,
                "-c",
                "user.name=Inventory test",
                "-c",
                "user.email=inventory@example.invalid",
                "commit",
                "-qm",
                "R fixture",
            )
            revision = command(root, "rev-parse", "HEAD")
            (root / "R/lower.r").write_text("UNTRACKED WORKTREE CHANGE")
            report = Path(directory) / "report"
            summary = audit(root, revision, report)
            files = {row["path"]: row for row in map(json.loads, (report / "files.jsonl").read_text().splitlines())}
            candidates = list(map(json.loads, (report / "candidates.jsonl").read_text().splitlines()))
            self.assertEqual(files["R/lower.r"]["category"], "r_source")
            self.assertEqual(files["R/lower.r"]["scan_status"], "r_ast_literal_discovery_only")
            self.assertIsNone(files["R/lower.r"]["instrumented_occurrences"])
            self.assertEqual(files["R/invalid.r"]["scan_status"], "r_ast_parse_review")
            self.assertEqual(summary["R_discovery"]["parsed_files"], 2)
            self.assertEqual(summary["R_discovery"]["review_files"], 1)
            self.assertFalse(summary["R_discovery"]["marked_message_discovery_reconciled"])
            self.assertEqual(
                {row["text_excerpt"] for row in candidates if row["kind"] == "R_literal_string"},
                {"Upper human label", "Lower human label"},
            )
            self.assertTrue(all(row["line"] == 1 for row in candidates if row["kind"] == "R_literal_string"))
            self.assertNotIn("not echoed", (report / "gaps.jsonl").read_text())
            self.assertIsNone(summary["coverage_percentage"])

    def test_r_parser_unavailability_is_a_visible_gap_not_zero_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            root.mkdir()
            self.fixture(root)
            path = root / "R/lower.r"
            path.parent.mkdir()
            path.write_text('message("Human label")')
            command(root, "add", ".")
            command(
                root,
                "-c",
                "user.name=Inventory test",
                "-c",
                "user.email=inventory@example.invalid",
                "commit",
                "-qm",
                "R fixture",
            )
            report = Path(directory) / "report"
            with patch(
                "inventory.discover_r",
                side_effect=ExtractionError("qualified parser unavailable"),
            ):
                summary = audit(root, command(root, "rev-parse", "HEAD"), report)
            files = {row["path"]: row for row in map(json.loads, (report / "files.jsonl").read_text().splitlines())}
            self.assertEqual(files["R/lower.r"]["scan_status"], "r_ast_parser_review")
            self.assertIsNone(files["R/lower.r"]["instrumented_occurrences"])
            self.assertEqual(summary["R_discovery"]["parsed_files"], 0)
            self.assertEqual(summary["R_discovery"]["review_files"], 1)
            self.assertIn(
                "R_parser_unavailable_or_incompatible",
                (report / "gaps.jsonl").read_text(),
            )

    def test_pinned_census_ignores_dirty_files_and_hashes_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            root.mkdir()
            revision, sources = self.fixture(root)
            (root / "mason/page.mas").write_text("MUTATED uncommitted source")
            (root / "untracked.pm").write_text("untracked")
            report = Path(directory) / "report"
            summary = audit(root, revision, report)
            self.assertFalse(summary["working_tree_used"])
            self.assertEqual(summary["tracked_paths"], len(sources))
            files = [json.loads(line) for line in (report / "files.jsonl").read_text().splitlines()]
            binary = next(row for row in files if row["path"] == "static/img/logo.png")
            self.assertEqual(
                binary["content_sha256"],
                hashlib.sha256(sources["static/img/logo.png"]).hexdigest(),
            )
            marks = [json.loads(line) for line in (report / "instrumented.jsonl").read_text().splitlines()]
            self.assertEqual(marks[0]["source"], "Trial name")
            self.assertEqual(summary["instrumentation"]["recognized_source_occurrences"], 1)
            self.assertEqual(summary["instrumentation"]["unique_source_catalog_messages"], 1)
            self.assertIsNone(summary["coverage_percentage"])
            self.assertEqual(summary["workflow_qualification"], [])

    def test_deterministic_reports_and_no_overwrite_or_source_reports(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "repo"
            root.mkdir()
            revision, _ = self.fixture(root)
            first = Path(directory) / "first"
            second = Path(directory) / "second"
            audit(root, revision, first)
            audit(root, revision, second)
            self.assertEqual(
                {p.name: p.read_bytes() for p in first.iterdir()},
                {p.name: p.read_bytes() for p in second.iterdir()},
            )
            with self.assertRaisesRegex(ValueError, "nonempty"):
                audit(root, revision, first)
            with self.assertRaisesRegex(ValueError, "outside"):
                audit(root, revision, root / "report")

    def test_candidate_classification_preserves_single_word_labels_and_data_uncertainty(
        self,
    ):
        text = (
            "<button>Save</button><p>Trial SQ 2026</p>\n<%init>\nmy "
            "$a=$c->i18n->p('button.save','Save');\nmy $q='SELECT name FROM "
            "project';\n</%init>\n"
        )
        candidates, marked, _gaps, excluded = scan_code("mason/test.mas", "a" * 64, text)
        self.assertTrue(any(row["text_excerpt"] == "Save" for row in candidates))
        self.assertTrue(any(row["text_excerpt"] == "Trial SQ 2026" and row["needs_review"] for row in candidates))
        self.assertFalse(any("SELECT" in row["text_excerpt"] for row in candidates))
        self.assertEqual(excluded["sql_or_query_literal"], 1)
        self.assertEqual(len(marked), 1)
        self.assertTrue(all(row["counts_as_coverage_denominator"] is False for row in candidates))

    def test_routes_preserve_unresolved_dynamic_and_chained_actions(self):
        text = (
            "__PACKAGE__->config(namespace=>'ajax');\nsub one :Path('/one') :Args(0) "
            "{}\nsub relative :Path('trial') :Args(1) {}\nsub variable :Path($path) "
            "{}\nsub chain :Chained('/') :PathPart('child') :CaptureArgs(1) {}\nsub no "
            ":Private {}\n"
        )
        found = routes("lib/SGN/Controller/Test.pm", "a" * 64, text)
        by_action = {row["action"]: row for row in found}
        self.assertEqual(by_action["one"]["url_candidate"], "/one")
        self.assertEqual(by_action["relative"]["url_candidate"], "/ajax/trial")
        self.assertNotIn("url_candidate", by_action["variable"])
        self.assertEqual(by_action["chain"]["resolution"], "chain_resolution_requires_runtime")
        self.assertEqual(by_action["no"]["resolution"], "not_a_public_route")
        self.assertTrue(all(row["needs_review"] for row in found))
        unrelated = routes(
            "lib/SGN/Controller/Test.pm",
            "a" * 64,
            "sub relative :Path('trial') {}\nmy $data={namespace=>'data-value'};\n",
        )
        self.assertIsNone(unrelated[0]["namespace_literal"])
        self.assertNotIn("url_candidate", unrelated[0])

    def test_vendor_generated_features_and_parser_gaps_are_explicit(self):
        self.assertEqual(category("js/source/legacy/jquery/dataTables.js", "100644")[0], "vendor")
        self.assertEqual(category("js/source/legacy/CXGN/Trial.js", "100644")[0], "javascript_source")
        self.assertEqual(category("static/app.min.js", "100644")[0], "generated")
        self.assertEqual(category("features/example/mason/page.mas", "100644")[0], "mason_template")
        self.assertEqual(category("mason/i18n/prototype.mas", "100644")[0], "mason_template")
        _, _, gaps, _ = scan_code("lib/Test.pm", "a" * 64, "my $text=qq{Hello};\n")
        self.assertTrue(any(row["kind"] == "unsupported_quote_like_or_heredoc" for row in gaps))
        self.assertEqual(
            pot_messages('msgid ""\nmsgstr ""\n\nmsgctxt ""\nmsgid "Save"\nmsgstr ""\n'),
            [("", "Save", None)],
        )


if __name__ == "__main__":
    unittest.main()
