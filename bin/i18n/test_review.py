"""Review exports retain context, attribution and original translator work."""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from catalog import init_po, source_revision


class ReviewTests(unittest.TestCase):
    """Exercise the public command with a frozen two-workflow release."""

    def test_workflow_export_is_separate_and_refuses_overwrite(self):
        """Keep whole messages and leave the original PO byte-identical."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            messages = [
                {"context": name, "source": source, "plural": None, "references": ["page.mas:1"]}
                for name, source in [("shared", "Save"), ("seedlots.name", "Seedlot name")]
            ]
            release = {
                "schema": 1,
                "api": 1,
                "domain": "sgn",
                "applicationVersion": "test-v1",
                "sourceRevision": source_revision(messages),
                "messages": messages,
                "partitions": {"common": [0], "seedlots": [1]},
            }
            (root / "release.json").write_text(json.dumps(release))
            po = root / "original.po"
            original = "# License attribution retained\n" + init_po(messages, "uk", "ltr", "nplurals=1; plural=0;")
            po.write_text(original)
            command = [
                sys.executable,
                str(Path(__file__).with_name("review.py")),
                "review",
                "--release",
                str(root / "release.json"),
                "--po",
                str(po),
                "--workflow",
                "seedlots",
                "--output",
                str(root / "review"),
            ]
            run = subprocess.run(command, capture_output=True, text=True, check=False)
            self.assertEqual(run.returncode, 0, run.stderr)
            output = (root / "review/review.po").read_text()
            self.assertIn('msgctxt "seedlots.name"', output)
            self.assertNotIn('msgctxt "shared"', output)
            self.assertIn("License attribution retained", output)
            self.assertEqual(po.read_text(), original)
            self.assertIn("test-v1", (root / "review/REVIEW.md").read_text())
            run = subprocess.run(command, capture_output=True, text=True, check=False)
            self.assertNotEqual(run.returncode, 0)
            self.assertEqual(po.read_text(), original)


if __name__ == "__main__":
    unittest.main()
