import XCTest
@testable import BrimLib

final class NotchGeometryTests: XCTestCase {

    func testMockGeometryComputedProperties() {
        let geo = NotchGeometry.mock(
            notchLeftX: 510,
            notchRightX: 702,
            notchHeight: 32,
            screenWidth: 1512
        )

        XCTAssertEqual(geo.notchWidth, 192)
        XCTAssertEqual(geo.leftSegmentWidth, 510)
        XCTAssertEqual(geo.rightSegmentWidth, 810)
        XCTAssertEqual(geo.notchHeight, 32)
    }

    func testDetectReturnsNilForNonNotchScreen() {
        let result = NotchGeometry.detect()
        if let geo = result {
            XCTAssertGreaterThan(geo.notchWidth, 0)
            XCTAssertGreaterThan(geo.notchHeight, 0)
        }
    }
}
