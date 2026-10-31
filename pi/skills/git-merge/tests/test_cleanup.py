import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "cleanup.py"


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="git-merge-test-")
        self.root = Path(self.temp.name).resolve()
        self.primary, self.source = self.root / "primary", self.root / "source"
        self.primary.mkdir()
        self.git(self.primary, "init", "-b", "main")
        self.git(self.primary, "config", "user.name", "Test")
        self.git(self.primary, "config", "user.email", "test@example.com")
        self.git(self.primary, "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "base")
        self.git(self.primary, "worktree", "add", "-b", "otter", str(self.source))
        (self.source / "work").write_text("done")
        self.git(self.source, "add", "work")
        self.git(self.source, "-c", "commit.gpgsign=false", "commit", "-m", "feature")
        self.source_commit = self.git(self.source, "rev-parse", "HEAD")
        self.git(self.primary, "merge", "--ff", "otter")
        self.target_commit = self.git(self.primary, "rev-parse", "HEAD")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "rex-calls.jsonl"
        fake = self.bin / "rex"
        fake.write_text('''#!/usr/bin/env python3
import json,os,sys
args=sys.argv[1:]
if 'inspect' in args:
 print(json.dumps({'session_id':'session:test','block':{'block_id':os.getenv('TEST_BLOCK','block:test')}}))
elif 'process' in args:
 print(json.dumps({'foreground':{'cwd':os.environ['TEST_SOURCE']}}))
elif 'close' in args:
 with open(os.environ['TEST_LOG'],'a') as f:
  f.write(json.dumps({'args':args,'cwd':os.getcwd(),'source_exists':os.path.exists(os.environ['TEST_SOURCE'])})+'\\n')
else:
 sys.exit(1)
''')
        fake.chmod(0o755)
        self.env = dict(os.environ, REX_SESSION="session:test", REX_BLOCK="block:test",
                        TEST_SOURCE=str(self.source), TEST_LOG=str(self.log),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])

    def tearDown(self):
        self.temp.cleanup()

    def git(self, cwd, *args):
        p = subprocess.run(["git", *args], cwd=cwd, text=True, capture_output=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p.stdout.strip()

    def invoke(self, *extra, local=True):
        args = [sys.executable, str(SCRIPT), "--primary", str(self.primary), "--source", str(self.source),
                "--branch", "otter", "--target", "main", "--source-commit", self.source_commit,
                "--target-commit", self.target_commit, "--session", "session:test", "--block", "block:test"]
        if local:
            args.append("--local-only")
        return subprocess.run(args + list(extra), cwd=self.source, env=self.env, text=True, capture_output=True)

    def assert_preserved(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertTrue(self.source.exists())
        self.assertIn("otter", self.git(self.primary, "branch", "--list", "otter"))
        self.assertFalse(self.log.exists(), "closed pane despite refusal")

    def test_dry_run_preserves_everything(self):
        p = self.invoke("--dry-run")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertTrue(self.source.exists())
        self.assertFalse(self.log.exists())

    def test_removes_from_primary_then_closes_only_exact_pane(self):
        p = self.invoke()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse(self.source.exists())
        self.assertEqual(self.git(self.primary, "branch", "--list", "otter"), "")
        call = json.loads(self.log.read_text())
        self.assertEqual(call["cwd"], str(self.primary))
        self.assertFalse(call["source_exists"])
        self.assertEqual(call["args"], ["--autostart=false", "block", "close", "-s", "session:test", "block:test"])

    def test_primary_removal_is_refused(self):
        self.assert_preserved(self.invoke("--source", str(self.primary)))

    def test_protected_source_is_refused(self):
        self.assert_preserved(self.invoke("--branch", "master"))

    def test_locked_worktree_is_preserved(self):
        self.git(self.primary, "worktree", "lock", str(self.source))
        self.assert_preserved(self.invoke())

    def test_dirty_source_is_preserved(self):
        (self.source / "unsaved").write_text("keep")
        self.assert_preserved(self.invoke())

    def test_dirty_target_is_preserved(self):
        (self.primary / "unsaved").write_text("keep")
        self.assert_preserved(self.invoke())

    def test_unmerged_source_is_preserved(self):
        self.git(self.source, "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "later")
        self.source_commit = self.git(self.source, "rev-parse", "HEAD")
        self.assert_preserved(self.invoke())

    def test_changed_commit_is_preserved(self):
        self.source_commit = "0" * 40
        self.assert_preserved(self.invoke())

    def test_wrong_pane_is_preserved(self):
        self.env["TEST_BLOCK"] = "block:someone-else"
        self.assert_preserved(self.invoke())

    def test_pane_cwd_outside_source_is_preserved(self):
        self.env["TEST_SOURCE"] = str(self.primary)
        self.assert_preserved(self.invoke())

    def test_missing_rex_context_is_preserved(self):
        self.env.pop("REX_BLOCK")
        self.assert_preserved(self.invoke())

    def test_requires_push_policy(self):
        self.assert_preserved(self.invoke(local=False))

    def test_live_upstream_is_verified(self):
        origin = self.root / "origin.git"
        self.git(self.primary, "init", "--bare", str(origin))
        self.git(self.primary, "remote", "add", "origin", str(origin))
        self.git(self.primary, "push", "-u", "origin", "main")
        p = self.invoke("--dry-run", local=False)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.git(self.primary, "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "not pushed")
        self.target_commit = self.git(self.primary, "rev-parse", "HEAD")
        self.assert_preserved(self.invoke(local=False))

    def test_source_upstream_that_blocks_safe_deletion_preserves_worktree(self):
        base = self.git(self.primary, "rev-parse", "HEAD~1")
        self.git(self.primary, "remote", "add", "origin", str(self.root / "unused"))
        self.git(self.primary, "update-ref", "refs/remotes/origin/otter", base)
        self.git(self.primary, "config", "branch.otter.remote", "origin")
        self.git(self.primary, "config", "branch.otter.merge", "refs/heads/otter")
        self.assert_preserved(self.invoke())


if __name__ == "__main__":
    unittest.main()
