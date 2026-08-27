import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

final class OwnershipLeakTests: XCTestCase {

    func testTreeFullyDeallocatesAfterScope() {
        #if DEBUG
        let baseline = LiveNodeCounter.current
        #endif

        weak var weakRoot: FlexNode?
        weak var weakLeaf: FlexNode?

        autoreleasepool {
            let config = FlexConfig(pointScaleFactor: 1)
            let root = FlexNode(config: config)
            let mid = FlexNode(config: config)
            let leaf = FlexNode(config: config)
            root.appendChild(mid)
            mid.appendChild(leaf)
            root.calculate(availableWidth: 100, availableHeight: 100)

            weakRoot = root
            weakLeaf = leaf
            XCTAssertNotNil(weakRoot)
            XCTAssertNotNil(weakLeaf)
        }

        XCTAssertNil(weakRoot, "root leaked")
        XCTAssertNil(weakLeaf, "leaf leaked")
        #if DEBUG
        XCTAssertEqual(LiveNodeCounter.current, baseline, "live node count did not return to baseline")
        #endif
    }

    func testDetachedSubtreeStaysAliveThenReleases() {
        #if DEBUG
        let baseline = LiveNodeCounter.current
        #endif
        weak var weakChild: FlexNode?

        autoreleasepool {
            let root = FlexNode()
            let child = FlexNode()
            root.appendChild(child)
            weakChild = child

            root.removeChild(child)
            XCTAssertNil(child.parent)
            // `child` is still held by this local var → alive.
            XCTAssertNotNil(weakChild)
        }

        XCTAssertNil(weakChild)
        #if DEBUG
        XCTAssertEqual(LiveNodeCounter.current, baseline)
        #endif
    }

    func testParentHoldsChildStrongly() {
        weak var weakChild: FlexNode?
        let root = FlexNode()
        autoreleasepool {
            let child = FlexNode()
            root.appendChild(child)
            weakChild = child
        }
        // Local `child` gone, but the parent's strong reference keeps it alive.
        XCTAssertNotNil(weakChild)
        root.removeChild(root.children[0])
        XCTAssertNil(weakChild)
    }
}
