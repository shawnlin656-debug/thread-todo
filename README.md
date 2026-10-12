# Thread

A side-panel todo for macOS that keeps your place when work gets interrupted.

The repository holds two implementations of the same design:

- **`native/`** is the macOS app, written in SwiftUI. It floats at the edge of the screen above other apps and puts the current task beside the MacBook camera notch.
- **The repository root** is the original static web demo used to work out the interaction and visual design.

## What it does

- **Interrupt without losing the thread.** Typing a task and pressing Enter starts it immediately. The task you were on moves to the *return path* and comes back automatically when the interruption is completed.
- **Queue for later.** Shift+Enter adds a task to the queue without touching your current focus.
- **Live Focus island.** The current task and its timer sit on either side of the MacBook camera notch. Hovering shows what comes next, and the left wing periodically flips to preview it.
- **Liquid Glass panel.** The side panel uses real edge refraction (an SVG displacement map derived from Snell's law) and a normal-based specular rim.
- Follows the system light or dark appearance, respects reduced motion and reduced transparency, and saves state to `localStorage`.

## macOS app

Requires macOS 26 and the Xcode Command Line Tools (full Xcode is not needed).

```sh
cd native
./scripts/build-app.sh      # produces native/build/Thread.app
open build/Thread.app
```

Thread runs as a menu bar accessory with no Dock icon; quit it from its menu bar item. The side panel tucks into the right edge of the screen like an auto-hiding Dock: rest the pointer on the edge to slide it out, and pin it from the panel or the menu bar item to keep it open. Tasks are saved to `~/Library/Application Support/Thread/state.json`.

| Path | Purpose |
| --- | --- |
| `Sources/Thread/App` | App entry point, menu bar item, app delegate |
| `Sources/Thread/Model` | `TaskItem` and `TaskStore` (state, actions, persistence) |
| `Sources/Thread/Panel` | The floating side panel and its sections |
| `Sources/Thread/Notch` | Notch geometry detection and the Live Focus island |
| `Sources/Thread/Support` | Floating window class and text formatting |

The side panel uses a frosted system material that blurs what is behind the window, with an experimental Liquid Glass option in the menu bar item. The island reads the notch position from `NSScreen` at run time, so it fits whichever MacBook it runs on; on a display without a notch it hangs from the top centre of the menu bar.

The build is ad-hoc signed, so it runs on the Mac that built it but is not ready to distribute.

## Web demo

No build step. Serve the folder with any static server and open it:

```sh
python3 -m http.server 4173
# http://localhost:4173
```

Append `?reset` to the URL to restore the sample tasks.

### Files

| File | Purpose |
| --- | --- |
| `index.html` | Markup: simulated desktop, notch island, side panel |
| `styles.css` | Design tokens and all styling |
| `app.js` | Task state, persistence, rendering and events |
| `glass.js` | Liquid Glass material (refraction and specular rim) |
| `PRODUCT.md` | Product intent and design principles |

### Limitations of the web demo

- Edge refraction needs a Chromium-based browser. Safari and Firefox fall back to a plain backdrop blur with the same highlight.
- The notch is a fixed 184 × 32 pt mock. Matching a specific MacBook requires `NSScreen` safe-area data, which only a native app can read.
- The focus timer counts only while the page is open.

## References

- [Liquid Glass in CSS and SVG](https://kube.io/blog/liquid-glass-css-svg/) for the refraction model
- [Apple Human Interface Guidelines: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
