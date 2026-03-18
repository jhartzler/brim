import AppKit

/// Describes the notch region on a MacBook screen.
/// All coordinates are in screen coordinate space (origin bottom-left).
struct NotchGeometry {
    let notchLeftX: CGFloat    // left edge of notch
    let notchRightX: CGFloat   // right edge of notch
    let notchHeight: CGFloat   // how far down from screen top the notch extends
    let screenWidth: CGFloat
    let screenMaxY: CGFloat    // top of screen in global coords

    var notchWidth: CGFloat { notchRightX - notchLeftX }
    var leftSegmentWidth: CGFloat { notchLeftX }
    var rightSegmentWidth: CGFloat { screenWidth - notchRightX }

    /// Detect notch from the main screen. Returns nil if no notch.
    static func detect(from screen: NSScreen? = .main) -> NotchGeometry? {
        guard let screen else { return nil }
        guard screen.safeAreaInsets.top > 0 else { return nil }

        guard let leftArea = screen.auxiliaryTopLeftArea,
              let rightArea = screen.auxiliaryTopRightArea else {
            return nil
        }

        let screenFrame = screen.frame
        let notchLeftX = leftArea.maxX
        let notchRightX = rightArea.origin.x

        guard notchRightX > notchLeftX else { return nil }

        return NotchGeometry(
            notchLeftX: notchLeftX - screenFrame.origin.x,
            notchRightX: notchRightX - screenFrame.origin.x,
            notchHeight: screen.safeAreaInsets.top,
            screenWidth: screenFrame.width,
            screenMaxY: screenFrame.maxY
        )
    }

    /// Create with explicit values (for testing).
    static func mock(
        notchLeftX: CGFloat,
        notchRightX: CGFloat,
        notchHeight: CGFloat,
        screenWidth: CGFloat,
        screenMaxY: CGFloat = 956
    ) -> NotchGeometry {
        NotchGeometry(
            notchLeftX: notchLeftX,
            notchRightX: notchRightX,
            notchHeight: notchHeight,
            screenWidth: screenWidth,
            screenMaxY: screenMaxY
        )
    }
}
