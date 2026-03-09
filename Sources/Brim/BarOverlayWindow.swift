import AppKit

final class BarOverlayWindow: NSWindow {
    static let barHeight: CGFloat = 4

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]

        let frame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - Self.barHeight,
            width: screen.frame.width,
            height: Self.barHeight
        )

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Must be above the menu bar (level 24) to render on top of it
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .systemBlue
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
    }

    // Prevent macOS from constraining this window below the menu bar
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }

    func reposition(progress: Double = 1.0) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let fullWidth = screen.frame.width
        let barWidth = fullWidth * progress
        let frame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - Self.barHeight,
            width: barWidth,
            height: Self.barHeight
        )
        setFrame(frame, display: true)
    }
}
