import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Only fixed status messages leave this machine; never prompts or tool output.
export default function (pi: ExtensionAPI) {
  let url = "";
  let active = false;
  let outcome = "completed";
  let finalText = "";
  let lastStatus = "";
  const waiting = new Set<string>();
  const requests = new Set<AbortController>();

  function reset() {
    active = false;
    outcome = "completed";
    finalText = "";
    lastStatus = "";
    waiting.clear();
  }

  async function push(status: string) {
    if (!url || status === lastStatus) return;
    lastStatus = status;
    const controller = new AbortController();
    requests.add(controller);
    const timer = setTimeout(() => controller.abort(), 5000);
    timer.unref();
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "text/plain; charset=utf-8", Title: "Pi" },
        body: status,
        signal: controller.signal,
        redirect: "error",
      });
      await response.body?.cancel();
      if (!response.ok) throw new Error(`ntfy HTTP ${response.status}`);
    } catch (error) {
      // Don't fail the agent or log the private topic URL.
      console.error(`[ntfy-push] Could not send ${status}`);
      if (lastStatus === status) lastStatus = "";
    } finally {
      clearTimeout(timer);
      requests.delete(controller);
    }
  }

  function setWaiting(key: string, enabled: boolean) {
    const wasWaiting = waiting.size > 0;
    if (enabled) waiting.add(key);
    else waiting.delete(key);
    if (!wasWaiting && waiting.size) void push("Input needed");
    if (wasWaiting && !waiting.size) lastStatus = "";
  }

  pi.on("session_start", () => {
    reset();
    url = "";
    try {
      const dir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
      const config = JSON.parse(readFileSync(join(dir, "ntfy.json"), "utf8"));
      if (config.enabled === false) return;
      const parsed = new URL(config.url);
      if (parsed.protocol !== "https:") throw new Error("HTTPS required");
      url = parsed.href;
    } catch {
      console.error("[ntfy-push] Missing or invalid ntfy.json; push disabled");
    }
  });

  // Reset once per user run, not at agent_start (which can repeat on retries).
  pi.on("before_agent_start", () => {
    if (!active) {
      reset();
      active = true;
    }
  });
  pi.on("agent_before_settle", (event) => { outcome = event.outcome; });
  pi.on("message_end", (event) => {
    if (event.message.role !== "assistant") return;
    finalText = event.message.content
      .filter((part) => part.type === "text")
      .map((part) => part.text).join("\n");
  });

  // Native extension dialogs, including permission confirmations.
  pi.on("ui_prompt_start", () => { setWaiting("ui", true); });
  pi.on("ui_prompt_end", () => { setWaiting("ui", false); });
  // The installed questionnaire exposes explicit wait events, including custom UI.
  pi.events.on("rpiv:ask-user:blocked", (data: unknown) => {
    if (!data || typeof data !== "object") return;
    const event = data as { active?: unknown; toolCallId?: unknown };
    if (typeof event.active === "boolean" && typeof event.toolCallId === "string") {
      setWaiting(`question:${event.toolCallId}`, event.active);
    }
  });

  pi.on("agent_settled", async (event) => {
    if (!active) return;
    active = false;
    // Escape/cancellation isn't a completion or failure notification.
    if (event.aborted || outcome === "aborted") return;
    const blocked = outcome === "error" || /(?:^|\n)\s*(?:blocked\b|(?:i(?:'m| am) )?(?:cannot|can't|unable to) (?:proceed|continue)\b)/i.test(finalText);
    // Plain-text questions have no dedicated lifecycle event; this is a fallback.
    const question = /\?\s*$/.test(finalText.trim());
    await push(blocked ? "Blocked" : waiting.size || question ? "Input needed" : "Done");
  });

  pi.on("session_shutdown", () => {
    url = "";
    reset();
    for (const request of requests) request.abort();
    requests.clear();
  });
}
