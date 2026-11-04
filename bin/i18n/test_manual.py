#!/usr/bin/env python3
"""Protect scientific examples and canonical navigation in translated manuals."""

import collections
import re
import shutil
import subprocess
import tempfile
import unittest

# Test names state their contracts; raw source fixtures retain exact line layouts.
# pylint: disable=missing-function-docstring
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "docs/r_markdown_docs"
LANGUAGES = ("uk", "es", "ar")


def fenced_blocks(text):
    result, active, block = [], "", []
    for line in text.splitlines(keepends=True):
        marker = re.match(r"^\s*(`{3,}|~{3,})", line)
        if active:
            block.append(line)
            if marker and marker[1][0] == active[0] and len(marker[1]) >= len(active):
                result.append(block[0].rstrip() + "\n" + "".join(block[1:-1]) + block[-1].rstrip() + "\n")
                active, block = "", []
        elif marker:
            active, block = marker[1], [line]
    if active:
        raise ValueError("Unclosed Markdown code block")
    return result


def number_tokens(text):
    text = re.sub(r"^---\n.*?\n---\n", "", text, count=1, flags=re.S)
    text = re.sub(r"(?m)^(#{1,6}[^\n]+?)\s*\{[^}\n]*\}\s*$", r"\1", text)
    return collections.Counter(re.findall(r"\d+(?:\.\d+)?", text))


class ManualTranslationTests(unittest.TestCase):
    """Exercise the manual translation tests contracts."""

    @classmethod
    def setUpClass(cls):
        cls.chapters = re.findall(r'"([^"\n]+\.Rmd)"', (ROOT / "_bookdown.yml").read_text())

    def copies(self):
        for locale in LANGUAGES:
            for chapter in self.chapters:
                yield locale, chapter, (ROOT / chapter).read_text(), (ROOT / "i18n" / locale / chapter).read_text()

    @unittest.skipUnless(shutil.which("Rscript"), "Rscript not installed")
    def test_build_help_and_invalid_outputs_do_not_render_or_write(self):
        with tempfile.TemporaryDirectory() as temporary:
            scratch = Path(temporary)
            alias = scratch / "manual-link"
            alias.symlink_to(ROOT, target_is_directory=True)
            command = ["Rscript", "--vanilla", str(ROOT / "build.R")]
            result = subprocess.run(command + ["--help"], capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("/absolute/output", result.stdout)
            cases = [
                (["uk"], "Usage:"),
                (["uk", "relative-output"], "absolute path"),
                (["uk", str(ROOT / "generated")], "overlap"),
                (["uk", str(ROOT.parent)], "overlap"),
                (["uk", "/"], "overlap"),
                (["uk", str(alias / "generated")], "overlap"),
                (["uk", str(scratch / "missing" / ".." / "manual-link" / "generated")], "overlap"),
                (["uk", str(scratch / "output"), "bad-mode"], "split or single"),
                (["uk", str(scratch / "output"), "split", "extra"], "Usage:"),
            ]
            for args, error in cases:
                with self.subTest(args=args):
                    result = subprocess.run(command + args, capture_output=True, text=True, check=False)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(error, result.stderr)
            self.assertEqual(list(scratch.iterdir()), [alias])
            self.assertFalse((ROOT / "generated").exists())
            existing = scratch / "existing-reader"
            existing.mkdir()
            (existing / "index.html").write_text("Keep existing reader")
            result = subprocess.run(command + ["all", str(existing)], capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("choose a new output folder", result.stderr)
            self.assertEqual((existing / "index.html").read_text(), "Keep existing reader")

    def test_all_current_chapters_have_one_copy_per_language(self):
        self.assertTrue(self.chapters)
        for locale in LANGUAGES:
            self.assertEqual(
                sorted(p.name for p in (ROOT / "i18n" / locale).glob("*.Rmd")),
                sorted(self.chapters),
            )

    def test_scientific_code_and_file_field_examples_are_verbatim(self):
        for locale, chapter, original, translated in self.copies():
            with self.subTest(locale=locale, chapter=chapter):
                self.assertEqual(fenced_blocks(original), fenced_blocks(translated))

    def test_formulas_remain_verbatim(self):
        pattern = r"(?<!\\)\$\$[\s\S]*?(?<!\\)\$\$|(?<!\\)\$[^\n$]+(?<!\\)\$"
        for locale, chapter, original, translated in self.copies():
            with self.subTest(locale=locale, chapter=chapter):
                self.assertEqual(re.findall(pattern, original), re.findall(pattern, translated))

    def test_numeric_examples_remain_verbatim(self):
        for locale, chapter, original, translated in self.copies():
            with self.subTest(locale=locale, chapter=chapter):
                self.assertEqual(number_tokens(original), number_tokens(translated))

    def test_localized_heading_ids_preserve_one_navigation_contract(self):
        canonical = None
        for locale in LANGUAGES:
            ids = [
                value
                for chapter in self.chapters
                for value in re.findall(
                    r"(?m)^#{1,6}[^\n]*\{#([^}\s]+)[^}]*\}",
                    (ROOT / "i18n" / locale / chapter).read_text(),
                )
            ]
            self.assertTrue(ids)
            self.assertEqual(len(ids), len(set(ids)))
            if canonical is None:
                canonical = ids
            else:
                self.assertEqual(ids, canonical)


if __name__ == "__main__":
    unittest.main()
