import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Pi 1.4 marks transcript messages with OSC 133 A/B/C. Rex interprets A as
// a new shell prompt and drops native working/blocked status records.
// Filter only these markers; leave Pi's native OSC 7501 reports untouched.
export default function (pi: ExtensionAPI) {
  let restore: (() => void) | undefined;

  function stop() {
    restore?.();
    restore = undefined;
  }

  pi.on("session_start", (_event, ctx) => {
    stop();
    if (ctx.mode !== "tui" || !process.stdout.isTTY
      || !process.env.REX_SESSION || !process.env.REX_BLOCK) return;

    const original = process.stdout.write;
    let active = true;
    const wrapped = ((chunk: string | Uint8Array, ...args: any[]) => {
      if (active && typeof chunk === "string") {
        chunk = chunk.replace(/\x1b\]133;[ABC](?:\x07|\x1b\\)/g, "");
      }
      return original.call(process.stdout, chunk, ...args);
    }) as typeof process.stdout.write;

    process.stdout.write = wrapped;
    restore = () => {
      active = false;
      // Another extension may have wrapped ours. Never remove its wrapper.
      if (process.stdout.write === wrapped) process.stdout.write = original;
    };
  });

  pi.on("session_shutdown", stop);
}
