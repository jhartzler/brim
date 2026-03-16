import XCTest
@testable import BrimLib

final class NotchBarPathBuilderTests: XCTestCase {

    func testPathStartsAtLeftEdge() {
        let geo = NotchGeometry.mock(
            notchLeftX: 510,
            notchRightX: 702,
            notchHeight: 32,
            screenWidth: 1512
        )
        let windowHeight = geo.notchHeight + NotchBarPathBuilder.barThickness
        let path = NotchBarPathBuilder.buildPath(geometry: geo, windowHeight: windowHeight)

        XCTAssertFalse(path.isEmpty)

        let bounds = path.boundingBox
        XCTAssertLessThan(bounds.minX, 10, "Path should start near left edge")
        XCTAssertGreaterThan(bounds.maxX, 1500, "Path should end near right edge")
    }

    func testPathDescendsBelowTopForNotch() {
        let geo = NotchGeometry.mock(
            notchLeftX: 510,
            notchRightX: 702,
            notchHeight: 32,
            screenWidth: 1512
        )
        let windowHeight = geo.notchHeight + NotchBarPathBuilder.barThickness
        let path = NotchBarPathBuilder.buildPath(geometry: geo, windowHeight: windowHeight)
        let bounds = path.boundingBox

        XCTAssertLessThan(bounds.minY, windowHeight / 2,
                          "Path should dip below midpoint for the notch wrap")
    }
}
