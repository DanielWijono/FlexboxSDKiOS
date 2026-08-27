//
//  FlexHostViewRenderTests.swift
//  FlexboxKitTests
//
//  Static render: a multi-level tree becomes a `UIView` hierarchy with correct
//  frames, the child-count invariant holds, and nothing is rejected. iOS
//  Simulator only.
//

#if canImport(UIKit)
import XCTest
import UIKit
import FlexboxCore
@testable import FlexboxKit
import FlexboxKitTestSupport
import FlexboxCoreTestSupport

@MainActor
final class FlexHostViewRenderTests: XCTestCase {

    func testCardRendersToAViewHierarchyWithCorrectStructure() {
        let observer = RecordingRenderObserver()
        let host = FlexHostView(tree: TreeFixtures.card)
        host.renderObserver = observer
        let (window, _) = HostHarness.finishMount(host: host, size: CGSize(width: 320, height: 568))
        defer { window.resignKey() }

        XCTAssertEqual(
            host.currentRenderTree.rootView.frame,
            CGRect(x: 0, y: 0, width: 320, height: 568)
        )

        // header / avatar / title / chevron / body  →  5 managed descendants
        // of the root ("card") view.
        let managed = HostHarness.managedSubviews(under: host.currentRenderTree.rootView)
        XCTAssertEqual(managed.count, 5)

        XCTAssertTrue(HostHarness.childCountInvariantHolds(from: host))
        XCTAssertFalse(observer.didReject, "unexpected rejections: \(observer.rejections)")
        XCTAssertFalse(observer.layoutPasses.isEmpty, "a layout pass should have been reported")
    }

    func testCardFramesMatchYogaOutput() {
        let host = FlexHostView(tree: TreeFixtures.card)
        let (window, _) = HostHarness.finishMount(host: host, size: CGSize(width: 320, height: 568))
        defer { window.resignKey() }

        let tree = host.currentRenderTree
        guard
            let header = tree.view(id: "header"),
            let avatar = tree.view(id: "avatar"),
            let title = tree.view(id: "title"),
            let chevron = tree.view(id: "chevron"),
            let body = tree.view(id: "body")
        else { return XCTFail("missing managed views") }

        // card: column, padding 16, gap 8, width 320
        XCTAssertEqual(header.frame.minX, 16)
        XCTAssertEqual(header.frame.minY, 16)
        XCTAssertEqual(header.frame.width, 288)          // 320 - 2*16

        // header: row, alignItems center, gap 12; avatar 40, chevron 12, title grows
        XCTAssertEqual(avatar.bounds.size, CGSize(width: 40, height: 40))
        XCTAssertEqual(chevron.bounds.size, CGSize(width: 12, height: 12))
        XCTAssertEqual(avatar.frame.minX, 0)
        XCTAssertEqual(title.frame.minX, 52)            // 40 + gap 12
        XCTAssertEqual(chevron.frame.maxX, 288, accuracy: 0.5)
        XCTAssertGreaterThan(title.frame.width, 0, "title should have measured its text")

        // center alignment of the shorter items in the row
        XCTAssertEqual(avatar.frame.minY, 0)
        XCTAssertEqual(chevron.frame.midY, header.frame.height / 2, accuracy: 0.5)

        // body sits below the header plus the 8pt column gap
        XCTAssertEqual(body.frame.minX, 16)
        XCTAssertEqual(body.frame.minY, header.frame.maxY + 8, accuracy: 0.5)
    }

    func testUnknownContentTypeFallsBackToContainerAndReports() {
        FlexKitPrecondition.assertsAreFatal = false
        defer { FlexKitPrecondition.assertsAreFatal = true }

        let tree = LayoutTree(
            id: "root", content: .container,
            children: [LayoutTree(id: "widget", content: .custom("no-such-factory"),
                                  style: FlexStyle(width: .points(10), height: .points(10)))]
        )
        let observer = RecordingRenderObserver()
        let host = FlexHostView(tree: tree)
        host.renderObserver = observer
        host.update(to: tree)   // rebuild now that the observer is attached
        let (window, _) = HostHarness.finishMount(host: host)
        defer { window.resignKey() }

        XCTAssertTrue(observer.rejections.contains { $0.operation == "FlexViewRegistry.resolve" })
        XCTAssertNotNil(host.currentRenderTree.view(id: "widget"), "a placeholder view is still created")
    }

    func testAutoLayoutContractHoldsForManagedSubviews() {
        let host = FlexHostView(tree: TreeFixtures.card)
        let (window, _) = HostHarness.finishMount(host: host)
        defer { window.resignKey() }

        XCTAssertEqual(host.flexAutoLayoutContractViolations(), [])
    }
}
#endif
