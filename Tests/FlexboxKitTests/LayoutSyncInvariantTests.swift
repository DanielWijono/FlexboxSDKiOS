//
//  LayoutSyncInvariantTests.swift
//  FlexboxKitTests
//
//  The DEBUG tree-sync gate (`LayoutSyncInvariant`): at every managed
//  container, the Yoga child list and the participating-subview list must agree
//  in count and in order.
//
//  Every violation is driven by mutating the view tree behind the renderer's
//  back — which is exactly the drift the gate exists to catch — with
//  `FlexKitPrecondition.assertsAreFatal` cleared so the reject-and-continue
//  path runs instead of trapping.
//
//  DEBUG + iOS Simulator only: the gate is compiled out of release builds.
//

#if canImport(UIKit) && DEBUG
import XCTest
import UIKit
import FlexboxCore
@testable import FlexboxKit
import FlexboxKitTestSupport

@MainActor
final class LayoutSyncInvariantTests: XCTestCase {

    /// root (column, 200 x 200)
    ///  ├─ first  (container, 100 x 40)
    ///  └─ second (container, 100 x 40)
    private var twoChildTree: LayoutTree {
        LayoutTree(
            id: "root", content: .container,
            style: FlexStyle(flexDirection: .column, width: .points(200), height: .points(200)),
            children: [
                LayoutTree(id: "first", content: .container,
                           style: FlexStyle(width: .points(100), height: .points(40))),
                LayoutTree(id: "second", content: .container,
                           style: FlexStyle(width: .points(100), height: .points(40))),
            ]
        )
    }

    /// A host laid out once — clean at this point — plus the observer that
    /// records its rejections. `renderObserver` is weak, so the caller has to
    /// keep the returned observer alive for the duration of the test.
    private func mount(
        _ tree: LayoutTree
    ) -> (host: FlexHostView, observer: RecordingRenderObserver) {
        let observer = RecordingRenderObserver()
        let host = FlexHostView(tree: tree)
        host.renderObserver = observer
        host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        host.setNeedsLayout()
        host.layoutIfNeeded()
        return (host, observer)
    }

    /// Only this gate's rejections — never another operation's.
    private func syncRejections(
        _ observer: RecordingRenderObserver
    ) -> [RecordingRenderObserver.Rejection] {
        observer.rejections.filter { $0.operation == "FlexHostView.treeSync" }
    }

    /// Clears the DEBUG trap for the duration of one test, so a violation
    /// reports and continues instead of aborting the run.
    private func withAssertsReported() {
        FlexKitPrecondition.assertsAreFatal = false
        addTeardownBlock { FlexKitPrecondition.assertsAreFatal = true }
    }

    // MARK: Clean trees

    func testAFreshlyMountedTreeSatisfiesTheInvariant() {
        let (_, observer) = mount(twoChildTree)
        XCTAssertTrue(syncRejections(observer).isEmpty,
                      "a tree the renderer built itself must satisfy its own invariant")
    }

    func testAReconciledTreeStillSatisfiesTheInvariant() {
        let (host, observer) = mount(twoChildTree)

        // Remove one child, add another, reorder — all through the payload.
        host.update(to: LayoutTree(
            id: "root", content: .container,
            style: FlexStyle(flexDirection: .column, width: .points(200), height: .points(200)),
            children: [
                LayoutTree(id: "third", content: .container,
                           style: FlexStyle(width: .points(100), height: .points(40))),
                LayoutTree(id: "second", content: .container,
                           style: FlexStyle(width: .points(100), height: .points(40))),
            ]
        ))
        HostHarness.relayout(host)

        XCTAssertTrue(syncRejections(observer).isEmpty,
                      "the incremental applier must leave the two trees in agreement")
    }

    // MARK: Count

    func testASubviewAddedBehindTheRenderersBackIsReported() {
        withAssertsReported()
        let (host, observer) = mount(twoChildTree)
        guard let container = host.currentRenderTree.view(id: "first") else {
            return XCTFail("no container view")
        }

        container.addSubview(UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10)))
        HostHarness.relayout(host)

        XCTAssertEqual(syncRejections(observer).count, 1, "the stray subview should be reported once")
        XCTAssertTrue(syncRejections(observer)[0].reason.contains("carry no node"),
                      "unexpected reason: \(syncRejections(observer)[0].reason)")
    }

    func testASubviewMarkedOutOfLayoutIsNotReported() {
        withAssertsReported()
        let (host, observer) = mount(twoChildTree)
        guard let container = host.currentRenderTree.view(id: "first") else {
            return XCTFail("no container view")
        }

        let overlay = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        overlay.isIncludedInLayout = false   // the documented escape hatch
        container.addSubview(overlay)
        HostHarness.relayout(host)

        XCTAssertTrue(syncRejections(observer).isEmpty,
                      "a view the app positions itself is not part of the invariant")
    }

    func testAManagedSubviewRemovedBehindTheRenderersBackIsReported() {
        withAssertsReported()
        let (host, observer) = mount(twoChildTree)
        guard let orphan = host.currentRenderTree.view(id: "second") else {
            return XCTFail("no second view")
        }

        orphan.removeFromSuperview()   // node left behind — the Artefak 1 leak mode
        HostHarness.relayout(host)

        XCTAssertEqual(syncRejections(observer).count, 1)
        XCTAssertTrue(syncRejections(observer)[0].reason.contains("2 Yoga child(ren) but 1"),
                      "unexpected reason: \(syncRejections(observer)[0].reason)")
    }

    // MARK: Order

    func testViewOrderThatDisagreesWithNodeOrderIsReported() {
        withAssertsReported()
        let (host, observer) = mount(twoChildTree)
        let rootView = host.currentRenderTree.rootView

        // Same count, wrong order: Yoga would lay these out in one order and
        // the renderer would write the results to the other.
        rootView.exchangeSubview(at: 0, withSubviewAt: 1)
        HostHarness.relayout(host)

        // Swapping two siblings puts BOTH positions out of agreement, and the
        // gate reports each one — it names positions, not "something moved".
        XCTAssertEqual(syncRejections(observer).count, 2)
        for rejection in syncRejections(observer) {
            XCTAssertTrue(rejection.reason.contains("order"),
                          "unexpected reason: \(rejection.reason)")
        }
        XCTAssertTrue(syncRejections(observer)[0].reason.contains("subview 0"))
        XCTAssertTrue(syncRejections(observer)[1].reason.contains("subview 1"))
    }

    // MARK: Carve-outs

    func testAScrollViewsUnmanagedSubviewsAreNotReported() {
        withAssertsReported()
        let (host, observer) = mount(LayoutTree(
            id: "root", content: .container,
            style: FlexStyle(flexDirection: .column, width: .points(200), height: .points(200)),
            children: [
                LayoutTree(
                    id: "scroll", content: .container,
                    style: FlexStyle(width: .points(200), height: .points(200), overflow: .scroll),
                    children: [
                        LayoutTree(id: "content", content: .container,
                                   style: FlexStyle(width: .points(200), height: .points(400))),
                    ]
                ),
            ]
        ))
        guard let scroll = host.currentRenderTree.view(id: "scroll") as? FlexScrollBackingView else {
            return XCTFail("overflow: scroll node was not backed by a scroll view")
        }

        // Stands in for UIKit's own scroll indicators, which land in `subviews`
        // and cannot be marked `isIncludedInLayout = false`.
        scroll.addSubview(UIView(frame: CGRect(x: 0, y: 0, width: 3, height: 40)))
        HostHarness.relayout(host)

        XCTAssertTrue(syncRejections(observer).isEmpty,
                      "unmanaged subviews of a scroll view are UIKit's, not a desync")
    }

    func testALeafsOwnViewInternalsAreNotReported() {
        withAssertsReported()
        let (host, observer) = mount(LayoutTree(
            id: "root", content: .container,
            style: FlexStyle(flexDirection: .column, width: .points(200), height: .points(200)),
            children: [
                LayoutTree(id: "label", content: .text, props: ["text": .string("hi")]),
            ]
        ))
        guard let label = host.currentRenderTree.view(id: "label") else {
            return XCTFail("no leaf view")
        }

        // A composed leaf view (a consumer's custom factory) owns its subviews;
        // the renderer manages none of them.
        label.addSubview(UIView(frame: CGRect(x: 0, y: 0, width: 4, height: 4)))
        HostHarness.relayout(host)

        XCTAssertTrue(syncRejections(observer).isEmpty,
                      "a leaf's view internals belong to its factory")
    }

    // MARK: Pass coupling

    func testTheGateRunsOnGeometryPassesOnlyNotOnSelfSizePasses() {
        withAssertsReported()
        let (host, observer) = mount(twoChildTree)
        guard let container = host.currentRenderTree.view(id: "first") else {
            return XCTFail("no container view")
        }
        container.addSubview(UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10)))

        _ = host.sizeThatFits(CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertTrue(syncRejections(observer).isEmpty,
                      "a measure-only pass sees the same trees and must not double-report")

        HostHarness.relayout(host)
        XCTAssertEqual(syncRejections(observer).count, 1, "the geometry pass reports it once")
    }
}
#endif
