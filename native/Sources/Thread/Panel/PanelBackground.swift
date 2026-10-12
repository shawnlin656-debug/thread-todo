import AppKit
import SwiftUI

/// The panel's material. A SwiftUI `glassEffect` only samples content inside its own
/// window, so over the desktop it shows nothing; these AppKit views sample what is
/// behind the window instead.
struct PanelBackground: View {
    static let liquidGlassKey = "useLiquidGlass"

    @AppStorage(Self.liquidGlassKey) private var useLiquidGlass = false
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if useLiquidGlass {
            LiquidGlassBackground(cornerRadius: cornerRadius)
        } else {
            VibrancyBackground(cornerRadius: cornerRadius)
                // The blur view punches through anything beneath it, so this shape only contributes its shadow.
                .background { shape.fill(.black).shadow(color: .black.opacity(0.28), radius: 22, y: 8) }
                .overlay { shape.strokeBorder(.white.opacity(0.22), lineWidth: 0.5) }
        }
    }
}

/// Frosted system material blurring whatever is behind the window. Always available.
private struct VibrancyBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        // Stay frosted even though this accessory app is never the active one.
        view.state = .active
        view.maskImage = Self.roundedMask(radius: cornerRadius)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}

    /// A stretchable rounded-rectangle image; the effect view is clipped to its alpha.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

/// The system Liquid Glass view from macOS 26.
private struct LiquidGlassBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = cornerRadius
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {}
}
