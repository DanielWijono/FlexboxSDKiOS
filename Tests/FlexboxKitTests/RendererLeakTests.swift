//
//  RendererLeakTests.swift
//  FlexboxKitTests
//
//  The renderer's half of the permanent leak gates (spec Artefak 3 §"Selesai
//  bila … lolos seluruh gerbang kebocoran"). `OwnershipLeakTests` covers the
//  engine; these cover the extra edges FlexboxKit adds on top of it:
//
//    • UIView → FlexNode is strong (associated object), FlexNode → UIView is
//      weak (`RenderItem.view`, `MeasureContext.view`), so a mounted tree
//      deallocates completely when the host goes away
//    • a node that outlives its host must not retain the host — the engine's
//      `onDirtied` closure reaches it through `WeakHostRelay`
//    • a reconcile removal is total: the removed subtree's views AND nodes go
//      (skipping the node side is the Artefak 1 leak mode)
//    • a full rebuild releases the previous tree rather than stacking one
//
//  No `UIWindow` here on purpose — see `HostHarness.layOutOffWindow`.
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
final class RendererLeakTests: XCTestCase {

    /// root (column)
    ///  ├─ child     (container, 100 x 40)
    ///  │    └─ grandchild (text)
    ///  └─ sibling   (container, 100 x 40)
    private func tree(childContent: ContentType = .container) -> LayoutTree {
        LayoutTree(
            id: "root", content: .container,
            style: FlexStyle(flexDirection: .column, width: .points(200), height: .points(200)),
            children: [
                LayoutTree(
                    id: "child", content: childContent,
                    style: FlexStyle(width: .points(100), height: .points(40)),
                    children: childContent.isLeaf ? [] : [
                        LayoutTree(id: "grandchild", content: .text,
                                   props: ["text": .string("hello")]),
                    ],
                    props: childContent.isLeaf ? ["text": .string("leaf")] : nil
                ),
                LayoutTree(
                    id: "sibling", content: .container,
                    style: FlexStyle(width: .points(100), height: .points(40))
                ),
            ]
        )
    }

    // MARK: Whole-tree teardown

    func testMountedTreeFullyDeallocatesWhenTheHostGoesAway() {
        assertLiveNodeCountReturnsToBaseline()

        weak var weakHost: FlexHostView?
        weak var weakRootView: UIView?
        weak var weakChildView: UIView?
        weak var weakRootNode: FlexNode?
        weak var weakGrandchildNode: FlexNode?

        autoreleasepool {
            let host = HostHarness.layOutOffWindow(tree())
            weakHost = host
            weakRootView = host.currentRenderTree.rootView
            weakChildView = host.currentRenderTree.view(id: "child")
            weakRootNode = host.currentRenderTree.root
            weakGrandchildNode = host.currentRenderTree.node(id: "grandchild")

            XCTAssertNotNil(weakChildView, "the child view should exist while mounted")
            XCTAssertNotNil(weakGrandchildNode, "the grandchild node should exist while mounted")
        }

        XCTAssertNil(weakHost, "host leaked")
        XCTAssertNil(weakRootView, "root view leaked")
        XCTAssertNil(weakChildView, "child view leaked")
        XCTAssertNil(weakRootNode, "root node leaked")
        XCTAssertNil(weakGrandchildNode, "grandchild node leaked")
    }

    func testNodeThatOutlivesItsHostDoesNotRetainIt() {
        assertLiveNodeCountReturnsToBaseline()

        weak var weakHost: FlexHostView?
        var survivingNode: FlexNode?

        autoreleasepool {
            let host = HostHarness.layOutOffWindow(tree())
            weakHost = host
            // A strong reference to a node in the middle of the tree. It keeps
            // its own subtree alive; it must not keep the host alive — the
            // engine reaches the host only through `WeakHostRelay`.
            survivingNode = host.currentRenderTree.node(id: "child")
            XCTAssertNotNil(survivingNode)
        }

        XCTAssertNil(weakHost, "a surviving node retained its host — onDirtied relay cycle")
        XCTAssertNotNil(survivingNode, "the explicitly retained node should still be alive")
        XCTAssertNil(survivingNode?.parent, "its parent went with the host")

        autoreleasepool { survivingNode = nil }
    }

    // MARK: Incremental removal

    func testReconcileRemovalReleasesTheRemovedSubtreesViewsAndNodes() {
        assertLiveNodeCountReturnsToBaseline()

        weak var weakRemovedView: UIView?
        weak var weakRemovedNode: FlexNode?
        weak var weakRemovedLeafNode: FlexNode?

        autoreleasepool {
            let host = HostHarness.layOutOffWindow(tree())
            weakRemovedView = host.currentRenderTree.view(id: "child")
            weakRemovedNode = host.currentRenderTree.node(id: "child")
            weakRemovedLeafNode = host.currentRenderTree.node(id: "grandchild")
            XCTAssertNotNil(weakRemovedView)

            autoreleasepool {
                // Same root id, same content kinds → the incremental path.
                host.update(to: LayoutTree(
                    id: "root", content: .container,
                    style: FlexStyle(
                        flexDirection: .column, width: .points(200), height: .points(200)
                    ),
                    children: [
                        LayoutTree(
                            id: "sibling", content: .container,
                            style: FlexStyle(width: .points(100), height: .points(40))
                        ),
                    ]
                ))
                HostHarness.relayout(host)
            }

            XCTAssertNil(weakRemovedView, "removed subtree's view leaked")
            XCTAssertNil(weakRemovedNode, "removed subtree's node leaked")
            XCTAssertNil(weakRemovedLeafNode, "removed subtree's leaf node leaked")

            // The surviving tree is still consistent after the removal.
            XCTAssertEqual(host.currentRenderTree.root.childCount, 1)
            XCTAssertNil(host.currentRenderTree.node(id: "child"),
                         "a removed id must leave the render index")
            XCTAssertTrue(
                HostHarness.childCountInvariantHolds(from: host.currentRenderTree.rootView)
            )
        }
    }

    // MARK: Full rebuild

    func testFullRebuildReleasesThePreviousTree() {
        assertLiveNodeCountReturnsToBaseline()

        weak var weakOldRootView: UIView?
        weak var weakOldChildView: UIView?
        weak var weakOldRootNode: FlexNode?

        autoreleasepool {
            let host = HostHarness.layOutOffWindow(tree())
            weakOldRootView = host.currentRenderTree.rootView
            weakOldChildView = host.currentRenderTree.view(id: "child")
            weakOldRootNode = host.currentRenderTree.root

            autoreleasepool {
                // `child` changes content kind container → text, which needs a
                // different UIView class: `update(to:)` routes this to a full
                // rebuild rather than a diff.
                host.update(to: tree(childContent: .text))
                HostHarness.relayout(host)
            }

            XCTAssertNotNil(host.currentRenderTree.view(id: "child"),
                            "the rebuilt tree has its own child view")
            XCTAssertNil(weakOldRootView, "previous root view leaked across the rebuild")
            XCTAssertNil(weakOldChildView, "previous child view leaked across the rebuild")
            XCTAssertNil(weakOldRootNode, "previous root node leaked across the rebuild")
            XCTAssertEqual(host.subviews.count, 1, "exactly one render tree is mounted")
        }
    }

    func testRepeatedMountAndTeardownCyclesDoNotAccumulate() {
        assertLiveNodeCountReturnsToBaseline()

        weak var weakLastHost: FlexHostView?
        for _ in 0..<20 {
            autoreleasepool {
                let host = HostHarness.layOutOffWindow(tree())
                HostHarness.relayout(host)
                weakLastHost = host
            }
            XCTAssertNil(weakLastHost, "a host from an earlier cycle is still alive")
        }
    }
}
#endif
