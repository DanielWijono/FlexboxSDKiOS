import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

final class ReparentingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        assertLiveNodeCountReturnsToBaseline()
    }

    func testSubtreeMovesBetweenParentsAndGeometryRecomputes() {
        let config = FlexConfig(pointScaleFactor: 1)
        let root = FlexNode(config: config)
        root.apply(FlexStyle(flexDirection: .row, width: .points(300), height: .points(100)))

        let left = FlexNode(config: config); left.apply(FlexStyle(flexGrow: 1))
        let right = FlexNode(config: config); right.apply(FlexStyle(flexGrow: 1))
        root.appendChild(left)
        root.appendChild(right)

        let movable = FlexNode(config: config)
        movable.apply(FlexStyle(width: .points(20), height: .points(20)))
        left.appendChild(movable)

        root.calculate(availableWidth: 300, availableHeight: 100)
        // Yoga layout is parent-relative; walk to root for an absolute x.
        func absoluteLeft(_ node: FlexNode) -> Double {
            var x = 0.0
            var current: FlexNode? = node
            while let n = current {
                x += n.layout.left
                current = n.parent
            }
            return x
        }
        XCTAssertEqual(absoluteLeft(movable), 0, "under left column (x = 0)")
        XCTAssertTrue(movable.parent === left)

        // Reparent: remove from `left` (YGNodeRemoveChild first), insert into `right`.
        movable.removeFromParent()
        XCTAssertNil(movable.parent)
        XCTAssertEqual(left.childCount, 0)
        right.appendChild(movable)
        XCTAssertTrue(movable.parent === right)

        root.calculate(availableWidth: 300, availableHeight: 100)
        // `movable` now lays out inside `right`: its absolute x equals `right`'s
        // origin, and `right` starts to the right of `left`.
        XCTAssertGreaterThan(right.layout.left, 0)
        XCTAssertEqual(absoluteLeft(movable), right.layout.left, "movable is positioned under right")
        XCTAssertEqual(movable.layout.left, 0, "at the leading edge of right")

        // Yoga and Swift child counts agree everywhere.
        XCTAssertEqual(left.childCount, 0)
        XCTAssertEqual(right.childCount, 1)
    }

    func testReinsertingWithoutRemovingIsRejected() {
        FlexPrecondition.assertsAreFatal = false
        defer { FlexPrecondition.assertsAreFatal = true }

        let root = FlexNode()
        let other = FlexNode()
        let child = FlexNode()
        root.appendChild(child)

        other.appendChild(child) // child already has a parent → rejected no-op
        XCTAssertTrue(child.parent === root)
        XCTAssertEqual(other.childCount, 0)
        XCTAssertEqual(root.childCount, 1)
    }
}
