//
//  GeometryMathTests.swift
//  FlexboxKitTests
//
//  `FlexLayoutResult` → `(bounds.size, center)` conversion. Pure — runs under
//  `swift test` on macOS. The rule under test: no rounding on the Swift side.
//

import XCTest
import FlexboxCore
@testable import FlexboxKit

final class GeometryMathTests: XCTestCase {

    func testBoundsSizeIsWidthByHeight() {
        XCTAssertEqual(flexBoundsSize(width: 120, height: 44), CGSize(width: 120, height: 44))
    }

    func testCenterWithMidAnchorOffsetsByHalfExtent() {
        let center = flexCenter(left: 10, top: 20, width: 100, height: 40,
                                anchorPoint: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(center, CGPoint(x: 60, y: 40))
    }

    func testCenterWithZeroAnchorEqualsOrigin() {
        let center = flexCenter(left: 10, top: 20, width: 100, height: 40,
                                anchorPoint: CGPoint(x: 0, y: 0))
        XCTAssertEqual(center, CGPoint(x: 10, y: 20))
    }

    func testNonIntegralValuesArePassedThroughUnrounded() {
        let size = flexBoundsSize(width: 33.3333, height: 10.5)
        XCTAssertEqual(size.width, 33.3333, accuracy: 1e-9)
        XCTAssertEqual(size.height, 10.5, accuracy: 1e-9)

        let center = flexCenter(left: 5.25, top: 7.75, width: 3.5, height: 1.5,
                                anchorPoint: CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(center.x, 5.25 + 1.75, accuracy: 1e-9)
        XCTAssertEqual(center.y, 7.75 + 0.75, accuracy: 1e-9)
    }
}
