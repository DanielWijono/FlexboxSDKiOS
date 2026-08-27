import XCTest
@testable import FlexboxCore

final class ReorderByIdTests: XCTestCase {

    private func row(_ ids: [String]) -> LayoutTree {
        LayoutTree(id: "root", content: .container,
                   children: ids.map { LayoutTree(id: $0, content: .container) })
    }

    func testReorderProducesMovesNotRemoveInsert() {
        let ops = Reconciler.reconcile(from: row(["a", "b", "c"]), to: row(["c", "a", "b"]))
        XCTAssertFalse(ops.contains { if case .remove = $0 { return true } else { return false } })
        XCTAssertFalse(ops.contains { if case .insert = $0 { return true } else { return false } })
        XCTAssertTrue(ops.allSatisfy { if case .move = $0 { return true } else { return false } })
        XCTAssertTrue(ops.contains(.move(id: "c", parentID: "root", index: 0)))
    }

    func testMixedInsertRemoveReorder() {
        let ops = Reconciler.reconcile(from: row(["a", "b", "c"]), to: row(["c", "d", "a"]))
        XCTAssertTrue(ops.contains(.remove(id: "b")))
        XCTAssertTrue(ops.contains { if case .insert(let id, _, _, _) = $0 { return id == "d" } else { return false } })
        XCTAssertTrue(ops.contains { if case .move(let id, _, _) = $0 { return id == "c" || id == "a" } else { return false } })
    }

    func testNoChangeWhenOrderStable() {
        XCTAssertEqual(Reconciler.reconcile(from: row(["a", "b"]), to: row(["a", "b"])), [])
    }
}
