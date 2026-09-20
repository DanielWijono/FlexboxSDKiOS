//
//  ScrollViewTests.swift
//  FlexboxKitTests
//
//  Step 7: `overflow: scroll` support.
//    • an overflow: scroll container is backed by a FlexScrollBackingView
//    • its box is the flex-laid size; contentSize is the child extent
//    • contentOffset survives a relayout (GeometryApplier preserves bounds.origin)
//    • scrollBehavior == .disabled falls back to a plain clipping container
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
final class ScrollViewTests: XCTestCase {

    /// root  (column, 200 x 300)
    ///  └─ scroll   (overflow: scroll, 200 x 300)
    ///       └─ content  (200 x 800 — taller than the viewport)
    private var scrollTree: LayoutTree {
        LayoutTree(
            id: "root", content: .container,
            style: FlexStyle(flexDirection: .column, width: .points(200), height: .points(300)),
            children: [
                LayoutTree(
                    id: "scroll", content: .container,
                    style: FlexStyle(width: .points(200), height: .points(300), overflow: .scroll),
                    children: [
                        LayoutTree(id: "content", content: .container,
                                   style: FlexStyle(width: .points(200), height: .points(800))),
                    ]
                ),
            ]
        )
    }

    private func mountScroll(
    ) -> (window: UIWindow, host: FlexHostView, scroll: FlexScrollBackingView) {
        let (window, host) = HostHarness.mount(scrollTree, size: CGSize(width: 200, height: 300))
        guard let scroll = host.currentRenderTree.view(id: "scroll") as? FlexScrollBackingView else {
            fatalError("overflow: scroll node was not backed by FlexScrollBackingView")
        }
        return (window, host, scroll)
    }

    func testScrollNodeIsBackedByAScrollViewSizedToContent() {
        let (window, _, scroll) = mountScroll()
        defer { window.resignKey() }

        XCTAssertEqual(scroll.bounds.size, CGSize(width: 200, height: 300),
                       "the scroll view's own box is its flex-laid size")
        XCTAssertEqual(scroll.contentSize, CGSize(width: 200, height: 800),
                       "contentSize tracks the laid-out content extent")
    }

    func testContentChildSitsInTheScrollViewsContentSpace() {
        let (window, host, _) = mountScroll()
        defer { window.resignKey() }

        guard let content = host.currentRenderTree.view(id: "content") else {
            return XCTFail("no content view")
        }
        XCTAssertEqual(content.frame, CGRect(x: 0, y: 0, width: 200, height: 800))
    }

    func testContentOffsetSurvivesARelayout() {
        let (window, host, scroll) = mountScroll()
        defer { window.resignKey() }

        scroll.contentOffset = CGPoint(x: 0, y: 250)   // within [0, 800 - 300]
        HostHarness.relayout(host)

        XCTAssertEqual(scroll.contentOffset, CGPoint(x: 0, y: 250),
                       "the geometry pass preserves bounds.origin / contentOffset")
        XCTAssertEqual(scroll.contentSize, CGSize(width: 200, height: 800),
                       "contentSize is recomputed to the same extent")
    }

    func testDisabledScrollBehaviorLeavesAPlainClippingContainer() {
        let (window, host) = HostHarness.mount(scrollTree, size: CGSize(width: 200, height: 300))
        defer { window.resignKey() }
        XCTAssertTrue(host.currentRenderTree.view(id: "scroll") is FlexScrollBackingView)

        host.scrollBehavior = .disabled   // rebinds the tree
        HostHarness.relayout(host)

        let view = host.currentRenderTree.view(id: "scroll")
        XCTAssertNotNil(view)
        XCTAssertFalse(view is FlexScrollBackingView,
                       ".disabled treats overflow: scroll like hidden — no scroll view")
        XCTAssertTrue(view?.clipsToBounds ?? false, "still clips, like overflow: hidden")
        XCTAssertEqual(host.currentRenderTree.view(id: "content")?.frame,
                       CGRect(x: 0, y: 0, width: 200, height: 800),
                       "content still lays out; it is just clipped, not scrollable")
    }
}
#endif
