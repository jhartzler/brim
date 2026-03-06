import AppKit

final class BarOverlayView: NSView {
    var progress: Double = 1.0 {
        didSet { needsDisplay = true }
    }

    var barColor: NSColor = .systemBlue {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard progress > 0 else { return }

        let screen = NSScreen.main
        let safeAreaInsets = screen?.safeAreaInsets ?? NSEdgeInsets()

        barColor.setFill()

        // If there's a notch (top safe area inset > 0), draw two segments
        if safeAreaInsets.top > 0, let screen {
            let notchWidth = screen.frame.width - safeAreaInsets.left - safeAreaInsets.right
            let notchLeft = safeAreaInsets.left
            let notchRight = notchLeft + notchWidth
            let totalDrawableWidth = safeAreaInsets.left + (screen.frame.width - notchRight)
            let fillWidth = totalDrawableWidth * progress

            // Left segment
            let leftSegmentWidth = min(fillWidth, safeAreaInsets.left)
            if leftSegmentWidth > 0 {
                let leftRect = NSRect(x: 0, y: 0, width: leftSegmentWidth, height: bounds.height)
                leftRect.fill()
            }

            // Right segment
            let remainingFill = fillWidth - safeAreaInsets.left
            if remainingFill > 0 {
                let rightStart = notchRight
                let rightRect = NSRect(x: rightStart, y: 0, width: remainingFill, height: bounds.height)
                rightRect.fill()
            }
        } else {
            // No notch — single bar across full width
            let fillWidth = bounds.width * progress
            let barRect = NSRect(x: 0, y: 0, width: fillWidth, height: bounds.height)
            barRect.fill()
        }
    }
}
