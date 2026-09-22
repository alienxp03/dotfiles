import assert from "node:assert/strict";
import test, { type TestContext } from "node:test";
import { KeybindingsManager } from "./node_modules/@earendil-works/pi-coding-agent/dist/core/keybindings.js";
import { TuiMainScreen, type TUI, type Component, type Terminal } from "@earendil-works/pi-tui";
import {
  dashboardColumnLayout,
  openSubagentPicker,
  openSubagentTakeover,
  reconcileDashboardSelection,
  type DashboardColumnLayout,
  type DashboardSelection,
} from "./src/ui/takeover.ts";

// Use the host input dispatcher and overlay focus stack, not a simulated dispatch.
function createHostHarness(t: TestContext, keys = new KeybindingsManager()) {
  const tui = new TuiMainScreen({ rows: 30, columns: 100, hideCursor: () => {} } as Terminal);
  t.mock.method(tui, "requestRender", () => {});
  const host = tui as unknown as {
    handleTerminalInput(data: string): void;
    requestImmediateRender(): void;
  };
  t.mock.method(host, "requestImmediateRender", () => {});
  const parentInput: string[] = [];
  tui.setFocus({
    render: () => [],
    invalidate: () => {},
    handleInput: (data) => parentInput.push(data),
  });
  const snap = { id: "sa-1", status: "running" };
  const view = {
    size: () => 1,
    list: () => [snap],
    get: () => snap,
    subscribe: () => () => {},
    subscribeTo: () => () => {},
  } as never;
  const ctx = {
    ui: {
      custom: (factory: (tui: TUI, theme: never, keys: KeybindingsManager, done: () => void) => Component & { dispose?(): void }) =>
        new Promise<null>((resolve) => {
          const component = factory(tui, {} as never, keys, () => {
            tui.hideOverlay();
            resolve(null);
            component.dispose?.();
          });
          tui.showOverlay(component);
          t.after(() => component.dispose?.());
        }),
    },
  } as never;
  return { tui, ctx, view, parentInput, dispatch: (data: string) => host.handleTerminalInput(data) };
}

for (const direct of [false, true]) {
  test(`${direct ? "direct takeover" : "dashboard"} consumes every cancel repeat until the guard expires`, async (t) => {
    t.mock.timers.enable({ apis: ["Date", "setTimeout", "setInterval"] });
    const h = createHostHarness(t);
    const opened = direct
      ? openSubagentTakeover(h.ctx, h.view, "sa-1")
      : openSubagentPicker(h.ctx, h.view);
    h.dispatch("\x1b");
    assert.equal(h.tui.hasOverlay(), false);
    assert.deepEqual(h.parentInput, [], "closing key must not be dispatched twice");
    for (const key of ["\x1b[27;1:3u", "\x1b", "\x1b[27;1:2u", "\x1b"]) {
      h.dispatch(key);
    }
    assert.deepEqual(h.parentInput, [], "release/repeat events must not expose the parent");
    h.dispatch("a");
    assert.deepEqual(h.parentInput, ["a"], "normal typing must remain available");
    t.mock.timers.tick(500);
    h.dispatch("\x1b");
    assert.deepEqual(h.parentInput, ["a", "\x1b"], "later intentional interrupt must work");
    await opened;
  });
}

test("direct takeover guards a remapped interrupt without blocking another overlay", async (t) => {
  t.mock.timers.enable({ apis: ["Date", "setTimeout", "setInterval"] });
  const h = createHostHarness(t, new KeybindingsManager({ "app.interrupt": "ctrl+q" }));
  const opened = openSubagentTakeover(h.ctx, h.view, "sa-1");
  h.dispatch("\x11");
  h.dispatch("\x11");
  h.dispatch("\x11");
  assert.deepEqual(h.parentInput, []);
  const overlayInput: string[] = [];
  h.tui.showOverlay({ render: () => [], invalidate: () => {}, handleInput: (data) => overlayInput.push(data) });
  h.dispatch("\x1b");
  assert.deepEqual(overlayInput, ["\x1b"]);
  h.tui.hideOverlay();
  t.mock.timers.tick(500);
  h.dispatch("\x11");
  assert.deepEqual(h.parentInput, ["\x11"]);
  await opened;
});

function layoutWidth(layout: DashboardColumnLayout) {
  const columns = [
    layout.state,
    layout.title,
    layout.backend,
    layout.model,
    layout.reasoning,
    layout.context,
    layout.elapsed,
  ].filter((value): value is number => value !== undefined);
  return (
    layout.marker +
    columns.reduce((total, value) => total + value, 0) +
    (columns.length - 1) * 3
  );
}

test("dashboard table uses the full width and hides metadata by priority", () => {
  const wide = dashboardColumnLayout(98);
  assert.equal(layoutWidth(wide), 98);
  assert.deepEqual(wide, {
    marker: 2,
    state: 1,
    title: 22,
    backend: 7,
    model: 24,
    reasoning: 8,
    context: 10,
    elapsed: 6,
  });

  const longModel = dashboardColumnLayout(98, 26);
  assert.equal(layoutWidth(longModel), 98);
  assert.equal(longModel.model, 26);
  assert.equal(longModel.title, 20);

  const medium = dashboardColumnLayout(74);
  assert.equal(layoutWidth(medium), 74);
  assert.equal(medium.model, undefined);
  assert.equal(medium.reasoning, 8);
  assert.equal(medium.context, 10);

  const narrow = dashboardColumnLayout(60);
  assert.equal(layoutWidth(narrow), 60);
  assert.equal(narrow.model, undefined);
  assert.equal(narrow.context, undefined);
  assert.equal(narrow.reasoning, undefined);
  assert.equal(narrow.backend, 7);
});

test("dashboard selection follows its subagent id and falls back by row", () => {
  const selection: DashboardSelection = { id: "sa-7", index: 6 };

  reconcileDashboardSelection(selection, [
    { id: "sa-new" },
    ...Array.from({ length: 8 }, (_, index) => ({ id: `sa-${index + 1}` })),
  ]);
  assert.deepEqual(selection, { id: "sa-7", index: 7 });

  reconcileDashboardSelection(selection, [
    ...Array.from({ length: 6 }, (_, index) => ({ id: `sa-${index + 1}` })),
    { id: "sa-8" },
    { id: "sa-9" },
  ]);
  assert.deepEqual(selection, { id: "sa-9", index: 7 });

  reconcileDashboardSelection(selection, [{ id: "sa-1" }, { id: "sa-2" }]);
  assert.deepEqual(selection, { id: "sa-2", index: 1 });

  reconcileDashboardSelection(selection, []);
  assert.deepEqual(selection, { id: undefined, index: 0 });
});

test("Escape after closing the dashboard does not interrupt the parent run", async () => {
  const snap = {
    id: "sa-1",
    origin: "model",
    backend: "codex",
    title: "demo",
    status: "running",
  };
  const view = {
    size: () => 1,
    list: () => [snap],
    get: (id: string) => (id === snap.id ? snap : undefined),
    subscribe: () => () => {},
    subscribeTo: () => () => {},
  } as never;
  const listeners = new Set<
    (data: string) => { consume?: boolean } | undefined
  >();
  let overlayVisible = false;
  let mainRunInterrupted = false;
  let component: { handleInput(data: string): void; dispose?(): void };
  const tui = {
    requestRender: () => {},
    hasOverlay: () => overlayVisible,
    addInputListener: (
      listener: (data: string) => { consume?: boolean } | undefined,
    ) => {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    terminal: { rows: 30 },
  } as never;
  const theme = {} as never;
  const keybindings = {
    matches: (data: string, binding: string) =>
      binding === "tui.select.cancel" && data === "escape",
    getKeys: () => [],
  } as never;
  const mainEditor = {
    handleInput: (data: string) => {
      if (data === "escape") mainRunInterrupted = true;
    },
  };
  const dispatch = (data: string) => {
    for (const listener of [...listeners]) {
      if (listener(data)?.consume) return;
    }
    if (overlayVisible) component.handleInput(data);
    else mainEditor.handleInput(data);
  };

  const ctx = {
    ui: {
      notify: () => {},
      custom: async (
        factory: (
          tui: never,
          theme: never,
          keys: never,
          done: (value: null) => void,
        ) => { handleInput(data: string): void; dispose?(): void },
      ) => {
        overlayVisible = true;
        const done = () => {
          overlayVisible = false;
          component.dispose?.();
        };
        component = factory(tui, theme, keybindings, done);
        dispatch("escape");
        assert.equal(overlayVisible, false);
        dispatch("escape");
        assert.equal(mainRunInterrupted, false);
        return null;
      },
    },
  } as never;

  await openSubagentPicker(ctx, view);
});

test("repeated Escape after takeover cannot cascade through the dashboard", async () => {
  const snap = {
    id: "sa-1",
    origin: "model",
    backend: "codex",
    title: "demo",
    status: "running",
  };
  const view = {
    size: () => 1,
    list: () => [snap],
    get: (id: string) => (id === snap.id ? snap : undefined),
    subscribe: () => () => {},
    subscribeTo: () => () => {},
  } as never;
  const tui = {
    requestRender: () => {},
    hasOverlay: () => true,
    addInputListener: () => () => {},
    terminal: { rows: 30 },
  } as never;
  const theme = {} as never;
  const keybindings = {
    matches: (data: string, binding: string) =>
      (binding === "tui.select.confirm" && data === "enter") ||
      (binding === "tui.select.cancel" && data === "escape") ||
      (binding === "app.interrupt" && data === "escape"),
    getKeys: () => [],
  } as never;
  const phases: string[] = [];
  let dashboardClosed = false;

  const ctx = {
    ui: {
      notify: () => {},
      custom: async (factory: (tui: never, theme: never, keys: never, done: (value: null) => void) => { handleInput(data: string): void; dispose?(): void }) => {
        const phase = phases.length === 0 ? "dashboard" : "takeover";
        phases.push(phase);
        let component: { handleInput(data: string): void; dispose?(): void };
        const done = () => {
          if (phase === "dashboard") dashboardClosed = true;
          component.dispose?.();
        };
        component = factory(tui, theme, keybindings, done);
        if (phase === "dashboard") {
          component.handleInput("enter");
          await Promise.resolve();
          await Promise.resolve();
          assert.equal(dashboardClosed, false);

          component.handleInput("escape");
          phases.push("repeat-escape-consumed");
          assert.equal(dashboardClosed, false);

          await new Promise((resolve) => setTimeout(resolve, 510));
          component.handleInput("escape");
          phases.push("dashboard-close");
        } else {
          component.handleInput("escape");
        }
        return null;
      },
    },
  } as never;

  await openSubagentPicker(ctx, view);
  assert.deepEqual(phases, [
    "dashboard",
    "takeover",
    "repeat-escape-consumed",
    "dashboard-close",
  ]);
  assert.equal(dashboardClosed, true);
});
