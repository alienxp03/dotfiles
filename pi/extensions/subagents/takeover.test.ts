import assert from "node:assert/strict";
import test from "node:test";
import {
  dashboardColumnLayout,
  openSubagentPicker,
  reconcileDashboardSelection,
  type DashboardColumnLayout,
  type DashboardSelection,
} from "./src/ui/takeover.ts";

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
  const tui = { requestRender: () => {}, terminal: { rows: 30 } } as never;
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
