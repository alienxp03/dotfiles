import { randomUUID } from "node:crypto";
import { mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";

export const sidebarStatuses = {
  idle: { label: "Idle", icon: "pause.circle.fill", color: "#8E8E93", priority: "0" },
  done: { label: "Done", icon: "checkmark.circle.fill", color: "#30D158", priority: "0" },
  running: { label: "Running", icon: "bolt.fill", color: "#4C8DFF", priority: "0" },
  waiting: { label: "Pi needs input", icon: "bell.fill", color: "#FF9F0A", priority: "100" },
  error: { label: "Pi error", icon: "exclamationmark.triangle.fill", color: "#FF453A", priority: "100" },
} as const;
export type SidebarPhase = keyof typeof sidebarStatuses;
const rank: Record<SidebarPhase, number> = { idle: 0, done: 1, running: 2, error: 3, waiting: 4 };
const heartbeatLifetimeMs = 30_000;

type PaneState = {
  workspaceId: string;
  surfaceId: string;
  sessionId: string;
  pid: number;
  token: string;
  updatedAt: number;
  phase: SidebarPhase;
};

function processAlive(pid: number): boolean {
  try { process.kill(pid, 0); return true; }
  catch (error) { return (error as NodeJS.ErrnoException).code === "EPERM"; }
}

type PaneOwner = Omit<PaneState, "token" | "updatedAt" | "phase"> & { stateDirectory: string };

// Only visible TUI parents publish here. Native hook records also contain
// in-process children, so they cannot identify the workspace's parent panes.
export class CmuxSidebarState {
  private readonly directory: string;
  private readonly file: string;
  private readonly token = randomUUID();

  private readonly owner: PaneOwner;
  private readonly isAlive: (pid: number) => boolean;

  constructor(owner: PaneOwner, isAlive = processAlive) {
    this.owner = owner;
    this.isAlive = isAlive;
    this.directory = join(owner.stateDirectory, "pi-sidebar-status", encodeURIComponent(owner.workspaceId));
    this.file = join(this.directory, `${encodeURIComponent(owner.surfaceId)}.json`);
  }

  async publish(phase: SidebarPhase): Promise<SidebarPhase> {
    await mkdir(this.directory, { recursive: true, mode: 0o700 });
    const temporary = `${this.file}.${randomUUID()}.tmp`;
    const state: PaneState = {
      workspaceId: this.owner.workspaceId, surfaceId: this.owner.surfaceId,
      sessionId: this.owner.sessionId, pid: this.owner.pid,
      token: this.token, phase, updatedAt: Date.now(),
    };
    try {
      await writeFile(temporary, JSON.stringify(state), { mode: 0o600, flag: "wx" });
      await rename(temporary, this.file);
    } finally {
      await rm(temporary, { force: true });
    }
    return (await this.aggregate()) ?? phase;
  }

  async remove(): Promise<SidebarPhase | undefined> {
    try {
      const state: PaneState = JSON.parse(await readFile(this.file, "utf8"));
      // Reload or session replacement may already have registered a successor.
      if (state.token === this.token) await rm(this.file, { force: true });
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
    return this.aggregate();
  }

  private async aggregate(): Promise<SidebarPhase | undefined> {
    let files: string[];
    try { files = await readdir(this.directory); }
    catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return undefined;
      throw error;
    }
    let result: SidebarPhase | undefined;
    for (const file of files) {
      if (!file.endsWith(".json")) continue;
      try {
        const state: PaneState = JSON.parse(await readFile(join(this.directory, file), "utf8"));
        if (state.workspaceId !== this.owner.workspaceId || !Object.hasOwn(rank, state.phase)
          || !Number.isInteger(state.pid) || state.pid <= 0 || !this.isAlive(state.pid)
          || !Number.isFinite(state.updatedAt) || Date.now() - state.updatedAt > heartbeatLifetimeMs) continue;
        if (result === undefined || rank[state.phase] > rank[result]) result = state.phase;
      } catch {
        // A closing pane or a damaged snapshot must not hide healthy siblings.
      }
    }
    return result;
  }
}
