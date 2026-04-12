import AppKit
import QuartzCore

final class BarOverlayWindow: NSWindow {
    static let barHeight: CGFloat = 4

    private(set) var notchGeometry: NotchGeometry?
    private(set) var shapeLayer: CAShapeLayer?
    var currentScreen: NSScreen?

    var hasNotch: Bool { notchGeometry != nil }

    /// Create a bar overlay window for a specific screen.
    /// If no screen is provided, uses NSScreen.main.
    init(screen: NSScreen? = nil) {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens[0]
        let notch = NotchGeometry.detect(from: targetScreen)

        let windowHeight: CGFloat
        let windowY: CGFloat

        if let notch {
            windowHeight = notch.notchHeight + Self.barHeight
            windowY = targetScreen.frame.maxY - windowHeight
        } else {
            windowHeight = Self.barHeight
            windowY = targetScreen.frame.maxY - Self.barHeight
        }

        let frame = NSRect(
            x: targetScreen.frame.origin.x,
            y: windowY,
            width: targetScreen.frame.width,
            height: windowHeight
        )

        super.init(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false

        notchGeometry = notch
        currentScreen = targetScreen

        if let notch {
            setupNotchMode(notch: notch, windowHeight: windowHeight)
        } else {
            backgroundColor = Settings.shared.barColor.withAlphaComponent(CGFloat(Settings.shared.barAlpha))
        }
    }

    private func setupNotchMode(notch: NotchGeometry, windowHeight: CGFloat) {
        backgroundColor = .clear

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        contentView.wantsLayer = true
        contentView.layer?.isGeometryFlipped = false  // keep default bottom-left origin
        self.contentView = contentView

        let layer = CAShapeLayer()
        layer.lineWidth = Self.barHeight
        layer.strokeColor = Settings.shared.barColor.withAlphaComponent(CGFloat(Settings.shared.barAlpha)).cgColor
        layer.fillColor = nil
        layer.lineCap = .round
        layer.path = NotchBarPathBuilder.buildPath(geometry: notch, windowHeight: windowHeight)
        layer.frame = contentView.bounds

        contentView.layer?.addSublayer(layer)
        shapeLayer = layer
    }

    // Prevent macOS from constraining this window below the menu bar
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }

    /// Update progress. In notch mode, only updates strokeEnd (window frame is static).
    /// Call repositionFrame() separately when the window needs to move (show, rebuild).
    func updateProgress(_ progress: Double) {
        if hasNotch {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            shapeLayer?.strokeEnd = CGFloat(progress)
            CATransaction.commit()
        } else {
            repositionFrame(progress: progress)
        }
    }

    /// Reposition the window frame on its assigned screen.
    /// Uses the screen this window was created for rather than NSScreen.main,
    /// so the bar stays on the correct display even when focus moves.
    func repositionFrame(progress: Double = 1.0) {
        let screen = currentScreen ?? NSScreen.main ?? NSScreen.screens[0]

        if hasNotch, let notch = notchGeometry {
            let windowHeight = notch.notchHeight + Self.barHeight
            let frame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - windowHeight,
                width: screen.frame.width,
                height: windowHeight
            )
            setFrame(frame, display: true)
        } else {
            // Non-notch: resize width for progress (existing behavior)
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

    /// Rebuild for a potentially different screen configuration (notch <-> non-notch).
    /// Uses the window's assigned screen rather than NSScreen.main.
    func rebuild() {
        let screen = currentScreen ?? NSScreen.main ?? NSScreen.screens[0]
        let newNotch = NotchGeometry.detect(from: screen)

        // Clean up old layer if present
        shapeLayer?.removeFromSuperlayer()
        shapeLayer = nil
        notchGeometry = nil
        currentScreen = screen

        if let newNotch {
            let windowHeight = newNotch.notchHeight + Self.barHeight
            notchGeometry = newNotch
            setupNotchMode(notch: newNotch, windowHeight: windowHeight)

            let frame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - windowHeight,
                width: screen.frame.width,
                height: windowHeight
            )
            setFrame(frame, display: true)
        } else {
            backgroundColor = Settings.shared.barColor.withAlphaComponent(CGFloat(Settings.shared.barAlpha))
            let frame = NSRect(
                x: screen.frame.origin.x,
                y: screen.frame.maxY - Self.barHeight,
                width: screen.frame.width,
                height: Self.barHeight
            )
            setFrame(frame, display: true)
        }
    }
}