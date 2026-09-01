//
//  TraitAndParticipationTests.swift
//  FlexboxKitTests
//
//  Step 6: trait reactions and layout participation.
//    • displayScale change            → fresh FlexConfig with the matching
//                                       pointScaleFactor, tree rebound.
//    • preferredContentSizeCategory   → MeasureCache flushed, relayout scheduled.
//    • layoutDirection / forced RTL   → the next pass runs `calculate(direction:)`.
//    • isHidden                       → effective `display: none`, siblings reflow.
//    • isIncludedInLayout == false    → the renderer leaves that frame alone and
//                                       the child-count invariant still holds.
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
final class TraitAndParticipationTests: XCTestCase {

    // MARK: Fixtures

    private func box(_ id: String, w: Double, h: Double) -> LayoutTree {
        LayoutTree(id: id, content: .container,
                   style: FlexStyle(width: .points(w), height: .points(h)))
    }

    /// A column of three 40-pt rows with a 10-pt gap. `c` sits at y = 100.
    private var stack: LayoutTree {
        LayoutTree(
            id: "stack", content: .container,
            style: FlexStyle(flexDirection: .column, gap: .points(10)),
            children: [box("a", w: 80, h: 40), box("b", w: 80, h: 40), box("c", w: 80, h: 40)]
        )
    }

    /// A row of two 60-pt boxes with a 10-pt gap.
    private var pair: LayoutTree {
        LayoutTree(
            id: "row", content: .container,
            style: FlexStyle(flexDirection: .row, gap: .points(10)),
            children: [box("a", w: 60, h: 40), box("b", w: 60, h: 40)]
        )
    }

    /// A padded column around one wrapping paragraph (a measured `text` leaf).
    private var paragraph: LayoutTree {
        LayoutTree(
            id: "wrap", content: .container,
            style: FlexStyle(flexDirection: .column, padding: Edges(.points(8))),
            children: [
                LayoutTree(id: "p", content: .text,
                           props: ["text": .string(
                               "A reasonably long line of text that wraps onto several rows "
                                   + "when the available width is narrow enough.")]),
            ]
        )
    }

    private func traits(
        scale: CGFloat? = nil,
        category: UIContentSizeCategory? = nil,
        direction: UITraitEnvironmentLayoutDirection? = nil
    ) -> UITraitCollection {
        var parts: [UITraitCollection] = []
        if let scale { parts.append(UITraitCollection(displayScale: scale)) }
        if let category { parts.append(UITraitCollection(preferredContentSizeCategory: category)) }
        if let direction { parts.append(UITraitCollection(layoutDirection: direction)) }
        return UITraitCollection(traitsFrom: parts)
    }

    // MARK: displayScale

    func testDisplayScaleChangeRebuildsConfigWithMatchingPointScale() {
        let (window, host) = HostHarness.mount(stack, size: CGSize(width: 200, height: 300))
        defer { window.resignKey() }
        let observer = RecordingRenderObserver()
        host.renderObserver = observer

        host.flexApplyTraitChange(previous: traits(scale: 2), current: traits(scale: 3))

        XCTAssertEqual(host.currentConfig().pointScaleFactor, 3, accuracy: 0.001,
                       "a scale change swaps in a fresh, per-tree FlexConfig")
        XCTAssertTrue(observer.traitRebuilds.contains("displayScale"))
        // The rebound tree still lays out.
        HostHarness.relayout(host)
        XCTAssertEqual(host.currentRenderTree.view(id: "c")!.frame.minY, 100, accuracy: 0.5)
    }

    func testEqualDisplayScaleIsANoOp() {
        let (window, host) = HostHarness.mount(stack, size: CGSize(width: 200, height: 300))
        defer { window.resignKey() }
        let observer = RecordingRenderObserver()
        host.renderObserver = observer
        let configBefore = host.currentConfig()

        host.flexApplyTraitChange(previous: traits(scale: 3), current: traits(scale: 3))

        XCTAssertTrue(host.currentConfig() === configBefore, "no rebind when the scale is unchanged")
        XCTAssertTrue(observer.traitRebuilds.isEmpty)
    }

    // MARK: preferredContentSizeCategory

    func testContentSizeCategoryChangeFlushesTheCacheAndRelayouts() {
        let (window, host) = HostHarness.mount(paragraph, size: CGSize(width: 200, height: 400))
        defer { window.resignKey() }
        let observer = RecordingRenderObserver()
        host.renderObserver = observer
        XCTAssertGreaterThan(host.currentCache().count, 0, "the mount pass populated the measure cache")

        host.flexApplyTraitChange(
            previous: traits(category: .large),
            current: traits(category: .accessibilityExtraExtraExtraLarge)
        )

        XCTAssertEqual(host.currentCache().count, 0, "every stale text metric was dropped")
        XCTAssertTrue(observer.traitRebuilds.contains("preferredContentSizeCategory"))

        host.layoutIfNeeded()
        XCTAssertFalse(observer.layoutPasses.isEmpty, "a relayout was scheduled")
    }

    func testEqualContentSizeCategoryIsANoOp() {
        let (window, host) = HostHarness.mount(paragraph, size: CGSize(width: 200, height: 400))
        defer { window.resignKey() }
        let observer = RecordingRenderObserver()
        host.renderObserver = observer
        let cachedBefore = host.currentCache().count

        host.flexApplyTraitChange(
            previous: traits(category: .large), current: traits(category: .large)
        )

        XCTAssertEqual(host.currentCache().count, cachedBefore, "cache untouched")
        XCTAssertTrue(observer.traitRebuilds.isEmpty)
    }

    // MARK: layoutDirection

    func testLayoutDirectionChangeSchedulesAPass() {
        let (window, host) = HostHarness.mount(pair, size: CGSize(width: 300, height: 100))
        defer { window.resignKey() }
        let observer = RecordingRenderObserver()
        host.renderObserver = observer

        host.flexApplyTraitChange(
            previous: traits(direction: .leftToRight),
            current: traits(direction: .rightToLeft)
        )

        XCTAssertTrue(observer.traitRebuilds.contains("layoutDirection"))
        host.layoutIfNeeded()
        XCTAssertFalse(observer.layoutPasses.isEmpty)
    }

    func testForcedRightToLeftMirrorsRootChildOrder() {
        let (window, host) = HostHarness.mount(pair, size: CGSize(width: 300, height: 100))
        defer { window.resignKey() }

        let aLTR = host.currentRenderTree.view(id: "a")!.frame.minX
        let bLTR = host.currentRenderTree.view(id: "b")!.frame.minX
        XCTAssertLessThan(aLTR, bLTR, "LTR: first child is left of the second")

        host.semanticContentAttribute = .forceRightToLeft
        HostHarness.relayout(host)

        let aRTL = host.currentRenderTree.view(id: "a")!.frame.minX
        let bRTL = host.currentRenderTree.view(id: "b")!.frame.minX
        XCTAssertGreaterThan(aRTL, bRTL, "RTL: the pass ran calculate(direction: .rtl) — first child is now on the right")
        XCTAssertEqual(aRTL, 300 - 60, accuracy: 0.5)
    }

    // MARK: isHidden → display: none

    func testHidingASiblingReflowsTheOthers() {
        let (window, host) = HostHarness.mount(stack, size: CGSize(width: 200, height: 300))
        defer { window.resignKey() }
        XCTAssertEqual(host.currentRenderTree.view(id: "c")!.frame.minY, 100, accuracy: 0.5)

        host.currentRenderTree.view(id: "b")!.isHidden = true
        HostHarness.relayout(host)
        XCTAssertEqual(host.currentRenderTree.view(id: "c")!.frame.minY, 50, accuracy: 0.5,
                       "the hidden sibling collapsed to display: none")

        host.currentRenderTree.view(id: "b")!.isHidden = false
        HostHarness.relayout(host)
        XCTAssertEqual(host.currentRenderTree.view(id: "c")!.frame.minY, 100, accuracy: 0.5,
                       "un-hiding restores the sibling to display: flex")
    }

    // MARK: isIncludedInLayout

    func testExcludedNonTreeSubviewKeepsItsFrameAndTheInvariantHolds() {
        let plain = HostHarness.mount(stack, size: CGSize(width: 200, height: 300))
        defer { plain.window.resignKey() }
        let withExtra = HostHarness.mount(stack, size: CGSize(width: 200, height: 300))
        defer { withExtra.window.resignKey() }

        let extra = UIView(frame: CGRect(x: 0, y: 500, width: 50, height: 50))
        extra.isIncludedInLayout = false
        withExtra.host.currentRenderTree.view(id: "stack")!.addSubview(extra)
        HostHarness.relayout(withExtra.host)

        XCTAssertEqual(extra.frame, CGRect(x: 0, y: 500, width: 50, height: 50),
                       "a self-positioned subview is never touched by the renderer")
        XCTAssertTrue(
            HostHarness.childCountInvariantHolds(from: withExtra.host.currentRenderTree.rootView),
            "the excluded subview does not count toward the child-count invariant"
        )
        XCTAssertEqual(
            withExtra.host.currentRenderTree.view(id: "c")!.frame,
            plain.host.currentRenderTree.view(id: "c")!.frame,
            "the real children land exactly where they would without the extra view"
        )
    }

    func testExcludingAManagedSubviewLeavesItsFrameAlone() {
        let (window, host) = HostHarness.mount(stack, size: CGSize(width: 200, height: 300))
        defer { window.resignKey() }

        let bView = host.currentRenderTree.view(id: "b")!
        bView.isIncludedInLayout = false
        let parked = CGRect(x: 11, y: 222, width: 33, height: 44)
        bView.frame = parked
        HostHarness.relayout(host)

        XCTAssertEqual(bView.frame, parked, "the renderer skips geometry for a non-participating subview")
        XCTAssertEqual(host.currentRenderTree.view(id: "a")!.frame.minY, 0, accuracy: 0.5,
                       "the other children still lay out")
    }
}
#endif
