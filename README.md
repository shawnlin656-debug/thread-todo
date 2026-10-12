# Thread

A side-panel todo for macOS that keeps your place when work gets interrupted. This repository is a static web demo of the interaction and visual design; it is not yet a native app.

## What it does

- **Interrupt without losing the thread.** Typing a task and pressing Enter starts it immediately. The task you were on moves to the *return path* and comes back automatically when the interruption is completed.
- **Queue for later.** Shift+Enter adds a task to the queue without touching your current focus.
- **Live Focus island.** The current task and its timer sit on either side of the MacBook camera notch. Hovering shows what comes next, and the left wing periodically flips to preview it.
- **Liquid Glass panel.** The side panel uses real edge refraction (an SVG displacement map derived from Snell's law) and a normal-based specular rim.
- Follows the system light or dark appearance, respects reduced motion and reduced transparency, and saves state to `localStorage`.

## Run it

No build step. Serve the folder with any static server and open it:

```sh
python3 -m http.server 4173
# http://localhost:4173
```

Append `?reset` to the URL to restore the sample tasks.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | Markup: simulated desktop, notch island, side panel |
| `styles.css` | Design tokens and all styling |
| `app.js` | Task state, persistence, rendering and events |
| `glass.js` | Liquid Glass material (refraction and specular rim) |
| `PRODUCT.md` | Product intent and design principles |

## Limitations

- Edge refraction needs a Chromium-based browser. Safari and Firefox fall back to a plain backdrop blur with the same highlight.
- The notch is a fixed 184 × 32 pt mock. Matching a specific MacBook requires `NSScreen` safe-area data, which only a native app can read.
- The focus timer counts only while the page is open.

## References

- [Liquid Glass in CSS and SVG](https://kube.io/blog/liquid-glass-css-svg/) for the refraction model
- [Apple Human Interface Guidelines: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
