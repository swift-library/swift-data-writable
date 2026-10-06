# SPDX-License-Identifier: Apache-2.0 WITH Swift-exception
import json
from pathlib import Path
import re
import runpy
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]


class ConsumerEvidenceTests(unittest.TestCase):
    def test_local_manifest_resolves_package_without_exposing_checkout_path(self):
        fixtures = ROOT / ".build/test-fixtures"
        fixtures.mkdir(parents=True, exist_ok=True)
        consumer = runpy.run_path(str(ROOT / "Scripts/validate-consumer"))
        with tempfile.TemporaryDirectory(dir=fixtures) as temporary:
            output = Path(temporary) / "consumer"
            arguments = ["validate-consumer", "--local", "--output", str(output)]
            with patch("sys.argv", arguments), \
                    patch("subprocess.check_output", return_value='{"commit":"fixture","dirty":true}'), \
                    patch("subprocess.run", side_effect=RuntimeError("stop before compilation")):
                with self.assertRaisesRegex(RuntimeError, "stop before compilation"):
                    consumer["main"]()
            manifest = output / "package/Package.swift"
            text = manifest.read_text()
            dependency = re.search(r'path: ("[^"\n]*")', text)
            self.assertIsNotNone(dependency)
            path = Path(json.loads(dependency[1]))
            self.assertFalse(path.is_absolute())
            self.assertEqual((manifest.parent / path).resolve(), ROOT)
            self.assertNotIn(str(ROOT), text)


if __name__ == "__main__":
    unittest.main()
