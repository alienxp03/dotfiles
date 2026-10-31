---
name: git-merge
description: Use when the user asks to merge or finish the current Git branch/worktree. Uses git-commit, merges and validates the target, pushes its configured upstream, then safely removes a merged Rex worktree/branch and closes only its originating pane.
---

# Git merge

Treat “merge”, “merge this”, or “finish and merge” as this workflow. A request to
create or discuss this skill is NOT permission to merge the current repository.

## Defaults

- Read and use the `git-commit` skill for committing source changes. Locate its
  installed `SKILL.md` beside this skill or in the configured skill locations.
  Do not recursively invoke `git-merge` from itself.
- Normal Git merge: fast-forward when possible, merge commit when necessary
  (`git merge --ff SOURCE`). No squash, rebase, force push, or history rewrite.
- Push the target to its configured upstream before cleanup. Respect explicit
  instructions not to push. Never invent an upstream or remote. With remotes but
  no configured target upstream, ask before pushing/cleanup. With no remote,
  local integration is sufficient; explain that nothing was pushed.
- Automatically delete the source worktree/branch and close its pane ONLY in a
  verified Rex context. Outside Rex, retain the source workspace and branch unless
  the user explicitly requests cleanup; never close another terminal app.
- Keep the source worktree, branch, and pane if merge, validation, or push fails.
  Do not reset a completed merge or discard user changes to make cleanup possible.

## 1. Establish exact context

Before committing, capture absolute source worktree path, source branch, primary
worktree path, intended target, and `REX_SESSION` / `REX_BLOCK` if present.

- Inspect `git status`, `git worktree list --porcelain`, current branch, common
  Git directory, configured upstreams, and repository instructions/tests.
- The primary worktree is the FIRST registered worktree, not a guessed `../main`.
- Default target: the local remote-default branch if it is checked out in the
  primary worktree; otherwise the primary worktree's checked-out branch. If that
  conflicts with project instructions or intent, ask. Never switch a worktree
  away from someone else's branch to guess a target.
- Stop for detached HEAD, missing target checkout, source == target, merging from
  the primary worktree, protected source names (`main`, `master`, `trunk`,
  `develop`, `development`, `release`), locked worktrees, or dirty target checkout.
  If merging directly on the primary branch is actually requested, clarify the
  source and do not delete the primary checkout.
- Resolve symlinks and verify both worktrees share the same Git common directory.
- Review ignored files too (`git status --short --ignored`): worktree removal can
  delete ignored data. Generated caches/build outputs may be discarded, but stop
  and preserve user-owned files, secrets, or unknown ignored content before
  cleanup. Do not treat “Git clean” as proof that no valuable ignored files exist.
- Rex environment variables are a hint, not proof. Read the `rex` skill; use the
  installed CLI's help if needed. Verify the exact block belongs to the captured
  session and its terminal process cwd is inside the source worktree. Do not
  guess a pane from labels or whichever client currently has focus.

## 2. Commit, integrate, validate, push

1. Use `git-commit` to review and commit all intended source changes. Preserve
   unrelated work; if scope is unclear, ask. Record the resulting source commit.
   A feature push is not required unless needed for its tracking branch's safe
   deletion; do not describe that as a substitute for pushing the merged target.
2. Run target-side commands with an explicit `git -C PRIMARY` / `cwd=PRIMARY`.
   Keep the agent's source checkout intact through validation and push.
3. Fetch the target's upstream remote, if configured. Update a behind target with
   `git merge --ff-only UPSTREAM`. If target and upstream diverged, stop and ask;
   do not rebase or make an unrelated integration merge automatically.
4. Merge the source branch with `git merge --ff SOURCE` in the clean target.
   Stop on conflicts; report them, preserving both worktrees. Resolve only with
   sufficient context/authorization; never use blanket ours/theirs.
5. Run the repository's required tests/builds from the merged target. Perform any
   required app rebuild/reload specified by its project instructions. A failing
   check blocks automatic cleanup; do not silently skip checks or claim unrun
   validation passed.
6. Check target and source are clean. Push target to its configured remote and
   merge ref, with no force. Confirm the remote branch contains the merged target
   commit. A failed push blocks cleanup. If source has an upstream that would
   make `git branch -d` refuse deletion, stop before cleanup; do not force-delete.
7. Record exact source and target commit IDs after validation. If either changes
   before cleanup, re-evaluate instead of deleting a moving branch.

## 3. Verified Rex cleanup (last)

Use the bundled `scripts/cleanup.py`; resolve its path relative to this skill.
It performs guards again and supports `--dry-run`. Python 3 is required.

```sh
python3 /ABSOLUTE/SKILL/DIR/scripts/cleanup.py \
  --primary /absolute/primary --source /absolute/source \
  --branch SOURCE --target TARGET \
  --source-commit SOURCE_SHA --target-commit TARGET_SHA \
  --session "$REX_SESSION" --block "$REX_BLOCK" --dry-run
```

- The default verifies the configured upstream live with `git ls-remote`.
  Add `--local-only` ONLY when the user explicitly declined pushing or the repo
  has no remotes, and say why. It does not mean “ignore a failed push”.
- After a successful dry-run, announce the actual merge/test/push result and
  explain that the originating Rex pane will now close. Do this BEFORE invoking
  final cleanup: closing the pane terminates the agent and tool delivery.
- Run the same command without `--dry-run` in ONE tool call. The helper changes
  directory to primary before removal; all later Git/Rex commands run there.
  Order: `git worktree remove SOURCE`, `git branch -d SOURCE_BRANCH`, then
  `rex block close -s SESSION BLOCK`. Never use `--force`, `-D`, or `rex kill`.
- Do not start another tool call assuming the deleted source cwd still exists.
  The helper prints its durable log path before mutations and records each phase
  outside the deleted worktree. If cleanup partially fails, use that log and an
  explicit surviving cwd to recover; do not claim every cleanup step succeeded.
- Never close the pane when a guard or cleanup command fails. If the worktree was
  removed but branch deletion failed in a race, report the partial state; do not
  escalate to force deletion. If pane closure fails, the integration and cleanup
  remain valid; report the exact pane to close manually.

## Reporting

Before destructive cleanup: source → target, commit, checks, push outcome, and
which source worktree/branch/pane will be removed. Be concise. No fabricated
success after killing your own agent. Do not auto-commit/push changes to this
skill merely because the user is discussing its behavior.
