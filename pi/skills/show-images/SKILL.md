---
name: show-images
description: Use whenever the user asks to see, show, or review any image, screenshot, mockup, or design — including pen.dev canvas work — because the user is often AFK and views the session through Paseo, where tool-result image attachments do NOT render. Always deliver images as markdown-embedded workspace-relative paths in the reply text, never as attachments.
---

# Showing images to an AFK Paseo viewer

The user frequently reviews sessions asynchronously through Paseo. In that viewer:

- Images attached to tool results (`read` on a PNG, pen `TakeScreenshot`) **do not render**. The user sees nothing.
- `open` / Preview / bringing an app forward **does not help** — they are not at the Mac.
- What **works**: markdown images in the assistant reply, pointing at files inside the workspace, plus a self-contained HTML gallery as fallback.

## Procedure

1. **Get the image into the workspace as a real file.**
   - pen.dev canvas: use `execute` → `Export([ids], "png", "./<folder>", {scale: 2})` — not `TakeScreenshot`. Note: Export prefixes the output path with the .pen file's directory; flatten the result with `mv` if it doubles up.
   - Screenshots of apps/windows: save with `screencapture -x <path>` or export from the source tool to a workspace path.

2. **Embed every image in the reply text as markdown**, one per line, with a caption alt text and a workspace-relative path:

   ```markdown
   ![01 · Frame caption](docs/design/exports/frame-01.png)
   ```

   Put the markdown images at the **top of the reply**, before any prose. Keep each on its own line. Never wrap them in code fences.

3. **Add the HTML fallback** for viewers that don't render workspace-relative markdown either. Write one self-contained `index.html` next to the images with every PNG base64-embedded as a data URL (no external refs), then link the path:

   ```bash
   python3 - <<'EOF'
   import base64
   frames = [("a.png", "Caption A"), ("b.png", "Caption B")]
   parts = ['<!doctype html><meta charset="utf-8"><title>Images</title>',
            '<body style="background:#111;color:#ddd;font-family:sans-serif;padding:32px;display:flex;flex-direction:column;gap:32px;align-items:center">']
   for f, cap in frames:
       b64 = base64.b64encode(open(f, "rb").read()).decode()
       parts.append(f'<figure style="margin:0;max-width:1100px"><figcaption style="color:#E4A66A;font-weight:600;margin-bottom:8px">{cap}</figcaption><img style="max-width:100%;border-radius:12px" src="data:image/png;base64,{b64}"></figure>')
   open("index.html", "w").write("".join(parts) + "</body>")
   EOF
   ```

4. **Close the reply** by naming the fallback paths: the `index.html` (openable from Paseo's file browser) and the folder of PNGs.

## Rules

- Never rely solely on tool-result attachments to deliver images the user asked to see — assume they are invisible.
- Never rely on `open`, Preview, Finder, or any on-screen Mac action — the user may be remote.
- Multiple images: embed all of them in order, each with a distinguishing caption; don't collapse into one montage unless asked.
- Scale exports at 2× so text in mockups stays readable when zoomed.
