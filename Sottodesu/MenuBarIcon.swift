import AppKit

/// The menu bar version of the app icon: a sun above three bars, longest to shortest.
/// It is a template image, so macOS tints it for light and dark menu bars.
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            let u = rect.width / 100
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 58 * u, y: 2 * u, width: 36 * u, height: 36 * u)).fill()
            let bars: [(y: CGFloat, length: CGFloat)] = [(54, 90), (70, 66), (86, 42)]
            for bar in bars {
                let frame = NSRect(x: 4 * u, y: bar.y * u, width: bar.length * u, height: 10 * u)
                NSBezierPath(roundedRect: frame, xRadius: 5 * u, yRadius: 5 * u).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Sottodesu"
        return image
    }()
}
