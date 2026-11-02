#!/usr/bin/env python3
"""Protect scientific examples and canonical navigation in translated manuals."""

import collections
import re
import unittest

# Test names state their contracts; raw source fixtures retain exact line layouts.
# pylint: disable=missing-function-docstring
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "docs/r_markdown_docs"
LANGUAGES = ("uk", "es", "ar")


def fenced_blocks(text):
    result, active, block = [], None, []
    for line in text.splitlines(keepends=True):
        marker = re.match(r"^\s*(`{3,}|~{3,})", line)
        if active:
            block.append(line)
            if marker and marker[1][0] == active[0] and len(marker[1]) >= len(active):
                result.append(block[0].rstrip() + "\n" + "".join(block[1:-1]) + block[-1].rstrip() + "\n")
                active, block = None, []
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
