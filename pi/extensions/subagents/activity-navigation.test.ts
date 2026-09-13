import assert from "node:assert/strict";
import test from "node:test";
import type { Theme } from "@earendil-works/pi-coding-agent";
import { type Editor, type Component, type TUI } from "@earendil-works/pi-tui";
import type { SubagentSnapshot } from "./src/domain.ts";
import type { SubagentReadModel } from "./src/manager.ts";
import { SubagentActivityWidget } from "./src/ui/activity.ts";

function setup() {
  const snapshots = [1, 2, 3].map((n) => ({
    id: `sa-${n}`, title: `agent-${n}`, status: "running", backend: "pi",
    createdAt: n, meta: {}, usage: {}, transcript: [], liveTools: [], queued: [],
  })) as unknown as SubagentSnapshot[];
  let update = () => {};
  const view = {
    list: () => snapshots,
    subscribe: (fn: () => void) => { update = fn; return () => {}; },
    stats: () => ({ totalAgents: 3, wallTimeMs: 0, agentTimeMs: 0 }),
  } as unknown as SubagentReadModel;
  let text = "";
  let autocomplete = false;
  const editor = {
    getText: () => text,
    isShowingAutocomplete: () => autocomplete,
  } as Editor;
  let focused: Component | null = editor;
  let overlay = false;
  let prompt = false;
  let listener: ((data: string) => { consume?: boolean } | undefined) | undefined;
  const tui = {
    requestRender() {},
    hasOverlay: () => overlay,
    getFocusedComponent: () => focused,
    setFocus: (component: Component | null) => { focused = component; },
    addInputListener: (fn: typeof listener) => { listener = fn; return () => { listener = undefined; }; },
  } as unknown as TUI;
  const opened: string[] = [];
  const widget = new SubagentActivityWidget(tui, {
    fg: (_color: string, value: string) => value,
    bold: (value: string) => value,
  } as unknown as Theme, view, {
    canFocus: () => !prompt,
    open: async (id) => { opened.push(id); },
    onError: (error) => { throw error; },
  });
  return {
    widget, editor, opened, snapshots,
    update: () => update(),
    focus: () => focused,
    text: (value: string) => { text = value; },
    autocomplete: (value: boolean) => { autocomplete = value; },
    overlay: (value: boolean) => { overlay = value; },
    prompt: (value: boolean) => { prompt = value; },
    send: (data: string) => {
      const result = listener?.(data);
      if (!result?.consume && focused === widget) widget.handleInput(data);
      return result;
    },
    render: () => widget.render(120).join("\n"),
  };
}

test("down enters only from an empty editor without autocomplete or modal UI", () => {
  const s = setup();
  try {
    s.text("draft");
    assert.equal(s.send("\x1b[B"), undefined);
    s.text("");
    s.autocomplete(true);
    assert.equal(s.send("\x1b[B"), undefined);
    s.autocomplete(false);
    s.overlay(true);
    assert.equal(s.send("\x1b[B"), undefined);
    s.overlay(false);
    s.prompt(true);
    assert.equal(s.send("\x1b[B"), undefined);
    s.prompt(false);
    assert.equal(s.focus(), s.editor);
    assert.deepEqual(s.send("\x1b[B"), { consume: true });
    assert.equal(s.focus(), s.widget);
    assert.match(s.render(), /›.*agent-1/);
    s.send("\x1b");
    assert.equal(s.focus(), s.editor);
    assert.deepEqual(s.send("\x1b"), { consume: true });
  } finally { s.widget.dispose(); }
});

test("the preview stays visible while composing a prompt", () => {
  const s = setup();
  try {
    s.text("@");
    assert.match(s.render(), /agent-1/);
    s.text("@agent-1");
    assert.match(s.render(), /agent-1/);
    s.text("@agent-1 inspect this");
    assert.match(s.render(), /agent-1/);
    s.text("new prompt");
    assert.match(s.render(), /agent-1/);
    s.text("");
    assert.match(s.render(), /agent-1/);
  } finally { s.widget.dispose(); }
});

test("j/k scroll previews, selection survives settlement, Enter opens selected agent", async () => {
  const s = setup();
  try {
    s.send("\x1b[B");
    s.send("j");
    s.send("j");
    assert.match(s.render(), /›.*agent-3/);
    assert.doesNotMatch(s.render(), /agent-1/);
    s.snapshots[2] = { ...s.snapshots[2], status: "done" };
    s.update();
    assert.match(s.render(), /›.*agent-3/);
    s.send("\r");
    await new Promise((resolve) => setTimeout(resolve, 0));
    assert.deepEqual(s.opened, ["sa-3"]);
    s.send("k");
    assert.match(s.render(), /›.*agent-2/);
    s.send("\x1b[A");
    assert.match(s.render(), /›.*agent-1/);
    s.send("\x1b[B");
    assert.match(s.render(), /›.*agent-2/);
    s.send("\x1b");
    assert.equal(s.focus(), s.editor);
  } finally { s.widget.dispose(); }
});

test("disposing a focused panel restores editor and removes input listener", () => {
  const s = setup();
  s.send("\x1b[B");
  s.widget.dispose();
  assert.equal(s.focus(), s.editor);
  assert.equal(s.send("\x1b[B"), undefined);
});
