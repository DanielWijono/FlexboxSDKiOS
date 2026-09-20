//
//  SafeAreaTests.swift
//  FlexboxKitTests
//
//  `FlexSafeAreaMode` against a live host (spec Artefak 3 — Safe area):
//    • `.ignore` (the default) leaves the layout exactly as the payload wrote it
//    • `.padRoot` insets the root's children by the safe area, on the chosen edges
//    • the payload's own root spacing is preserved, not replaced
//    • opting back out restores the payload-only layout
//    • a self-size pass sees the same insets a geometry pass does
//
//  The device contributes its own insets on top of the controller's, so the
//  assertions are written against `host.safeAreaInsets` rather than constants.
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
final class SafeAreaTests: XCTestCase {

    /// root (column, fills the host)
    ///  └─ child (flexGrow 1 — takes whatever the root's content box leaves)
    private func tree(rootPadding: Edges? = nil, rootBorder: EdgeWidths? = nil) -> LayoutTree {
        LayoutTree(
            id: "root", content: .container,
            style: FlexStyle(
                flexDirection: .column,
                width: .percent(100), height: .percent(100),
                padding: rootPadding, border: rootBorder
            ),
            children: [
                LayoutTree(
                    id: "child", content: .container,
                    style: FlexStyle(flexGrow: 1, width: .percent(100))
                )
            ]
        )
    }

    private let extraInsets = UIEdgeInsets(top: 40, left: 8, bottom: 30, right: 6)

    /// The single child's frame, in the root view's coordinates — the root view
    /// itself always fills the host, so the child is what the insets move.
    private func childFrame(_ host: FlexHostView) -> CGRect {
        host.currentRenderTree.view(id: "child")?.frame ?? .null
    }

    // MARK: - Default: nothing happens

    func testIgnoreIsTheDefaultAndLeavesTheLayoutUntouched() {
        let mounted = HostHarness.mountInViewController(
            tree(), additionalSafeAreaInsets: extraInsets
        )
        defer { mounted.window.isHidden = true }

        XCTAssertEqual(mounted.host.safeAreaMode, .ignore)
        XCTAssertGreaterThan(
            mounted.host.safeAreaInsets.top, 0,
            "precondition: the harness must give the host a real safe area"
        )
        XCTAssertEqual(childFrame(mounted.host), mounted.host.bounds)
    }

    // MARK: - padRoot

    func testPadRootAllInsetsChildrenByTheSafeArea() {
        let mounted = HostHarness.mountInViewController(
            tree(), additionalSafeAreaInsets: extraInsets
        )
        defer { mounted.window.isHidden = true }
        let host = mounted.host

        host.safeAreaMode = .padRoot(.all)
        HostHarness.relayout(host)

        let insets = host.safeAreaInsets
        XCTAssertEqual(childFrame(host), host.bounds.inset(by: insets))
        XCTAssertEqual(
            host.currentRenderTree.rootView.frame, host.bounds,
            "the root view still fills the host — only its children move in"
        )
    }

    func testPadRootHonoursTheEdgeFilter() {
        let mounted = HostHarness.mountInViewController(
            tree(), additionalSafeAreaInsets: extraInsets
        )
        defer { mounted.window.isHidden = true }
        let host = mounted.host

        host.safeAreaMode = .padRoot(.top)
        HostHarness.relayout(host)

        let topOnly = UIEdgeInsets(top: host.safeAreaInsets.top, left: 0, bottom: 0, right: 0)
        XCTAssertEqual(childFrame(host), host.bounds.inset(by: topOnly))
    }

    /// The API promise: the safe area stacks on the payload's spacing, and does
    /// not replace it.
    func testSafeAreaStacksOnTopOfPayloadRootPadding() {
        let padding: CGFloat = 12
        let mounted = HostHarness.mountInViewController(
            tree(rootPadding: Edges(.points(Double(padding)))),
            additionalSafeAreaInsets: extraInsets
        )
        defer { mounted.window.isHidden = true }
        let host = mounted.host

        let withoutSafeArea = childFrame(host)
        XCTAssertEqual(withoutSafeArea, host.bounds.insetBy(dx: padding, dy: padding))

        host.safeAreaMode = .padRoot(.all)
        HostHarness.relayout(host)

        let insets = host.safeAreaInsets
        let expected = host.bounds
            .inset(by: insets)
            .insetBy(dx: padding, dy: padding)
        XCTAssertEqual(childFrame(host), expected)
    }

    /// Percentage root padding is the case a points-based merge could not have
    /// expressed — border-stacking has to handle it like any other.
    func testSafeAreaStacksOnTopOfPercentageRootPadding() {
        let mounted = HostHarness.mountInViewController(
            tree(rootPadding: Edges(.percent(10))),
            additionalSafeAreaInsets: extraInsets
        )
        defer { mounted.window.isHidden = true }
        let host = mounted.host

        // Percent padding resolves against the root's width on every edge.
        let pad = host.bounds.width * 0.1
        XCTAssertEqual(childFrame(host), host.bounds.insetBy(dx: pad, dy: pad))

        host.safeAreaMode = .padRoot(.all)
        HostHarness.relayout(host)

        let expected = host.bounds
            .inset(by: host.safeAreaInsets)
            .insetBy(dx: pad, dy: pad)
        XCTAssertEqual(childFrame(host), expected)
    }

    func testSafeAreaStacksOnTopOfPayloadRootBorder() {
        let border: CGFloat = 4
        let mounted = HostHarness.mountInViewController(
            tree(rootBorder: EdgeWidths(Double(border))),
            additionalSafeAreaInsets: extraInsets
        )
        defer { mounted.window.isHidden = true }
        let host = mounted.host

        host.safeAreaMode = .padRoot(.all)
        HostHarness.relayout(host)

        let expected = host.bounds
            .inset(by: host.safeAreaInsets)
            .insetBy(dx: border, dy: border)
        XCTAssertEqual(childFrame(host), expected)
    }

    /// Repeated passes must not accumulate: the value is recomputed from the
    /// payload each time, never added to what the last pass wrote.
    func testRepeatedPassesDoNotAccumulateInsets() {
        let mounted = HostHarness.mountInViewController(
            tree(), additionalSafeAreaInsets: extraInsets
        )
        defer { mounted.window.isHidden = true }
        let host = mounted.host

        host.safeAreaMode = .padRoot(.all)
        HostHarness.relayout(host)
        let afterFirst = childFrame(host)

        HostHarness.relayout(host)
        HostHarness.relayout(host)
        XCTAssertEqual(childFrame(host), afterFirst)
    }

    // MARK: - Opting back out

    func testOptingBackOutRestoresThePayloadLayout() {
        let padding: CGFloat = 12
        let mounted = HostHarness.mountInViewController(
            tree(rootPadding: Edges(.points(Double(padding)))),
            additionalSafeAreaInsets: extraInsets
        )
        defer { mounted.window.isHidden = true }
        let host = mounted.host

        let payloadOnly = childFrame(host)

        host.safeAreaMode = .padRoot(.all)
        HostHarness.relayout(host)
        XCTAssertNotEqual(childFrame(host), payloadOnly)

        host.safeAreaMode = .ignore
        HostHarness.relayout(host)
        XCTAssertEqual(childFrame(host), payloadOnly)
    }

    // MARK: - Self-size path

    func testSelfSizePassAccountsForTheSafeArea() {
        // A root that sizes to its content, so the insets show up in the answer.
        let sizing = LayoutTree(
            id: "root", content: .container,
            style: FlexStyle(flexDirection: .column, width: .percent(100)),
            children: [
                LayoutTree(
                    id: "child", content: .container,
                    style: FlexStyle(width: .percent(100), height: .points(100))
                )
            ]
        )
        let mounted = HostHarness.mountInViewController(
            sizing, additionalSafeAreaInsets: extraInsets
        )
        defer { mounted.window.isHidden = true }
        let host = mounted.host

        let offer = CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude)
        XCTAssertEqual(host.sizeThatFits(offer).height, 100)

        host.safeAreaMode = .padRoot(.all)
        HostHarness.relayout(host)

        let insets = host.safeAreaInsets
        XCTAssertEqual(
            host.sizeThatFits(offer).height,
            100 + insets.top + insets.bottom,
            accuracy: 0.01
        )
    }

    // MARK: - Invalidation

    func testSafeAreaChangeSchedulesAPassWhenOptedIn() {
        let mounted = HostHarness.mountInViewController(
            tree(), additionalSafeAreaInsets: .zero
        )
        defer { mounted.window.isHidden = true }
        let host = mounted.host

        host.safeAreaMode = .padRoot(.all)
        HostHarness.relayout(host)
        let before = childFrame(host)

        mounted.controller.additionalSafeAreaInsets = extraInsets
        mounted.window.layoutIfNeeded()
        host.layoutIfNeeded()

        XCTAssertNotEqual(
            childFrame(host), before,
            "safeAreaInsetsDidChange must schedule a pass, not wait for the next unrelated one"
        )
        XCTAssertEqual(childFrame(host), host.bounds.inset(by: host.safeAreaInsets))
    }

    func testSafeAreaChangeIsInertWhileIgnoring() {
        let mounted = HostHarness.mountInViewController(
            tree(), additionalSafeAreaInsets: .zero
        )
        defer { mounted.window.isHidden = true }
        let host = mounted.host

        let before = childFrame(host)
        mounted.controller.additionalSafeAreaInsets = extraInsets
        mounted.window.layoutIfNeeded()
        host.layoutIfNeeded()

        XCTAssertEqual(childFrame(host), before)
    }
}
#endif
