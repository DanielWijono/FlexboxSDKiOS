//
//  FlexHostViewSnapshotTests.swift
//  FlexboxKitTests
//
//  A visual sanity check on the Step 1 static render path: a `LayoutTree` value
//  becomes a laid-out `UIView` hierarchy, captured as a PNG under
//  `__Snapshots__/`. First run records the image and fails ("recorded — re-run");
//  after that it guards the pixels. Re-record with FLEX_RECORD_SNAPSHOTS=1.
//
//  iOS Simulator only.
//

#if canImport(UIKit)
import XCTest
import UIKit
import FlexboxCore
import FlexboxKit
import FlexboxKitTestSupport
import FlexboxCoreTestSupport

@MainActor
final class FlexHostViewSnapshotTests: XCTestCase {

    /// Tinted containers + images so the flex boxes are visible; text stays on
    /// the built-in `UILabel` factory.
    private func tintedRegistry() -> FlexViewRegistry {
        var registry = FlexViewRegistry.default
        registry.register(DebugBoxFactory(fill: UIColor.systemBlue.withAlphaComponent(0.12)),
                          for: .container)
        registry.register(DebugBoxFactory(fill: UIColor.systemGreen.withAlphaComponent(0.30)),
                          for: .image)
        return registry
    }

    private func host(_ tree: LayoutTree) -> FlexHostView {
        let host = FlexHostView(tree: tree, registry: tintedRegistry())
        host.backgroundColor = .systemBackground
        return host
    }

    // MARK: Fixtures

    /// A full-width column: a 3-across weighted row, a headline, a wrapping
    /// paragraph. Nothing here sets a frame by hand.
    private var demoScreen: LayoutTree {
        LayoutTree(
            id: "screen", content: .container,
            style: FlexStyle(flexDirection: .column,
                             padding: Edges(.points(16)),
                             gap: .points(12)),
            children: [
                LayoutTree(
                    id: "row", content: .container,
                    style: FlexStyle(flexDirection: .row, height: .points(64), gap: .points(8)),
                    children: [
                        LayoutTree(id: "a", content: .container, style: FlexStyle(flexGrow: 1)),
                        LayoutTree(id: "b", content: .container, style: FlexStyle(flexGrow: 2)),
                        LayoutTree(id: "c", content: .container, style: FlexStyle(flexGrow: 1)),
                    ]
                ),
                LayoutTree(id: "headline", content: .text,
                           props: ["text": .string("Server-driven layout"),
                                   "numberOfLines": .number(1)]),
                LayoutTree(id: "para", content: .text,
                           props: ["text": .string(
                               "This screen was built from a LayoutTree value and laid out "
                                   + "by Yoga. The renderer only wrote bounds.size and center.")]),
            ]
        )
    }

    // MARK: Tests

    func testDemoScreenSnapshot() {
        FlexSnapshot.verify(host(demoScreen),
                            named: "demo-screen-320w",
                            size: CGSize(width: 320, height: 220))
    }

    func testCardFixtureSnapshot() {
        FlexSnapshot.verify(host(TreeFixtures.card),
                            named: "card-fixture-320w",
                            size: CGSize(width: 320, height: 160))
    }

    func testNarrowWidthReflowsParagraph() {
        // Same tree, half the width — the paragraph should wrap to more lines and
        // the row's boxes should get proportionally narrower.
        FlexSnapshot.verify(host(demoScreen),
                            named: "demo-screen-160w",
                            size: CGSize(width: 160, height: 320))
    }

    // MARK: Step 4 — content invalidation, visualised

    /// Three states of one host driven by `update(to:)`:
    ///   0 — initial
    ///   1 — `detail` text replaced with a long string → the leaf re-measures,
    ///       the column reflows taller
    ///   2 — only `detail`'s `textColor` changed → identical layout, new colour
    ///       (no `markContentDirty`, no re-measure)
    private var note: LayoutTree {
        LayoutTree(
            id: "note", content: .container,
            style: FlexStyle(flexDirection: .column, padding: Edges(.points(16)), gap: .points(8)),
            children: [
                LayoutTree(id: "title", content: .text,
                           props: ["text": .string("Status"), "numberOfLines": .number(1)]),
                LayoutTree(id: "detail", content: .text,
                           props: ["text": .string("All systems normal."),
                                   "textColor": .string("#1A7F37")]),
            ]
        )
    }

    private func detail(text: String, color: String) -> LayoutTree {
        var t = note
        t.children[1].props = ["text": .string(text), "textColor": .string(color)]
        return t
    }

    func testContentInvalidationInitial() {
        FlexSnapshot.verify(host(note),
                            named: "content-update-0-initial",
                            size: CGSize(width: 260, height: 150))
    }

    func testContentInvalidationTextGrew() {
        let h = host(note)
        h.update(to: detail(
            text: "Degraded performance in us-east-1. Investigating elevated error rates on checkout.",
            color: "#1A7F37"))
        FlexSnapshot.verify(h,
                            named: "content-update-1-text-grew",
                            size: CGSize(width: 260, height: 150))
    }

    func testContentInvalidationColorOnly() {
        let h = host(note)
        h.update(to: detail(
            text: "Degraded performance in us-east-1. Investigating elevated error rates on checkout.",
            color: "#1A7F37"))
        h.update(to: detail(
            text: "Degraded performance in us-east-1. Investigating elevated error rates on checkout.",
            color: "#CF222E"))
        FlexSnapshot.verify(h,
                            named: "content-update-2-color-only",
                            size: CGSize(width: 260, height: 150))
    }
}
#endif
