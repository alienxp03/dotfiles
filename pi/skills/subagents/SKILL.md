---
name: subagents
description: invoke this skill when the user asks you or you want to use subagents
---

# Subagents

- Each subagent is headless, has its own context window, cannot see the parent conversation, cannot ask the user, and cannot spawn subagents or workflows. Give every child a self-contained prompt with paths, constraints, and the expected report.
- You can also split tasks across multiple Git worktrees (Worktrunk: `wt switch --create <branch>`) and point each subagent at its worktree via `working_dir` — same-directory parallelism risks conflicting edits.

## Pi Harness

**Harness:** `pi`
**Prompt nicknames:** “pi”, “pi agent”, “pi subagent”
**Best default:** Use when the user does not request another harness. It inherits the parent model and thinking level when `model` or `reasoning_effort` is omitted. Almost never use Astra model unless user specifically asks for it, or approved by the user.

Pi can use any model shown by `pi --list-models`. Prefer `provider/model-id`; a bare model id only works when unambiguous. Common picks in this environment:

| Model                     | Vision | Recommended effort |
| ------------------------- | ------ | ------------------ |
| `zai/glm-5.3`             | no     | `max`              |
| `zai/glm-5.3-flash`       | yes    | `max`              |
| `openai-codex/gpt-6-luna` | yes    | `xhigh`            |
| `openai-codex/gpt-6.1-sol` | yes    | `high`             |

**Thinking budgets:** `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`. These map directly to pi thinking levels.

**Vision routing:** The parent's model is `$PI_MODEL`. Inherit it by omitting `model`; the only exception is image input. When the parent model lacks vision (e.g. `zai/glm-5.3`), spawn any subtask that must look at screenshots, images, or rendered UI on `zai/glm-5.3-flash` at `max` effort. Writing UI code is not a vision task — only route subtasks that consume image content.

## Codex Harness

**Harness:** `codex`
**Prompt nicknames:** “codex”, “Codex CLI”, “codex agent”, “codex subagent”
**Best default:** `gpt-6-luna` with `xhigh` effort for coding work. Stick to `gpt-6-luna`/`gpt-6.1-sol` unless the user specifically asks for another model.

| Model        | Recommended effort |
| ------------ | ------------------ |
| `gpt-6-luna` | `xhigh`            |
| `gpt-6.1-sol` | `high`             |

**Thinking budgets accepted by the extension:** `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`. Codex maps these to the nearest effort supported by the selected model; `off`/`minimal` become `minimal`, while `max` becomes the highest extension-supported Codex effort.

Requires the Codex CLI to be installed and authenticated.

## Claude Harness

**Harness:** `claude`
**Prompt nicknames:** “claude”, “Claude Code”, “claude subagent”
**Best default:** omit `model` for the harness default; pass an alias like `sonnet` or `opus` when a tier is requested.

**Thinking budgets:** `off`–`max` map to Claude thinking budget; the harness picks the nearest supported value.

Requires Claude Code to be installed and authenticated.

## Spawn and Manage

Call `subagent_spawn` with a complete `prompt`, short `name`, chosen `harness`, and optional `working_dir`, `model`, and `reasoning_effort`. At most four subagents run concurrently.

- `subagent_check({ id })`: peek without blocking; does not consume automatic result delivery.
- `subagent_list()`: list all runs.
- `subagent_wait({ ids })`: block only when results are required to proceed. If `subagent_check` reports a settled result still queued and you will summarize it, call `subagent_wait` before responding so the completion cannot appear afterward.
- `subagent_cancel({ ids })`: stop runs while preserving partial transcripts.
- `/subagents`: inspect or take over a run interactively.

Results return automatically. After spawning, continue useful parent work instead of immediately waiting.
