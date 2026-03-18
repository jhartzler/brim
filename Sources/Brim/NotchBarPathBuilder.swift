import AppKit
import QuartzCore

enum NotchBarPathBuilder {

    static let cornerRadius: CGFloat = 8
    static let barThickness: CGFloat = 4

    /// Build the U-shaped path around the notch.
    ///
    /// Path traces: left edge -> right along top -> down left side of notch
    /// -> across bottom of notch -> up right side of notch -> right along top -> right edge.
    ///
    /// Coordinate space: window-local, origin at bottom-left.
    /// Window height = notchHeight + barThickness.
    /// The top horizontal segments are at y = windowHeight - (barThickness / 2).
    /// The bottom of the U is at y = barThickness / 2 (bottom of window + half stroke).
    static func buildPath(geometry: NotchGeometry, windowHeight: CGFloat) -> CGPath {
        let r = cornerRadius
        let halfStroke = barThickness / 2

        // Key Y coordinates (window-local, bottom-left origin)
        let topY = windowHeight - halfStroke          // center of top bar stroke
        let bottomY = halfStroke                       // center of bottom-of-notch stroke

        // Key X coordinates (window-local, 0 = left edge of screen)
        let leftEdge: CGFloat = halfStroke
        let rightEdge = geometry.screenWidth - halfStroke
        let notchLeft = geometry.notchLeftX
        let notchRight = geometry.notchRightX

        let path = CGMutablePath()

        // Start at left edge, at the top
        path.move(to: CGPoint(x: leftEdge, y: topY))

        // Horizontal line to notch left corner (minus radius)
        path.addLine(to: CGPoint(x: notchLeft - r, y: topY))

        // Curve down around notch left-top corner
        path.addArc(tangent1End: CGPoint(x: notchLeft, y: topY),
                     tangent2End: CGPoint(x: notchLeft, y: topY - r),
                     radius: r)

        // Down the left side of the notch
        path.addLine(to: CGPoint(x: notchLeft, y: bottomY + r))

        // Curve around notch bottom-left corner
        path.addArc(tangent1End: CGPoint(x: notchLeft, y: bottomY),
                     tangent2End: CGPoint(x: notchLeft + r, y: bottomY),
                     radius: r)

        // Across the bottom of the notch
        path.addLine(to: CGPoint(x: notchRight - r, y: bottomY))

        // Curve around notch bottom-right corner
        path.addArc(tangent1End: CGPoint(x: notchRight, y: bottomY),
                     tangent2End: CGPoint(x: notchRight, y: bottomY + r),
                     radius: r)

        // Up the right side of the notch
        path.addLine(to: CGPoint(x: notchRight, y: topY - r))

        // Curve around notch right-top corner
        path.addArc(tangent1End: CGPoint(x: notchRight, y: topY),
                     tangent2End: CGPoint(x: notchRight + r, y: topY),
                     radius: r)

        // Horizontal line to right edge
        path.addLine(to: CGPoint(x: rightEdge, y: topY))

        return path
    }
}
