#!/usr/bin/env python3
"""Isolated discovery-link tests. Never changes the operator's HOME."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts/link-agy-skills.py"


class LinkAgySkills(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="skills-agy-test-")
        self.user = Path(self.temp.name)
        self.source = self.user / ".agents/skills"
        self.target = self.user / ".gemini/antigravity-cli/skills"
        self.source.mkdir(parents=True)
        self.lock = self.user / ".agents/.skill-lock.json"
        self.entries = {}

    def tearDown(self):
        self.temp.cleanup()

    def skill(self, name, owner="ryangriffinau/skills"):
        self.entries[name] = {"source": owner}
        if ".." not in name and "/" not in name:
            package = self.source / name
            package.mkdir()
            (package / "SKILL.md").write_text(f"---\nname: {name}\ndescription: Test\n---\n")
        self.lock.write_text(json.dumps({"version": 3, "skills": self.entries}))

    def run_helper(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), "--user-dir", str(self.user), *args],
                              text=True, capture_output=True, timeout=10)

    def snapshot(self):
        return {str(p.relative_to(self.user)): ("link", str(p.readlink())) if p.is_symlink()
                else ("dir",) if p.is_dir() else ("file", p.read_bytes())
                for p in self.user.rglob("*")}

    def test_default_and_explicit_check_do_not_write(self):
        self.skill("write-goal")
        before = self.snapshot()
        for flags in [(), ("--check",)]:
            result = self.run_helper(*flags)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn("1 missing", result.stdout)
            self.assertEqual(self.snapshot(), before)

    def test_apply_and_repeat_preserve_unrelated(self):
        self.skill("write-goal")
        self.skill("foreign", "someone/else")
        self.target.mkdir(parents=True)
        (self.target / "personal").mkdir()
        (self.target / "personal/SKILL.md").write_text("local skill")
        original_lock = self.lock.read_bytes()
        result = self.run_helper("--apply")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.target / "write-goal").resolve(), (self.source / "write-goal").resolve())
        self.assertFalse((self.target / "foreign").exists())
        self.assertEqual((self.target / "personal/SKILL.md").read_text(), "local skill")
        self.assertEqual(self.lock.read_bytes(), original_lock)
        before = self.snapshot()
        self.assertEqual(self.run_helper("--apply").returncode, 0)
        self.assertEqual(self.run_helper("--check").returncode, 0)
        self.assertEqual(self.snapshot(), before)

    def test_conflict_prevents_all_creation(self):
        for kind in ["directory", "file", "link"]:
            with self.subTest(kind=kind):
                self.skill("a-first")
                self.skill("z-conflict")
                self.target.mkdir(parents=True)
                conflict = self.target / "z-conflict"
                if kind == "directory":
                    conflict.mkdir()
                elif kind == "file":
                    conflict.write_text("keep")
                else:
                    conflict.symlink_to(self.user / "unrelated-missing")
                before = self.snapshot()
                result = self.run_helper("--apply")
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertEqual(self.snapshot(), before)
                self.assertFalse((self.target / "a-first").exists())
                self.tearDown()
                self.setUp()

    def test_unsafe_names_rejected_without_writes(self):
        for name in ["../escape", "name/child", "-flag", ".hidden", "a" * 65]:
            with self.subTest(name=name):
                self.entries = {name: {"source": "ryangriffinau/skills"}}
                self.lock.write_text(json.dumps({"skills": self.entries}))
                before = self.snapshot()
                result = self.run_helper("--apply")
                self.assertEqual(result.returncode, 2)
                self.assertIn("Unsafe skill name", result.stderr)
                self.assertEqual(self.snapshot(), before)

    def test_missing_entrypoint_prevents_all_creation(self):
        self.skill("a-first")
        self.entries["z-missing"] = {"source": "ryangriffinau/skills"}
        self.lock.write_text(json.dumps({"skills": self.entries}))
        before = self.snapshot()
        self.assertEqual(self.run_helper("--apply").returncode, 2)
        self.assertEqual(self.snapshot(), before)

    def test_discovery_root_symlink_is_rejected(self):
        self.skill("write-goal")
        self.target.parent.mkdir(parents=True)
        self.target.symlink_to(self.source, target_is_directory=True)
        before = self.snapshot()
        self.assertEqual(self.run_helper("--apply").returncode, 2)
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
