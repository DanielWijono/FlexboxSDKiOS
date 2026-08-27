import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

final class OpApplierTests: XCTestCase {

    override func setUp() {
        super.setUp()
        assertLiveNodeCountReturnsToBaseline()
    }

    func testUpdateRecomputesGeometry() {
        let v1 = LayoutTree(id: "root", content: .container,
                            style: FlexStyle(flexDirection: .row, width: .points(100), height: .points(10)),
                            children: [
                                LayoutTree(id: "a", content: .container, style: FlexStyle(flexGrow: 1)),
                                LayoutTree(id: "b", content: .container, style: FlexStyle(flexGrow: 1)),
                            ])
        let binding = FlexLayoutBinding(tree: v1, config: FlexConfig(pointScaleFactor: 1))
        binding.root.calculate(availableWidth: 100, availableHeight: 10)
        XCTAssertEqual(binding.node(id: "a")?.layout.width, 50)

        // v2: `a` gets grow 3, `b` grow 1  → 75 / 25
        var v2 = v1
        v2.children[0].style.flexGrow = 3
        let ops = binding.update(to: v2)
        XCTAssertEqual(ops, [.updateStyle(id: "a", delta: v2.children[0].style.delta(from: v1.children[0].style))])

        binding.root.calculate(availableWidth: 100, availableHeight: 10)
        XCTAssertEqual(binding.node(id: "a")?.layout.width, 75)
        XCTAssertEqual(binding.node(id: "b")?.layout.width, 25)
    }

    func testInsertAndRemoveKeepRegistryAndYogaInSync() {
        let v1 = LayoutTree(id: "root", content: .container, children: [
            LayoutTree(id: "a", content: .container),
        ])
        let binding = FlexLayoutBinding(tree: v1)

        var v2 = v1
        v2.children.append(LayoutTree(id: "b", content: .container, children: [
            LayoutTree(id: "b1", content: .text),
        ]))
        binding.update(to: v2)
        XCTAssertNotNil(binding.node(id: "b"))
        XCTAssertNotNil(binding.node(id: "b1"))
        XCTAssertEqual(binding.root.childCount, 2)

        binding.update(to: v1) // remove b (and b1)
        XCTAssertNil(binding.node(id: "b"))
        XCTAssertNil(binding.node(id: "b1"))
        XCTAssertEqual(binding.root.childCount, 1)
    }

    func testReorderAppliesAsMoves() {
        func row(_ ids: [String]) -> LayoutTree {
            LayoutTree(id: "root", content: .container,
                       style: FlexStyle(flexDirection: .row, width: .points(30), height: .points(10)),
                       children: ids.map {
                           LayoutTree(id: $0, content: .container, style: FlexStyle(width: .points(10)))
                       })
        }
        let binding = FlexLayoutBinding(tree: row(["a", "b", "c"]), config: FlexConfig(pointScaleFactor: 1))
        binding.update(to: row(["c", "a", "b"]))
        binding.root.calculate(availableWidth: 30, availableHeight: 10)

        XCTAssertEqual(binding.node(id: "c")?.layout.left, 0)
        XCTAssertEqual(binding.node(id: "a")?.layout.left, 10)
        XCTAssertEqual(binding.node(id: "b")?.layout.left, 20)
        XCTAssertTrue(binding.node(id: "c") === binding.root.children.first)
    }

    func testBadOpSequenceIsRejectedNotFatal() {
        FlexPrecondition.assertsAreFatal = false
        defer { FlexPrecondition.assertsAreFatal = true }

        let binding = FlexLayoutBinding(tree: LayoutTree(id: "root", content: .container))
        binding.apply([.updateStyle(id: "ghost", delta: FlexStyleDelta(changed: FlexStyle(flexGrow: 1), cleared: []))])
        binding.apply([.remove(id: "ghost")])
        binding.apply([.move(id: "ghost", parentID: "root", index: 0)])
        // Still usable.
        binding.root.calculate(availableWidth: 10, availableHeight: 10)
        XCTAssertEqual(binding.root.childCount, 0)
    }
}
