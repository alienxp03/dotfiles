import { randomUUID } from "node:crypto";
import { mkdirSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// Raptor matches this metadata to the native Rex status owner. No terminal output.
export default function (pi: ExtensionAPI) {
  let timer: ReturnType<typeof setInterval> | undefined;
  let file: string | undefined;
  let blockId = "";
  let sessionId = "";

  function stop() {
    if (timer) clearInterval(timer);
    timer = undefined;
    const ownFile = file;
    file = undefined;
    if (ownFile) {
      try { unlinkSync(ownFile); } catch { /* Best-effort cleanup. */ }
    }
  }

  function update(ctx: ExtensionContext) {
    if (!file) return;
    let temporary: string | undefined;
    try {
      const metadata = {
        pid: process.pid,
        app: "pi",
        name: ctx.sessionManager.getSessionName() || "",
        block_id: blockId,
        session_id: sessionId,
        updated_at: new Date().toISOString(),
      };
      mkdirSync(dirname(file), { recursive: true, mode: 0o700 });
      temporary = `${file}.${randomUUID()}.tmp`;
      writeFileSync(temporary, JSON.stringify(metadata), { mode: 0o600, flag: "wx" });
      renameSync(temporary, file);
    } catch {
      // Metadata failures must not interrupt Pi. The next heartbeat retries.
    } finally {
      if (temporary) {
        try { unlinkSync(temporary); } catch { /* Renamed or unavailable. */ }
      }
    }
  }

  pi.on("session_start", (_event, ctx) => {
    stop();
    const { REX_SESSION, REX_BLOCK, XDG_CACHE_HOME, HOME } = process.env;
    if (ctx.mode !== "tui" || !REX_SESSION?.trim() || !REX_BLOCK?.trim()) return;
    const cache = XDG_CACHE_HOME || (HOME ? join(HOME, "Library", "Caches") : undefined);
    if (!cache) return;

    blockId = REX_BLOCK;
    sessionId = REX_SESSION;
    file = join(cache, "raptor", "agents", `pi-${process.pid}.json`);
    update(ctx);
    timer = setInterval(() => update(ctx), 5000);
    timer.unref();
  });

  pi.on("session_info_changed", (_event, ctx) => update(ctx));
  pi.on("session_shutdown", stop);
}
