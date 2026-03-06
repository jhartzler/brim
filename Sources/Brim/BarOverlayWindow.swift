import AppKit

final class BarOverlayWindow: NSWindow {
    static let barHeight: CGFloat = 4

    init() {
        guard let screen = NSScreen.main else {
            super.init(
                contentRect: .zero,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            return
        }

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

        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
    }

    func reposition() {
        guard let screen = NSScreen.main else { return }
        let frame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.maxY - Self.barHeight,
            width: screen.frame.width,
            height: Self.barHeight
        )
        setFrame(frame, display: true)
    }
}
