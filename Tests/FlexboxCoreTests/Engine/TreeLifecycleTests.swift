import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

final class TreeLifecycleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        assertLiveNodeCountReturnsToBaseline()
    }

    func testThreeLevelTreeBuildsAndCalculates() {
        let config = FlexConfig(pointScaleFactor: 1)
        let root = FlexNode(config: config)
        root.apply(FlexStyle(flexDirection: .column, width: .points(200), height: .points(120)))

        let rowA = FlexNode(config: config)
        rowA.apply(FlexStyle(flexDirection: .row, flexGrow: 1))
        let rowB = FlexNode(config: config)
        rowB.apply(FlexStyle(flexDirection: .row, flexGrow: 1))
        root.appendChild(rowA)
        root.appendChild(rowB)

        let a1 = FlexNode(config: config); a1.apply(FlexStyle(flexGrow: 1))
        let a2 = FlexNode(config: config); a2.apply(FlexStyle(flexGrow: 1))
        rowA.appendChild(a1)
        rowA.appendChild(a2)

        XCTAssertEqual(root.nodeCount, 5)

        root.calculate(availableWidth: 200, availableHeight: 120)

        XCTAssertEqual(root.layout.width, 200)
        XCTAssertEqual(root.layout.height, 120)
        XCTAssertEqual(rowA.layout.height, 60)
        XCTAssertEqual(rowB.layout.top, 60)
        // row A split evenly across 200pt
        XCTAssertEqual(a1.layout.width, 100)
        XCTAssertEqual(a2.layout.width, 100)
        XCTAssertEqual(a2.layout.left, 100)
    }

    func testEvenSplitRowFixture() {
        let binding = FlexLayoutBinding(tree: TreeFixtures.evenSplitRow, config: FlexConfig(pointScaleFactor: 1))
        binding.root.calculate(availableWidth: 100, availableHeight: 20)

        XCTAssertEqual(binding.node(id: "left")?.layout.width, 50)
        XCTAssertEqual(binding.node(id: "right")?.layout.width, 50)
        XCTAssertEqual(binding.node(id: "right")?.layout.left, 50)
    }

    func testChildInvariantHoldsAfterMutations() {
        let root = FlexNode()
        let a = FlexNode()
        let b = FlexNode()
        root.appendChild(a)
        root.appendChild(b)
        XCTAssertEqual(root.childCount, 2)
        root.removeChild(a)
        XCTAssertEqual(root.childCount, 1)
        root.calculate(availableWidth: 50, availableHeight: 50)
        // assertChildInvariant() runs inside calculate/insert/remove in DEBUG.
    }
}
