import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const SCRIPT = `
ObjC.import("AppKit");
ObjC.import("CoreGraphics");
JSON.stringify({
  bundleId: ObjC.unwrap($.NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier),
  idleSeconds: $.CGEventSourceSecondsSinceLastEventType(1, 4294967295)
});`;

// No System Events/Accessibility permission required. Unknown state must not
// silence a notification (including Linux/remote agents and probe failures).
export async function isAttendingRex(
  exec: ExtensionAPI["exec"],
  platform: string = process.platform,
): Promise<boolean> {
  if (platform !== "darwin") return false;
  try {
    const [result, consoleState] = await Promise.all([
      exec("/usr/bin/osascript", ["-l", "JavaScript", "-e", SCRIPT], { timeout: 2000 }),
      exec("/usr/sbin/ioreg", ["-n", "Root", "-d", "1"], { timeout: 2000 }),
    ]);
    if (result.code !== 0 || consoleState.code !== 0) return false;
    if (!/"IOConsoleLocked"\s*=\s*No\b/.test(consoleState.stdout)
      || /"IOConsoleLocked"\s*=\s*Yes\b/.test(consoleState.stdout)) return false;
    const state = JSON.parse(result.stdout);
    return state.bundleId === "com.superlogical.rex"
      && typeof state.idleSeconds === "number"
      && Number.isFinite(state.idleSeconds)
      && state.idleSeconds >= 0 && state.idleSeconds < 60;
  } catch {
    return false;
  }
}
