#!/usr/bin/env python3
"""Regression checks for the publication boundary; no app credentials required."""
import importlib.util
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("export_source", Path(__file__).with_name("export-source.py"))
exporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)


class PublicationBoundaryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name).resolve()
        self.old_root = exporter.ROOT
        exporter.ROOT = self.root
        (self.root / "scripts").mkdir()
        (self.root / "README.md").write_text("Public source fixture\n")

    def tearDown(self):
        exporter.ROOT = self.old_root
        self.temp.cleanup()

    def manifest(self, *names):
        (self.root / "scripts/public-files.txt").write_text("\n".join(names) + "\n")

    def test_forbidden_paths_rejected_even_if_manifest_is_changed(self):
        for name in ("Config/Local.xcconfig", "./Config/Local.xcconfig", "../outside",
                     "/absolute", ".git/config", "design/source.pen", ".env",
                     ".aws/credentials", "signing.p12", "secret.pem", "build/result.json"):
            with self.subTest(name=name):
                self.manifest(name)
                with self.assertRaises(ValueError):
                    exporter.approved_files()

    def test_symlink_and_duplicate_rejected(self):
        (self.root / "link.md").symlink_to(self.root / "README.md")
        self.manifest("link.md")
        with self.assertRaises(ValueError):
            exporter.approved_files()
        self.manifest("README.md", "README.md")
        with self.assertRaises(ValueError):
            exporter.approved_files()

    def test_export_is_reproducible_and_includes_only_approved_files(self):
        (self.root / "private.txt").write_text("Excluded test fixture")
        self.manifest("README.md")
        first, second = self.root / "one", self.root / "two"
        exporter.export(first)
        exporter.export(second)
        self.assertEqual((first / "bulb-assist-source.tar.gz").read_bytes(),
                         (second / "bulb-assist-source.tar.gz").read_bytes())
        with tarfile.open(first / "bulb-assist-source.tar.gz") as bundle:
            self.assertEqual(bundle.getnames(), ["bulb-assist-source/README.md",
                                                "bulb-assist-source/SOURCE_MANIFEST.json"])
            self.assertTrue(all(m.uid == m.gid == m.mtime == 0 and not m.uname and not m.gname
                                for m in bundle.getmembers()))
        manifest = json.loads((first / "bulb-assist-source/SOURCE_MANIFEST.json").read_text())
        self.assertEqual([entry["path"] for entry in manifest["files"]], ["README.md"])
        with self.assertRaises(FileExistsError):
            exporter.export(first)


if __name__ == "__main__":
    unittest.main()
