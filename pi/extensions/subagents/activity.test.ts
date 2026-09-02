import assert from "node:assert/strict";
import test from "node:test";
import type { Theme } from "@earendil-works/pi-coding-agent";
import type { TUI } from "@earendil-works/pi-tui";
import {
  isMeaningfulActivityEvent,
  type SubagentSnapshot,
} from "./src/domain.ts";
import type { SubagentReadModel } from "./src/manager.ts";
import {
  SubagentActivityWidget,
  formatActivityRow,
  latestActivity,
  selectActiveSubagents,
} from "./src/ui/activity.ts";

function snapshot(
  overrides: Partial<SubagentSnapshot> = {},
): SubagentSnapshot {
  return {
    id: "sa-1",
    origin: "model",
    backend: "codex",
    title: "inspect repository",
    prompt: "Inspect the repository",
    cwd: "/tmp/project",
    status: "running",
    createdAt: 1_000,
    lastActivityAt: 1_000,
    meta: { backend: "codex", modelLabel: "gpt-5.6-sol" },
    usage: {},
    transcript: [],
    liveTools: [],
    queued: [],
    finalText: "",
    turns: 0,
    ...overrides,
  };
}

test("selectActiveSubagents keeps the first two running agents in creation order", () => {
  const selected = selectActiveSubagents([
    snapshot({ id: "sa-old", createdAt: 10, lastActivityAt: 40 }),
    snapshot({ id: "btw-recent", origin: "btw", createdAt: 20, lastActivityAt: 10 }),
    snapshot({ id: "sa-new", createdAt: 30, lastActivityAt: 50 }),
    snapshot({ id: "sa-done", status: "done", createdAt: 40, lastActivityAt: 60 }),
  ]);

  assert.deepEqual(
    selected.visible.map((snap) => snap.id),
    ["sa-old", "btw-recent"],
  );
  assert.equal(selected.active.length, 3);
  assert.equal(selected.hiddenCount, 1);
});

test("selectActiveSubagents uses stable id order for equal creation times", () => {
  const selected = selectActiveSubagents([
    snapshot({ id: "sa-z", lastActivityAt: 20 }),
    snapshot({ id: "sa-a", lastActivityAt: 20 }),
    snapshot({ id: "sa-m", lastActivityAt: 20 }),
  ]);

  assert.deepEqual(
    selected.visible.map((snap) => snap.id),
    ["sa-a", "sa-m"],
  );
  assert.equal(selected.hiddenCount, 1);
});

test("latestActivity prefers a live tool and sanitizes its preview", () => {
  const activity = latestActivity(
    snapshot({
      liveTools: [
        {
          toolId: "tool-1",
          name: "shell",
          argsPreview: "{\"command\":\"rg\\nTODO\"}",
        },
      ],
    }),
  );

  assert.equal(activity, 'shell: {"command":"rg\\nTODO"}');
});

test("latestActivity falls back from assistant text to transcript and starting", () => {
  assert.equal(
    latestActivity(
      snapshot({
        liveAssistant: { text: "  reading\nfiles  ", thinking: "" },
      }),
    ),
    "assistant: reading files",
  );
  assert.equal(
    latestActivity(
      snapshot({
        transcript: [
          {
            kind: "toolResult",
            toolId: "tool-1",
            name: "read",
            isError: false,
            outputPreview: "file contents",
          },
        ],
      }),
    ),
    "read: file contents",
  );
  assert.equal(latestActivity(snapshot()), "starting");
});

test("latestActivity bounds long previews and formatActivityRow includes metadata", () => {
  const activity = latestActivity(
    snapshot({
      liveAssistant: { text: "x".repeat(500), thinking: "" },
    }),
  );

  assert.equal(activity.length, 240);
  assert.match(
    formatActivityRow(snapshot({ title: "review", createdAt: Date.now() })),
    /^review · codex · \d+s · starting$/,
  );
});

test("only meaningful events change the activity ranking", () => {
  assert.equal(
    isMeaningfulActivityEvent({
      _tag: "UsageChanged",
      tokens: 100,
      contextWindow: 1_000,
    }),
    false,
  );
  assert.equal(
    isMeaningfulActivityEvent({
      _tag: "MetaChanged",
      meta: { modelLabel: "gpt-5.6-sol" },
    }),
    false,
  );
  assert.equal(isMeaningfulActivityEvent({ _tag: "ToolStart", toolId: "t", name: "read" }), true);
});

test("the widget shows the first two active agents and bounded overflow", async () => {
  const snapshots = [
    snapshot({ id: "sa-old", title: "old", createdAt: 10, lastActivityAt: 40 }),
    snapshot({ id: "btw-recent", origin: "btw", title: "aside", createdAt: 20, lastActivityAt: 10 }),
    snapshot({ id: "sa-new", title: "new", createdAt: 30, lastActivityAt: 50 }),
    snapshot({ id: "sa-done", status: "done", title: "done", createdAt: 40, lastActivityAt: 60 }),
  ];
  let listener: (() => void) | undefined;
  let renders = 0;
  const view = {
    list: () => snapshots,
    subscribe: (next: () => void) => {
      listener = next;
      return () => {
        listener = undefined;
      };
    },
    stats: () => ({
      totalAgents: 4,
      agentTimeMs: 90_000,
      wallTimeMs: 60_000,
      contextTokens: 12_400,
    }),
  } as unknown as SubagentReadModel;
  const tui = {
    requestRender: () => {
      renders++;
    },
  } as unknown as TUI;
  const theme = {
    fg: (_name: string, text: string) => text,
  } as unknown as Theme;
  const widget = new SubagentActivityWidget(tui, theme, view);

  const lines = widget.render(100);
  assert.equal(lines.length, 4);
  assert.match(lines[0], /Subagents · 3 running/);
  assert.match(lines[0], /4 total/);
  assert.match(lines[0], /1m00s wall/);
  assert.match(lines[0], /1m30s total/);
  assert.match(lines[0], /12k ctx tokens/);
  assert.match(lines[1], /■\s+│\s+old\s+│\s+codex/);
  assert.match(lines[2], /■\s+│\s+aside\s+│\s+codex/);
  assert.doesNotMatch(lines[1], /sa-new|btw-recent|running/);
  assert.doesNotMatch(lines[2], /sa-new|btw-recent|running/);
  assert.match(lines[3], /\+1 more/);
  assert.doesNotMatch(lines[3], /\/subagents for details/);
  assert.equal(widget.render(100).some((line) => line.includes("sa-done")), false);

  widget.dispose();
  listener?.();
  await new Promise((resolve) => setTimeout(resolve, 70));
  assert.equal(renders, 0);
});

test("the widget keeps the summary after all agents settle", () => {
  const snapshots = [snapshot({ status: "done", title: "finished" })];
  const view = {
    list: () => snapshots,
    subscribe: () => () => {},
    stats: () => ({
      totalAgents: 1,
      agentTimeMs: 12_000,
      wallTimeMs: 12_000,
      contextTokens: 2_400,
    }),
  } as unknown as SubagentReadModel;
  const tui = { requestRender: () => {} } as unknown as TUI;
  const theme = { fg: (_name: string, text: string) => text } as unknown as Theme;
  const widget = new SubagentActivityWidget(tui, theme, view);

  const lines = widget.render(100);
  assert.equal(lines.length, 2);
  assert.match(lines[0], /Subagents · 0 running · 1 total/);
  assert.match(lines[0], /2\.4k ctx tokens/);
  assert.doesNotMatch(lines[1], /\/subagents for details/);
  widget.dispose();
});
