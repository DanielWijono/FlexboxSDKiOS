//
//  ReconcileToViewSyncTests.swift
//  FlexboxKitTests
//
//  Step 3: `host.update(to:)` drives `Reconciler` → `FlexOpApplier`, mutating the
//  `FlexNode` tree and the `UIView` tree in lockstep. Each op is checked for
//  structure, surviving-view identity, the child-count invariant, and — on
//  removal — that the `UIView` *and* its `FlexNode` are released.
//
//  iOS Simulator only.
//

#if canImport(UIKit)
import XCTest
import UIKit
import FlexboxCore
@testable import FlexboxKit
import FlexboxKitTestSupport
import FlexboxCoreTestSupport

@MainActor
final class ReconcileToViewSyncTests: XCTestCase {

    // MARK: Fixtures

    private func row(_ id: String, height: Double) -> LayoutTree {
        LayoutTree(id: id, content: .container, style: FlexStyle(height: .points(height)))
    }

    /// `list` column of three fixed-height boxes: a, b, c.
    private func listABC() -> LayoutTree {
        LayoutTree(
            id: "list", content: .container,
            style: FlexStyle(flexDirection: .column, gap: .points(4)),
            children: [row("a", height: 20), row("b", height: 20), row("c", height: 20)]
        )
    }

    private func managedIDs(_ host: FlexHostView) -> [String] {
        HostHarness.managedSubviews(under: host.currentRenderTree.rootView)
            .compactMap { $0.flexNode }
            .compactMap { host.currentRenderTree.idForNode($0) }
    }

    private func mount(_ tree: LayoutTree, _ observer: RecordingRenderObserver)
        -> (UIWindow, FlexHostView)
    {
        let host = FlexHostView(tree: tree)
        host.renderObserver = observer
        return HostHarness.finishMount(host: host, size: CGSize(width: 200, height: 400))
    }

    // MARK: Insert

    func testInsertAddsOneViewAndNodeInOrder() {
        let observer = RecordingRenderObserver()
        let (window, host) = mount(listABC(), observer)
        defer { window.resignKey() }

        var next = listABC()
        next.children.insert(row("d", height: 20), at: 2)   // a, b, [d], c
        host.update(to: next)
        HostHarness.relayout(host)

        XCTAssertEqual(managedIDs(host), ["a", "b", "d", "c"])
        XCTAssertEqual(host.currentRenderTree.node(id: "list")?.childCount, 4)
        XCTAssertNotNil(host.currentRenderTree.view(id: "d"))
        XCTAssertTrue(HostHarness.childCountInvariantHolds(from: host))
        XCTAssertFalse(observer.didReject, "unexpected: \(observer.rejections)")
    }

    // MARK: Remove

    func testRemoveReleasesBothTheViewAndItsNode() throws {
        assertLiveNodeCountReturnsToBaseline()
        let observer = RecordingRenderObserver()
        let (window, host) = mount(listABC(), observer)
        defer { window.resignKey() }

        // Deallocation of a UIView goes through an autorelease pool that only
        // drains after this method returns, so check it at teardown, not inline.
        assertDeallocated(try XCTUnwrap(host.currentRenderTree.node(id: "b")), "b node")
        assertDeallocated(try XCTUnwrap(host.currentRenderTree.view(id: "b")), "b view")

        var next = listABC()
        next.children.remove(at: 1)   // a, c
        host.update(to: next)
        HostHarness.relayout(host)

        XCTAssertEqual(managedIDs(host), ["a", "c"])
        XCTAssertEqual(host.currentRenderTree.node(id: "list")?.childCount, 2)
        XCTAssertNil(host.currentRenderTree.item(id: "b"), "index entry dropped")
        XCTAssertNil(host.currentRenderTree.node(id: "b"), "node lookup still resolves 'b'")
        XCTAssertTrue(HostHarness.childCountInvariantHolds(from: host))
        XCTAssertFalse(observer.didReject, "unexpected: \(observer.rejections)")
    }

    // MARK: Move

    func testReorderMovesViewsWithoutRebuilding() {
        let observer = RecordingRenderObserver()
        let (window, host) = mount(listABC(), observer)
        defer { window.resignKey() }

        let aBefore = ObjectIdentifier(host.currentRenderTree.view(id: "a")!)
        let cBefore = ObjectIdentifier(host.currentRenderTree.view(id: "c")!)

        var next = listABC()
        next.children = [next.children[2], next.children[0], next.children[1]]   // c, a, b
        host.update(to: next)
        HostHarness.relayout(host)

        XCTAssertEqual(managedIDs(host), ["c", "a", "b"])
        XCTAssertEqual(ObjectIdentifier(host.currentRenderTree.view(id: "a")!), aBefore,
                       "view for 'a' was rebuilt instead of moved")
        XCTAssertEqual(ObjectIdentifier(host.currentRenderTree.view(id: "c")!), cBefore,
                       "view for 'c' was rebuilt instead of moved")
        // z-order follows child order
        let subviews = host.currentRenderTree.rootView.subviews
        XCTAssertLessThan(subviews.firstIndex(of: host.currentRenderTree.view(id: "c")!)!,
                          subviews.firstIndex(of: host.currentRenderTree.view(id: "a")!)!)
        XCTAssertTrue(HostHarness.childCountInvariantHolds(from: host))
        XCTAssertFalse(observer.didReject, "unexpected: \(observer.rejections)")
    }

    // MARK: Style

    func testUpdateStyleReappliesToTheSameNodeAndView() {
        let observer = RecordingRenderObserver()
        let (window, host) = mount(listABC(), observer)
        defer { window.resignKey() }

        let aViewBefore = ObjectIdentifier(host.currentRenderTree.view(id: "a")!)
        XCTAssertEqual(host.currentRenderTree.view(id: "a")?.bounds.height, 20)

        var next = listABC()
        next.children[0].style.height = .points(50)
        host.update(to: next)
        HostHarness.relayout(host)

        XCTAssertEqual(host.currentRenderTree.view(id: "a")?.bounds.height, 50)
        XCTAssertEqual(ObjectIdentifier(host.currentRenderTree.view(id: "a")!), aViewBefore)
        XCTAssertTrue(HostHarness.childCountInvariantHolds(from: host))
        XCTAssertFalse(observer.didReject, "unexpected: \(observer.rejections)")
    }

    // MARK: Content

    func testUpdateContentRefreshesPropsAndRemeasuresLeaf() {
        let observer = RecordingRenderObserver()
        let tree = LayoutTree(
            id: "list", content: .container,
            style: FlexStyle(flexDirection: .column, gap: .points(4)),
            children: [
                LayoutTree(id: "label", content: .text,
                           props: ["text": .string("one")]),
                row("spacer", height: 10),
            ]
        )
        let (window, host) = mount(tree, observer)
        defer { window.resignKey() }

        let labelBefore = ObjectIdentifier(host.currentRenderTree.view(id: "label")!)
        let heightBefore = host.currentRenderTree.view(id: "label")!.bounds.height

        var next = tree
        next.children[0].props = ["text": .string("line one\nline two\nline three")]
        host.update(to: next)
        HostHarness.relayout(host)

        let label = host.currentRenderTree.view(id: "label") as? UILabel
        XCTAssertEqual(label?.text, "line one\nline two\nline three")
        XCTAssertEqual(ObjectIdentifier(host.currentRenderTree.view(id: "label")!), labelBefore,
                       "label was rebuilt instead of updated in place")
        XCTAssertGreaterThan(host.currentRenderTree.view(id: "label")!.bounds.height, heightBefore,
                             "leaf did not re-measure after its text grew")
        XCTAssertFalse(observer.didReject, "unexpected: \(observer.rejections)")
    }

    // MARK: replaceRoot

    func testRootIdChangeRebuildsFromScratch() {
        assertLiveNodeCountReturnsToBaseline()
        let observer = RecordingRenderObserver()
        let (window, host) = mount(listABC(), observer)
        defer { window.resignKey() }

        weak var oldListNode = host.currentRenderTree.node(id: "list")
        let oldRootView = host.currentRenderTree.rootView

        let replacement = LayoutTree(
            id: "grid", content: .container,
            style: FlexStyle(flexDirection: .row, gap: .points(4)),
            children: [row("x", height: 30), row("y", height: 30)]
        )
        host.update(to: replacement)
        HostHarness.relayout(host)

        XCTAssertEqual(host.tree.id, "grid")
        XCTAssertNil(host.currentRenderTree.item(id: "list"), "old index cleared")
        XCTAssertNil(oldListNode, "old root subtree leaked")
        XCTAssertFalse(oldRootView.isDescendant(of: host), "old root view still attached")
        XCTAssertEqual(managedIDs(host), ["x", "y"])
        XCTAssertTrue(HostHarness.childCountInvariantHolds(from: host))
        XCTAssertFalse(observer.didReject, "unexpected: \(observer.rejections)")
    }

    // MARK: Compound

    func testOneUpdateAppliesRemoveInsertMoveAndStyleTogether() {
        let observer = RecordingRenderObserver()
        let (window, host) = mount(listABC(), observer)
        defer { window.resignKey() }

        // a, b, c  →  b, a(h=40), d, e   (c removed, b moved ahead of a, d & e new)
        var next = listABC()
        next.children[0].style.height = .points(40)   // a
        next.children = [
            next.children[1],                          // b
            next.children[0],                          // a
            row("d", height: 20),
            row("e", height: 20),
        ]
        host.update(to: next)
        HostHarness.relayout(host)

        XCTAssertEqual(managedIDs(host), ["b", "a", "d", "e"])
        XCTAssertNil(host.currentRenderTree.item(id: "c"))
        XCTAssertEqual(host.currentRenderTree.view(id: "a")?.bounds.height, 40)
        XCTAssertEqual(host.currentRenderTree.node(id: "list")?.childCount, 4)
        XCTAssertTrue(HostHarness.childCountInvariantHolds(from: host))
        XCTAssertFalse(observer.didReject, "unexpected: \(observer.rejections)")
    }

    // MARK: Content invalidation (step 4)

    func testTextChangeDirtiesTheLeafButColorChangeDoesNot() throws {
        let observer = RecordingRenderObserver()
        let tree = LayoutTree(
            id: "list", content: .container,
            style: FlexStyle(flexDirection: .column, gap: .points(4)),
            children: [
                LayoutTree(id: "label", content: .text,
                           props: ["text": .string("short"),
                                   "textColor": .string("#000000")]),
            ]
        )
        let (window, host) = mount(tree, observer)
        defer { window.resignKey() }

        let labelNode = try XCTUnwrap(host.currentRenderTree.node(id: "label"))
        XCTAssertFalse(labelNode.isDirty, "clean after the initial pass")
        let heightBefore = try XCTUnwrap(host.currentRenderTree.view(id: "label")).bounds.height

        // 1. size-affecting change → leaf marked content-dirty, height grows
        var withLongText = tree
        withLongText.children[0].props = [
            "text": .string("line one\nline two\nline three\nline four"),
            "textColor": .string("#000000"),
        ]
        host.update(to: withLongText)
        XCTAssertTrue(labelNode.isDirty, "text change should mark the leaf content-dirty")
        HostHarness.relayout(host)
        XCTAssertGreaterThan(
            try XCTUnwrap(host.currentRenderTree.view(id: "label")).bounds.height, heightBefore
        )
        XCTAssertFalse(labelNode.isDirty, "clean again after relayout")

        // 2. colour-only change → view refreshes, layout is NOT dirtied
        let colorBefore = (host.currentRenderTree.view(id: "label") as? UILabel)?.textColor
        var withNewColor = withLongText
        withNewColor.children[0].props = [
            "text": .string("line one\nline two\nline three\nline four"),
            "textColor": .string("#ff0000"),
        ]
        host.update(to: withNewColor)
        XCTAssertFalse(labelNode.isDirty, "colour-only change must not dirty layout")
        HostHarness.relayout(host)
        let colorAfter = (host.currentRenderTree.view(id: "label") as? UILabel)?.textColor
        XCTAssertNotEqual(colorBefore, colorAfter, "the view should still refresh on a colour change")
        XCTAssertFalse(observer.didReject, "unexpected: \(observer.rejections)")
    }

    // MARK: Convergence

    func testIncrementalUpdateRendersIdenticallyToAFreshBuild() {
        let start = listABC()
        var target = listABC()
        target.children[0].style.height = .points(40)
        target.children = [target.children[2], target.children[0], target.children[1]]
        target.children.append(row("d", height: 16))

        let incremental = FlexHostView(tree: start)
        incremental.update(to: target)

        let fresh = FlexHostView(tree: target)

        FlexSnapshot.assertSameRender(incremental, fresh, size: CGSize(width: 200, height: 200))
    }
}
#endif
