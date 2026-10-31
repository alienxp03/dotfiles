#!/usr/bin/env python3
"""Guarded post-merge Rex cleanup. Never performs a merge or force-deletes data."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


class Refused(RuntimeError):
    pass


def run(args, cwd, check=True):
    result = subprocess.run(args, cwd=cwd, text=True, capture_output=True)
    if check and result.returncode:
        raise Refused(f"Command failed: {args!r}\n{result.stderr.strip()}")
    return result


def git(cwd, *args, check=True):
    return run(["git", *args], cwd, check).stdout.strip()


def require(condition, message):
    if not condition:
        raise Refused(message)


def worktrees(primary):
    records, record = [], {}
    for field in git(primary, "worktree", "list", "--porcelain", "-z").split("\0"):
        if not field:
            if record:
                records.append(record)
                record = {}
        else:
            key, _, value = field.partition(" ")
            record[key] = value
    if record:
        records.append(record)
    return records


def ancestor(primary, older, newer):
    return run(["git", "merge-base", "--is-ancestor", older, newer], primary, False).returncode == 0


def verify(args):
    primary, source = Path(args.primary).resolve(strict=True), Path(args.source).resolve(strict=True)
    require(primary != source and primary.is_relative_to(source) is False, "Cannot remove the primary worktree or its parent")
    require(args.branch != args.target, "Source and target branches are identical")
    require(args.branch not in {"main", "master", "trunk", "develop", "development", "release"}, "Protected source branch")
    require(not args.branch.startswith("-") and not args.target.startswith("-"), "Invalid branch argument")
    trees = worktrees(primary)
    require(trees and Path(trees[0]["worktree"]).resolve() == primary, "--primary must be the first registered worktree")
    entry = next((x for x in trees if Path(x["worktree"]).resolve() == source), None)
    require(entry is not None and "locked" not in entry, "Source worktree is missing or locked")
    require(entry.get("branch") == "refs/heads/" + args.branch, "Source worktree branch changed")
    require(Path(git(source, "rev-parse", "--show-toplevel")).resolve() == source, "--source is not a worktree root")
    require(git(primary, "symbolic-ref", "--short", "HEAD") == args.target, "Target is not checked out in primary")
    primary_common = Path(git(primary, "rev-parse", "--path-format=absolute", "--git-common-dir")).resolve()
    source_common = Path(git(source, "rev-parse", "--path-format=absolute", "--git-common-dir")).resolve()
    require(primary_common == source_common, "Worktrees do not share a Git repository")
    require(git(source, "rev-parse", "HEAD") == args.source_commit, "Source commit changed")
    require(git(primary, "rev-parse", "HEAD") == args.target_commit, "Target commit changed")
    for path in (source, primary):
        require(not git(path, "status", "--porcelain=v1", "--untracked-files=all"), f"Worktree is dirty: {path}")
        for state in ("MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply"):
            state_path = Path(git(path, "rev-parse", "--git-path", state))
            if not state_path.is_absolute():
                state_path = path / state_path
            require(not state_path.exists(), f"Git operation in progress: {path} ({state})")
    require(ancestor(primary, args.source_commit, args.target_commit), "Source is not merged into target")
    upstream = run(["git", "rev-parse", "--verify", args.branch + "@{upstream}"], primary, False)
    if upstream.returncode == 0:
        require(ancestor(primary, args.source_commit, upstream.stdout.strip()), "Source tracking branch would make git branch -d refuse; preserve worktree")
    if not args.local_only:
        remote = git(primary, "config", "--get", "branch." + args.target + ".remote")
        ref = git(primary, "config", "--get", "branch." + args.target + ".merge")
        require(remote and remote != "." and ref.startswith("refs/heads/"), "Target needs a remote upstream, or an explicitly justified --local-only")
        actual = git(primary, "ls-remote", "--exit-code", remote, ref).split()
        require(actual and actual[0] == args.target_commit, "Target commit is not the live upstream tip; push/verify before cleanup")
    require(os.environ.get("REX_SESSION") == args.session and os.environ.get("REX_BLOCK") == args.block, "Rex IDs do not match this agent's environment")
    require(args.session.startswith("session:") and args.block.startswith("block:"), "Expected full Rex session/block IDs")
    inspect = json.loads(run(["rex", "--autostart=false", "block", "inspect", args.block, "-s", args.session, "--json"], primary).stdout)
    require(inspect.get("session_id") == args.session and inspect.get("block", {}).get("block_id") == args.block, "Rex pane/session mismatch")
    process = json.loads(run(["rex", "--autostart=false", "block", "call", "-s", args.session, "-b", args.block, "process"], primary).stdout)
    cwd = (process.get("foreground") or {}).get("cwd") or (process.get("child") or {}).get("cwd")
    require(cwd and Path(cwd).resolve().is_relative_to(source), "Rex pane's process cwd is not inside the source worktree")
    return primary, source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("primary", "source", "branch", "target", "source-commit", "target-commit", "session", "block"):
        parser.add_argument("--" + flag, required=True)
    parser.add_argument("--local-only", action="store_true", help="Explicit no-push/no-remote policy; never bypass a failed push")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    primary, source = verify(args)
    commands = [
        ["git", "worktree", "remove", str(source)],
        ["git", "branch", "-d", "--", args.branch],
        ["rex", "--autostart=false", "block", "close", "-s", args.session, args.block],
    ]
    print(json.dumps({"cwd": str(primary), "commands": commands, "dry_run": args.dry_run}), flush=True)
    if args.dry_run:
        return
    log = Path(tempfile.mkdtemp(prefix="git-merge-cleanup-")) / "result.json"
    state = {"primary": str(primary), "source": str(source), "branch": args.branch, "target": args.target,
             "session": args.session, "block": args.block, "completed": []}
    def save():
        with log.open("w") as stream:
            json.dump(state, stream, indent=2)
            stream.flush()
            os.fsync(stream.fileno())
    save()
    print(f"Cleanup log: {log}", flush=True)
    # No subsequent command depends on the source cwd, even if this interpreter
    # was launched from inside it. The agent may be terminated by the final step.
    os.chdir(primary)
    try:
        for label, command in zip(("worktree_removed", "branch_deleted", "pane_closed"), commands):
            state["next"] = label
            save()
            run(command, primary)
            state["completed"].append(label)
            save()
    except Exception as error:
        state["error"] = str(error)
        save()
        raise


if __name__ == "__main__":
    try:
        main()
    except (Refused, OSError, ValueError) as error:
        print(f"Cleanup stopped: {error}", file=sys.stderr)
        sys.exit(1)
