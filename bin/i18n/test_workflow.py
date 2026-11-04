"""Real gettext/CLI checks; separate Poedit GUI evidence qualifies the editor workflow."""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import catalog
import pack
import workflow
from catalog_format import json_bytes

TOOLS = Path(__file__).resolve().parent


class WorkflowTests(unittest.TestCase):
    """Exercise separate workspaces and ready artifacts without source mutation."""

    def setUp(self):
        # unittest cleanup also runs after an assertion or command failure.
        # pylint: disable=consider-using-with
        temporary = tempfile.TemporaryDirectory(prefix="sgn-i18n-workflow-test-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.origin = self.root / "supplied"
        self.origin.mkdir()
        self.messages = [
            {"context": "trial.name", "source": "Trial name", "plural": None, "references": ["trial.js:1"]},
            {
                "context": "trial.count",
                "source": "%{count} trial",
                "plural": "%{count} trials",
                "references": ["trial.js:2"],
            },
        ]
        self.release = {
            "schema": 1,
            "api": 1,
            "domain": "sgn",
            "applicationVersion": "synthetic-release-v1",
            "sourceRevision": catalog.source_revision(self.messages),
            "messages": self.messages,
            "partitions": {"common": [0], "trials": [1]},
        }
        self.release_file = self.origin / "release.json"
        self.release_file.write_bytes(json_bytes(self.release))
        self.po = self.origin / "arbitrary-original-name.po"
        text = "# Original fixture license notice\n" + catalog.init_po(
            self.messages, "uk", "ltr", "nplurals=3; plural=(n==1 ? 0 : n==2 ? 1 : 2);", "Українська"
        )
        text = text.replace('msgid "Trial name"\nmsgstr ""', 'msgid "Trial name"\nmsgstr "uk: name"')
        text = text.replace(
            'msgstr[0] ""\nmsgstr[1] ""\nmsgstr[2] ""',
            'msgstr[0] "%{count} alpha"\nmsgstr[1] "%{count} beta"\nmsgstr[2] "%{count} gamma"',
        )
        self.po.write_text(text, encoding="utf-8")
        (self.origin / "NOTICE.txt").write_text("Owned synthetic attribution\n")
        commands = self.root / "gettext-only"
        commands.mkdir()
        for name in ("msgcat", "msgfmt", "msgmerge"):
            executable = shutil.which(name)
            self.assertIsNotNone(executable, "GNU gettext is required for workflow tests: " + name)
            (commands / name).symlink_to(executable)
        self.env = {**os.environ, "PATH": str(commands), "PYTHONDONTWRITEBYTECODE": "1"}

    def command(self, *args, ok=True, env=None, script=None):
        """Run an actual isolated command with no Node, Perl or R in PATH."""
        result = subprocess.run(
            [sys.executable, "-B", str(script or TOOLS / "workflow.py"), *map(str, args)],
            cwd=self.root,
            env=env or self.env,
            capture_output=True,
            text=True,
            check=False,
            timeout=40,
        )
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return json.loads(result.stdout) if ok else result.stderr

    def prepare(self, name="workspace"):
        """Prepare a frozen workspace from an external, arbitrarily named PO."""
        target = self.root / name
        receipt = self.command("prepare", "--release", self.release_file, "--po", self.po, "--output", target)
        self.assertEqual(receipt["locales"], ["uk"])
        return target

    def assert_no_stage(self):
        """A failed command cannot leave a publishable-looking partial folder."""
        self.assertEqual(list(self.root.glob(".sgn-i18n-*")), [])

    def test_frozen_prepare_and_package_work_after_source_inputs_are_deleted(self):
        """Build real ready packs with copied tools, gettext only and unchanged source bytes."""
        original_po = self.po.read_bytes()
        original_release = self.release_file.read_bytes()
        workspace = self.prepare()
        self.assertEqual(self.po.read_bytes(), original_po)
        self.assertEqual(self.release_file.read_bytes(), original_release)
        translated = workspace / "translations/uk.po"
        self.assertIn("Original fixture license notice", translated.read_text())
        self.assertNotIn("Generated; do not edit", translated.read_text())
        self.assertIn("Project-Id-Version: SGN synthetic-release-v1", translated.read_text())
        self.assertIn("Edit msgstr text", translated.read_text())
        self.assertEqual((workspace / "notices/NOTICE.txt").read_text(), "Owned synthetic attribution\n")
        shutil.rmtree(self.origin)
        saved_po = translated.read_bytes()
        output = self.root / "ready"
        receipt = self.command(
            "package", "--workspace", workspace, "--output", output, script=workspace / "tools/workflow.py"
        )
        self.assertEqual(receipt["packages"][0]["locale"], "uk")
        self.assertEqual(receipt["coverage"], [{"locale": "uk", "translated": 2, "englishFallback": 0, "total": 2}])
        manifest, data = pack.validate_pack(output / "uk-pack")
        self.assertEqual(manifest["sourceRevision"], self.release["sourceRevision"])
        self.assertEqual(data["messages"]["trial.name\x04Trial name"]["forms"], ["uk: name"])
        self.assertEqual(translated.read_bytes(), saved_po)
        self.assertEqual((output / "translations/uk.po").read_bytes(), saved_po)
        self.assertEqual(set(p.name for p in (output / "operator-tools").iterdir()), set(workflow.OPERATOR_FILES))
        self.assertEqual((output / "notices/NOTICE.txt").read_text(), "Owned synthetic attribution\n")
        self.assertFalse(any(output.rglob(".sgn-i18n-store")))
        self.assertFalse((output / ".build").exists())
        self.assert_no_stage()

    def test_source_prepare_extracts_once_and_never_updates_the_source_po_or_pot(self):
        """Only source extraction is captured; GNU merge and workspace output are actual."""
        source = self.root / "source"
        original = source / "locale/uk/LC_MESSAGES/sgn.po"
        original.parent.mkdir(parents=True)
        original.write_bytes(self.po.read_bytes())
        old_template = source / "locale/sgn.pot"
        old_template.write_text("Preserved original source POT\n")
        output = self.root / "source-workspace"
        args = argparse.Namespace(
            release=None, root=source, po=None, application_version="source-commit-fixture", output=output
        )
        with patch.object(catalog, "source_messages", return_value=self.messages) as extraction:
            workflow.prepare(args)
        extraction.assert_called_once_with(source)
        self.assertEqual(original.read_bytes(), self.po.read_bytes())
        self.assertEqual(old_template.read_text(), "Preserved original source POT\n")
        snapshot = catalog.validate_release(json.loads((output / "release.json").read_text()))
        self.assertEqual(snapshot["applicationVersion"], "source-commit-fixture")
        self.assertEqual(snapshot["partitions"], {"common": [0, 1]})

    def test_prepare_refuses_existing_or_symlinked_output_and_duplicate_languages(self):
        """Existing work, link targets and original PO files remain untouched."""
        target = self.root / "existing"
        target.mkdir()
        (target / "keep.txt").write_text("Keep original\n")
        self.command("prepare", "--release", self.release_file, "--po", self.po, "--output", target, ok=False)
        self.assertEqual((target / "keep.txt").read_text(), "Keep original\n")
        link = self.root / "linked"
        link.symlink_to(self.root / "missing-target")
        self.command("prepare", "--release", self.release_file, "--po", self.po, "--output", link, ok=False)
        self.assertTrue(link.is_symlink())
        output = self.root / "duplicate"
        error = self.command(
            "prepare", "--release", self.release_file, "--po", self.po, "--po", self.po, "--output", output, ok=False
        )
        self.assertIn("More than one PO", error)
        self.assertFalse(output.exists())
        self.assert_no_stage()

    def test_existing_output_is_rejected_before_source_tools_run(self):
        """A repeated command does not spend minutes parsing a release it cannot write."""
        target = self.root / "already-here"
        target.mkdir()
        args = argparse.Namespace(
            release=None,
            root=self.origin,
            po=None,
            application_version="fixture-v1",
            output=target,
        )
        with patch.object(catalog, "source_messages", side_effect=AssertionError("must not extract")):
            with self.assertRaisesRegex(ValueError, "Output already exists"):
                workflow.prepare(args)

    def test_invalid_release_or_po_does_not_create_output(self):
        """Input validation happens before any complete output can be published."""
        bad_release = self.origin / "bad.json"
        bad_release.write_bytes(json_bytes({**self.release, "sourceRevision": "f" * 64}))
        output = self.root / "unwritten"
        self.command("prepare", "--release", bad_release, "--po", self.po, "--output", output, ok=False)
        self.assertFalse(output.exists())
        bad_po = self.origin / "bad.po"
        bad_po.write_text("This is not a PO file")
        self.command("prepare", "--release", self.release_file, "--po", bad_po, "--output", output, ok=False)
        self.assertFalse(output.exists())
        self.assert_no_stage()

    def test_package_placeholder_failure_cleans_staging_and_preserves_workspace(self):
        """Invalid saved wording cannot produce or overwrite an installable bundle."""
        workspace = self.prepare()
        po = workspace / "translations/uk.po"
        po.write_text(po.read_text().replace("%{count} beta", "%{different} beta"), encoding="utf-8")
        before = po.read_bytes()
        output = self.root / "bad-package"
        error = self.command("package", "--workspace", workspace, "--output", output, ok=False)
        self.assertIn("placeholder", error)
        self.assertFalse(output.exists())
        self.assertEqual(po.read_bytes(), before)
        self.assert_no_stage()

    def test_package_refuses_existing_output_and_detects_changed_frozen_template(self):
        """The frozen message contract and existing bundle are preserved."""
        workspace = self.prepare()
        output = self.root / "ready"
        self.command("package", "--workspace", workspace, "--output", output)
        before = (output / "uk-pack/manifest.json").read_bytes()
        self.command("package", "--workspace", workspace, "--output", output, ok=False)
        self.assertEqual((output / "uk-pack/manifest.json").read_bytes(), before)
        (workspace / "release.pot").write_text("Changed English source")
        self.command("package", "--workspace", workspace, "--output", self.root / "different", ok=False)
        self.assertFalse((self.root / "different").exists())
        self.assert_no_stage()

    def test_saved_input_changes_cannot_mismatch_package_and_provenance(self):
        """A later editor save is kept for the next build, not mixed into this bundle."""
        workspace = self.prepare()
        po = workspace / "translations/uk.po"
        before = po.read_bytes()
        release_before = (workspace / "release.json").read_bytes()
        original_run = subprocess.run

        def save_after_compilation(command, *arguments, **options):
            result = original_run(command, *arguments, check=options.pop("check", False), **options)
            if str(command[1]).endswith("catalog.py"):
                po.write_text(po.read_text().replace("uk: name", "uk: later save"), encoding="utf-8")
                changed = {**self.release, "applicationVersion": "saved-after-this-build"}
                (workspace / "release.json").write_bytes(json_bytes(changed))
            return result

        output = self.root / "snapshot-ready"
        with patch.object(workflow.subprocess, "run", side_effect=save_after_compilation):
            workflow.package(argparse.Namespace(workspace=workspace, output=output))
        self.assertNotEqual(po.read_bytes(), before)
        self.assertEqual((output / "translations/uk.po").read_bytes(), before)
        self.assertEqual((output / "release.json").read_bytes(), release_before)
        _, data = pack.validate_pack(output / "uk-pack")
        self.assertEqual(data["messages"]["trial.name\x04Trial name"]["forms"], ["uk: name"])


if __name__ == "__main__":
    unittest.main()
