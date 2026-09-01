/** All model-facing strings for the subagents tools. */

/** Describes subagent_spawn, including harnesses and the fixed concurrency cap. */
export const SUBAGENT_SPAWN_TOOL_DESCRIPTION =
  "Spawn a background subagent: a fully autonomous, headless agent with its own context window and the selected harness's normal host permissions. You choose the harness it runs on: pi (in-process pi session, inherits this environment's tools and config), claude (Claude Code), or codex (Codex CLI). Fire-and-forget: this returns immediately with an id. In TUI mode, live activity is visible above the editor. Continue useful parent work; the final output is delivered automatically when the subagent settles. Use subagent_wait only when the result is a hard dependency for the next parent action. Children cannot orchestrate more agents/workflows or ask the user, and cannot see this conversation, so the prompt must be self-contained. Only use trusted working directories. Max 4 subagents can be running at once across all harnesses.";

/** Adds background subagent delegation to the parent model's available-tools prompt. */
export const SUBAGENT_SPAWN_PROMPT_SNIPPET =
  "Spawn a background subagent on a chosen harness (pi, Claude Code, or Codex; own context, normal tools) for a self-contained task. Continue parent work after spawning; live activity appears above the editor and the result arrives automatically.";

/** Guides the parent model to delegate standalone tasks and avoid unnecessary blocking waits. */
export const SUBAGENT_SPAWN_PROMPT_GUIDELINES = [
  "Use subagent_spawn to delegate self-contained tasks that can run in the background; give it a complete, standalone prompt.",
  "Pick the subagent harness deliberately: pi unless you have a reason to prefer Claude Code or Codex (e.g. the user asked for one, or the task suits that harness).",
  "After subagent_spawn, keep working; results arrive automatically. Only call subagent_wait when you cannot proceed without the result.",
  "If subagent_check reports a settled result that is still queued and you plan to use it in your response, call subagent_wait before responding. This consumes the queued delivery so it cannot appear after your summary.",
];

/** Model-facing schema descriptions for subagent_spawn task and execution options. */
export const SUBAGENT_SPAWN_PARAMETER_DESCRIPTIONS = {
  prompt:
    "Task prompt for the subagent. Must be self-contained: include all needed context, file paths, and what to report back.",
  name: "Short human-readable name for this subagent, shown in listings and the UI",
  harness:
    'Harness to run the subagent on: "pi" (in-process pi session; inherits this environment), "claude" (Claude Code), or "codex" (Codex CLI). Choose deliberately per task.',
  workingDir:
    "Trusted working directory for the autonomous child (default: current working directory)",
  model:
    'Model hint, interpreted by the chosen harness (pi: "provider/model-id" or model id; claude: model alias like "sonnet"/"opus"; codex: model slug). Omit for the harness default (pi inherits the current model).',
  reasoningEffort:
    "Reasoning effort on a shared scale; the harness maps it to its nearest native equivalent (pi thinking level, codex reasoning effort, claude thinking budget). Omit for the harness default (pi inherits the current level).",
};

/** Builds the subagent_spawn result that tells the parent model how to continue or inspect the child. */
export function buildSubagentSpawnResult(options: {
  id: string;
  title: string;
  harness: string;
  modelLabel: string;
  cwd: string;
}) {
  return (
    `Spawned subagent ${options.id} "${options.title}" (${options.harness}: ${options.modelLabel}, ${options.cwd}).\n` +
    `It runs in the background and its live activity appears above the editor. Continue useful parent work; its result will be delivered automatically when it finishes. ` +
    `Use subagent_wait(ids: ["${options.title}"]) only if its result is a hard dependency; exact names work for wait, check, and cancel. The runtime id "${options.id}" also remains available.`
  );
}

/** Describes explicit blocking collection of one or more subagent results. */
export const SUBAGENT_WAIT_TOOL_DESCRIPTION =
  "Block until all listed subagents have settled, then return their final outputs. Accepts runtime ids or exact human-readable names. Prefer letting results arrive automatically; use this only when you need a result before continuing.";

/** Model-facing schema description for the subagent ids or names to await. */
export const SUBAGENT_WAIT_PARAMETER_DESCRIPTIONS = {
  ids: 'Subagent runtime ids or exact human-readable names, e.g. ["review-api"] or ["sa-1", "sa-2"]',
};

/** Describes aborting running subagents while retaining their partial transcripts. */
export const SUBAGENT_CANCEL_TOOL_DESCRIPTION =
  "Cancel one or more running subagents. Accepts runtime ids or exact human-readable names. This aborts their active work but preserves their partial session transcripts on disk.";

/** Model-facing schema description for the subagent ids or names to cancel. */
export const SUBAGENT_CANCEL_PARAMETER_DESCRIPTIONS = {
  ids: 'Subagent runtime ids or exact human-readable names, e.g. ["demo-pi"] or ["sa-1", "sa-2"]',
};

/** Describes nonblocking inspection of a subagent without consuming its result. */
export const SUBAGENT_CHECK_TOOL_DESCRIPTION =
  "Peek at a subagent's status and recent activity without blocking. Accepts a runtime id or exact human-readable name. Does not consume its result. If a settled result is queued and you plan to use it in your response, call subagent_wait before responding so the completion cannot appear afterward.";

/** Tells the model how to avoid summarizing ahead of queued result delivery. */
export function buildSubagentCheckSettledGuidance(id: string) {
  return `This settled result is still queued for automatic delivery. Before responding with or summarizing it, call subagent_wait(ids: ["${id}"]) to consume that delivery; otherwise its completion message may appear after your response.`;
}

/** Model-facing schema description for the subagent id or name to inspect. */
export const SUBAGENT_CHECK_PARAMETER_DESCRIPTIONS = {
  id: "Subagent runtime id or exact human-readable name",
};

/** Describes listing all tracked running and settled subagents. */
export const SUBAGENT_LIST_TOOL_DESCRIPTION =
  "List all subagents (running and finished) with their harness and status.";

/** Builds the child completion/failure wrapper injected into the parent model's context. */
export function buildSubagentResultMessage(options: {
  id: string;
  title: string;
  status: "running" | "done" | "error";
  errorText?: string;
  output: string;
}) {
  const verb = options.status === "error" ? "failed" : "finished";
  let text = `Subagent ${options.id} "${options.title}" ${verb}.`;
  if (options.errorText) text += `\nError: ${options.errorText}`;
  text += `\n\n${options.output}`;
  return text;
}
