//
//  SelfSizingTests.swift
//  FlexboxKitTests
//
//  Step 5: the self-size entry points. `sizeThatFits` / `intrinsicContentSize` /
//  `systemLayoutSizeFitting` run their own measure-only Yoga pass, independent of
//  `layoutSubviews`, honour per-axis constraints (a real bound clamps AtMost; an
//  infinite / zero offer yields the natural extent), and terminate when queried
//  re-entrantly.
//
//  iOS Simulator only.
//

#if canImport(UIKit)
import XCTest
import UIKit
import FlexboxCore
@testable import FlexboxKit
import FlexboxKitTestSupport

@MainActor
final class SelfSizingTests: XCTestCase {

    // MARK: Fixtures

    /// A column: padding 16, gap 10, two definite boxes (100×40, 120×60).
    /// Natural width = 120 + 32 = 152. Natural height = 16+40+10+60+16 = 142.
    private var fixedColumn: LayoutTree {
        LayoutTree(
            id: "col", content: .container,
            style: FlexStyle(flexDirection: .column, padding: Edges(.points(16)), gap: .points(10)),
            children: [
                LayoutTree(id: "a", content: .container,
                           style: FlexStyle(width: .points(100), height: .points(40))),
                LayoutTree(id: "b", content: .container,
                           style: FlexStyle(width: .points(120), height: .points(60))),
            ]
        )
    }

    /// A padded column around one wrapping paragraph — height depends on width.
    private var paragraph: LayoutTree {
        LayoutTree(
            id: "wrap", content: .container,
            style: FlexStyle(flexDirection: .column, padding: Edges(.points(8))),
            children: [
                LayoutTree(id: "p", content: .text,
                           props: ["text": .string(
                               "A reasonably long line of text that will wrap onto more "
                                   + "rows as the available width shrinks.")]),
            ]
        )
    }

    // MARK: sizeThatFits

    func testSizeThatFitsHeightIsTheContentHeightNotTheOfferedInfinity() {
        let host = FlexHostView(tree: fixedColumn)
        let fitted = host.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertEqual(fitted.height, 142, accuracy: 0.5,
                       "the free axis returns the natural extent, not the infinity it was offered")
        XCTAssertEqual(fitted.width, 320, accuracy: 0.5, "a finite width offer is honoured in full")
    }

    func testSizeThatFitsNeverReportsMoreThanARealBound() {
        // The one fixed child is 120 wide; offer less than that and the answer is
        // still clamped down to what was offered (AtMost), never the overflow.
        let host = FlexHostView(tree: fixedColumn)
        let fitted = host.sizeThatFits(CGSize(width: 80, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertLessThanOrEqual(fitted.width, 80.5)
        XCTAssertEqual(fitted.height, 142, accuracy: 0.5, "fixed heights are unaffected by the width clamp")
    }

    func testSizeThatFitsWithNoConstraintReturnsTheNaturalSize() {
        let host = FlexHostView(tree: fixedColumn)
        let fitted = host.sizeThatFits(CGSize(width: 0, height: 0))   // both axes unconstrained
        XCTAssertEqual(fitted.width, 152, accuracy: 0.5)
        XCTAssertEqual(fitted.height, 142, accuracy: 0.5)
    }

    func testNarrowerWidthYieldsTallerSelfSize() {
        let host = FlexHostView(tree: paragraph)
        let wide = host.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))
        let narrow = host.sizeThatFits(CGSize(width: 140, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertGreaterThan(narrow.height, wide.height)
        XCTAssertEqual(wide.width, 320, accuracy: 0.5)
        XCTAssertEqual(narrow.width, 140, accuracy: 0.5)
    }

    // MARK: independence from layoutSubviews

    func testSelfSizePassDoesNotDisturbAMountedLayout() {
        let (window, host) = HostHarness.mount(fixedColumn, size: CGSize(width: 300, height: 400))
        defer { window.resignKey() }

        let before = host.currentRenderTree.view(id: "b")!.frame
        _ = host.sizeThatFits(CGSize(width: 120, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertEqual(host.currentRenderTree.view(id: "b")!.frame, before,
                       "a measure-only pass applies no geometry and schedules no relayout")

        HostHarness.relayout(host)
        XCTAssertEqual(host.currentRenderTree.view(id: "b")!.frame, before,
                       "the next real pass still lands where it did")
    }

    func testSelfSizePassDoesNotEmitALayoutObservation() {
        let observer = RecordingRenderObserver()
        let host = FlexHostView(tree: fixedColumn)
        host.renderObserver = observer

        _ = host.sizeThatFits(CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertTrue(observer.layoutPasses.isEmpty, "measuring is not laying out")

        let (window, _) = HostHarness.finishMount(host: host, size: CGSize(width: 200, height: 300))
        defer { window.resignKey() }
        XCTAssertFalse(observer.layoutPasses.isEmpty, "a geometry pass is still reported")
    }

    // MARK: intrinsicContentSize

    func testIntrinsicContentSizeReportsHeightAndDefersWidthWhenSized() {
        let (window, host) = HostHarness.mount(fixedColumn, size: CGSize(width: 250, height: 400))
        defer { window.resignKey() }

        let intrinsic = host.intrinsicContentSize
        XCTAssertEqual(intrinsic.width, UIView.noIntrinsicMetric, "width is left to Auto Layout once the host is sized")
        XCTAssertEqual(intrinsic.height, 142, accuracy: 0.5)
    }

    func testIntrinsicContentSizeReportsBothExtentsWhenUnsized() {
        let host = FlexHostView(tree: fixedColumn)          // never given a width
        let intrinsic = host.intrinsicContentSize
        XCTAssertEqual(intrinsic.width, 152, accuracy: 0.5)
        XCTAssertEqual(intrinsic.height, 142, accuracy: 0.5)
    }

    func testIntrinsicContentSizeTerminatesWhenQueriedDuringAPass() {
        let host = FlexHostView(tree: fixedColumn)
        host.bounds = CGRect(x: 0, y: 0, width: 200, height: 0)

        let settled = host.intrinsicContentSize            // real pass: depth 0 → 1 → 0
        XCTAssertEqual(settled.height, 142, accuracy: 0.5)

        XCTAssertTrue(host.reentrancy.enter(), "stand in for a running layoutSubviews")
        let reentered = host.intrinsicContentSize          // must return without nesting a pass
        host.reentrancy.leave()

        XCTAssertEqual(reentered.height, settled.height, accuracy: 0.5,
                       "a re-entrant query returns the last self-sized result")
        XCTAssertFalse(host.reentrancy.isActive, "guard depth is balanced")
    }

    // MARK: systemLayoutSizeFitting

    func testSystemLayoutSizeFittingPinsARequiredAxis() {
        let host = FlexHostView(tree: fixedColumn)
        let size = host.systemLayoutSizeFitting(
            CGSize(width: 250, height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        XCTAssertEqual(size.width, 250, accuracy: 0.5, "required horizontal priority pins the width")
        XCTAssertEqual(size.height, 142, accuracy: 0.5, "vertical is free → natural height")
    }

    func testSystemLayoutSizeFittingUnpinnedFallsBackToSizeThatFits() {
        let host = FlexHostView(tree: fixedColumn)
        let a = host.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let b = host.sizeThatFits(UIView.layoutFittingCompressedSize)
        XCTAssertEqual(a.width, b.width, accuracy: 0.5)
        XCTAssertEqual(a.height, b.height, accuracy: 0.5)
    }
}
#endif
