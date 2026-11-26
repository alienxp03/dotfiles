import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  let fast = true;

  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setStatus("fast", fast && ctx.model?.provider === "openai-codex" ? "FAST" : undefined);
  });

  pi.registerCommand("fast", {
    description: "Toggle the OpenAI Codex priority tier",
    handler: async (_args, ctx) => {
      fast = !fast;
      ctx.ui.setStatus("fast", fast && ctx.model?.provider === "openai-codex" ? "FAST" : undefined);
      ctx.ui.notify(`Codex priority tier: ${fast ? "on" : "off"}`, "info");
    },
  });

  pi.on("model_select", (event, ctx) => {
    ctx.ui.setStatus("fast", fast && event.model.provider === "openai-codex" ? "FAST" : undefined);
  });

  pi.on("before_provider_request", (event, ctx) => {
    if (!fast || ctx.model?.provider !== "openai-codex") return;
    const payload = event.payload;
    if (payload && typeof payload === "object" && !Array.isArray(payload)) {
      return { ...payload, service_tier: "priority" };
    }
  });
}
