import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";
import {
  DefaultResourceLoader,
  SettingsManager,
} from "@earendil-works/pi-coding-agent";
import { childExtensionsOverride } from "./src/child-extensions.ts";

test("headless child excludes only the global cmux lifecycle hook", async () => {
  mkdirSync("aux", { recursive: true });
  const root = mkdtempSync(join(process.cwd(), "aux", "pi-child-extensions-"));
  const agentDir = join(root, "agent");
  const cwd = join(root, "project");
  const globalExtensions = join(agentDir, "extensions");
  const projectExtensions = join(cwd, ".pi", "extensions");
  mkdirSync(globalExtensions, { recursive: true });
  mkdirSync(projectExtensions, { recursive: true });
  writeFileSync(join(cwd, "AGENTS.md"), "Fixture project context.\n");
  writeFileSync(join(globalExtensions, "cmux-session.ts"), `
    export default (pi) => {
      pi.on("session_start", () => globalThis.__piChildHookEvents.push("global:start"));
      pi.on("session_shutdown", () => globalThis.__piChildHookEvents.push("global:shutdown"));
    };
  `);
  writeFileSync(join(globalExtensions, "other.ts"), `
    export default (pi) => {
      pi.on("session_start", () => globalThis.__piChildHookEvents.push("other:start"));
      pi.on("session_shutdown", () => globalThis.__piChildHookEvents.push("other:shutdown"));
    };
  `);
  writeFileSync(join(projectExtensions, "cmux-session.ts"), `
    export default (pi) => {
      pi.on("session_start", () => globalThis.__piChildHookEvents.push("project:start"));
      pi.on("session_shutdown", () => globalThis.__piChildHookEvents.push("project:shutdown"));
    };
  `);
  const events: string[] = [];
  const globalWithEvents = globalThis as typeof globalThis & { __piChildHookEvents?: string[] };
  globalWithEvents.__piChildHookEvents = events;

  try {
    const settingsManager = SettingsManager.create(cwd, agentDir, { projectTrusted: true });
    const options = {
      cwd,
      agentDir,
      settingsManager,
      systemPrompt: "Fixture system prompt.",
      appendSystemPrompt: ["Fixture appended prompt."],
    };
    const parentLoader = new DefaultResourceLoader(options);
    const childLoader = new DefaultResourceLoader({
      ...options,
      extensionsOverride: childExtensionsOverride(agentDir),
    });
    await parentLoader.reload();
    await childLoader.reload();

    const globalCmuxPath = join(globalExtensions, "cmux-session.ts");
    const parent = parentLoader.getExtensions();
    const child = childLoader.getExtensions();
    assert.deepEqual(parent.errors, []);
    assert.deepEqual(child.errors, []);
    assert.ok(parent.extensions.some((extension) => extension.resolvedPath === globalCmuxPath));
    assert.ok(!child.extensions.some((extension) => extension.resolvedPath === globalCmuxPath));
    assert.ok(child.extensions.some((extension) => extension.resolvedPath === join(globalExtensions, "other.ts")));
    assert.ok(child.extensions.some((extension) => extension.resolvedPath === join(projectExtensions, "cmux-session.ts")));
    const parentCmux = parent.extensions.find((extension) => extension.resolvedPath === globalCmuxPath)!;
    for (const handler of parentCmux.handlers.get("session_start") ?? []) {
      await handler({ type: "session_start" } as never, {} as never);
    }
    assert.deepEqual(events, ["global:start"], "native parent loader keeps the hook");
    events.length = 0;

    const alias = join(globalExtensions, "alias.ts");
    symlinkSync(globalCmuxPath, alias);
    const override = childExtensionsOverride(agentDir);
    const withAlias = override({
      ...parent,
      extensions: [...parent.extensions, { ...parentCmux, resolvedPath: alias }],
      errors: [{ path: alias, error: "same file" }, { path: join(globalExtensions, "other.ts"), error: "other file" }],
    });
    assert.ok(!withAlias.extensions.some((extension) => extension.resolvedPath === alias));
    assert.deepEqual(withAlias.errors, [{ path: join(globalExtensions, "other.ts"), error: "other file" }]);
    assert.equal(withAlias.runtime, parent.runtime);

    for (const type of ["session_start", "session_shutdown"]) {
      for (const extension of child.extensions) {
        for (const handler of extension.handlers.get(type) ?? []) {
          await handler({ type } as never, {} as never);
        }
      }
    }
    assert.deepEqual(events.slice(0, 2).sort(), ["other:start", "project:start"]);
    assert.deepEqual(events.slice(2).sort(), ["other:shutdown", "project:shutdown"]);
    assert.ok(childLoader.getAgentsFiles().agentsFiles.length > 0);
    assert.deepEqual(childLoader.getAgentsFiles(), parentLoader.getAgentsFiles());
    assert.deepEqual(childLoader.getSkills(), parentLoader.getSkills());
    assert.deepEqual(childLoader.getPrompts(), parentLoader.getPrompts());
    assert.deepEqual(childLoader.getThemes(), parentLoader.getThemes());
    assert.equal(childLoader.getSystemPrompt(), parentLoader.getSystemPrompt());
    assert.equal(childLoader.getSystemPrompt(), "Fixture system prompt.");
    assert.deepEqual(childLoader.getAppendSystemPrompt(), parentLoader.getAppendSystemPrompt());

    const untrustedLoader = new DefaultResourceLoader({
      cwd,
      agentDir,
      settingsManager: SettingsManager.create(cwd, agentDir, { projectTrusted: false }),
      extensionsOverride: childExtensionsOverride(agentDir),
    });
    await untrustedLoader.reload();
    const untrustedPaths = untrustedLoader.getExtensions().extensions.map((extension) => extension.resolvedPath);
    assert.ok(untrustedPaths.includes(join(globalExtensions, "other.ts")));
    assert.ok(!untrustedPaths.includes(join(projectExtensions, "cmux-session.ts")));
  } finally {
    delete globalWithEvents.__piChildHookEvents;
    rmSync(root, { recursive: true, force: true });
  }
});
