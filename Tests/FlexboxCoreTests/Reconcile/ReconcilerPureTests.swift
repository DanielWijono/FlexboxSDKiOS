import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

final class ReconcilerPureTests: XCTestCase {

    func testIdenticalTreesProduceNoOps() {
        let tree = TreeFixtures.card
        XCTAssertEqual(Reconciler.reconcile(from: tree, to: tree), [])
    }

    func testStyleChangeIsAFieldLevelDelta() {
        let old = LayoutTree(id: "r", content: .container,
                             style: FlexStyle(flexGrow: 1, padding: Edges(.points(8))))
        let new = LayoutTree(id: "r", content: .container,
                             style: FlexStyle(flexGrow: 2)) // grow changed, padding cleared

        let ops = Reconciler.reconcile(from: old, to: new)
        XCTAssertEqual(ops.count, 1)
        guard case .updateStyle(let id, let delta) = ops[0] else { return XCTFail("\(ops)") }
        XCTAssertEqual(id, "r")
        XCTAssertEqual(delta.changed.flexGrow, 2)
        XCTAssertNil(delta.changed.padding)
        XCTAssertTrue(delta.cleared.contains(.padding))
    }

    func testInsertEmitsFullSubtreeUnderExistingParent() {
        let old = LayoutTree(id: "root", content: .container, children: [
            LayoutTree(id: "a", content: .container),
        ])
        let new = LayoutTree(id: "root", content: .container, children: [
            LayoutTree(id: "a", content: .container),
            LayoutTree(id: "b", content: .container, children: [
                LayoutTree(id: "b1", content: .text),
            ]),
        ])
        let ops = Reconciler.reconcile(from: old, to: new)
        XCTAssertEqual(ops.count, 1)
        guard case .insert(let id, let parentID, let index, let subtree) = ops[0] else {
            return XCTFail("\(ops)")
        }
        XCTAssertEqual(id, "b")
        XCTAssertEqual(parentID, "root")
        XCTAssertEqual(index, 1)
        XCTAssertEqual(subtree.children.first?.id, "b1")
    }

    func testRemoveEmitsTopmostOnly() {
        let old = LayoutTree(id: "root", content: .container, children: [
            LayoutTree(id: "gone", content: .container, children: [
                LayoutTree(id: "gone-child", content: .text),
            ]),
            LayoutTree(id: "stay", content: .container),
        ])
        let new = LayoutTree(id: "root", content: .container, children: [
            LayoutTree(id: "stay", content: .container),
        ])
        let ops = Reconciler.reconcile(from: old, to: new)
        XCTAssertEqual(ops, [.remove(id: "gone")])
    }

    func testContentChangeEmitsUpdateContent() {
        let old = LayoutTree(id: "t", content: .text, props: ["text": .string("a")])
        let new = LayoutTree(id: "t", content: .text, props: ["text": .string("b")])
        XCTAssertEqual(Reconciler.reconcile(from: old, to: new), [.updateContent(id: "t")])
    }

    func testDifferentRootIDForcesReplaceRoot() {
        let ops = Reconciler.reconcile(
            from: LayoutTree(id: "old", content: .container),
            to: LayoutTree(id: "new", content: .container)
        )
        guard case .replaceRoot(let subtree) = ops.first, ops.count == 1 else { return XCTFail("\(ops)") }
        XCTAssertEqual(subtree.id, "new")
    }
}
