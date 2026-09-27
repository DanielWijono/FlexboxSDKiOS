//
//  RightToLeftTests.swift
//  FlexboxKitTests
//
//  RTL (spec Artefak 3 §"RTL"): the host's `effectiveUserInterfaceLayoutDirection`
//  is passed to Yoga, so a row mirrors — the first child starts at the right edge.
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
final class RightToLeftTests: XCTestCase {

    /// A 320-wide row of two fixed boxes: a (50×40) then b (70×40).
    private var row: LayoutTree {
        LayoutTree(
            id: "row", content: .container,
            style: FlexStyle(flexDirection: .row),
            children: [
                LayoutTree(id: "a", content: .container,
                           style: FlexStyle(width: .points(50), height: .points(40))),
                LayoutTree(id: "b", content: .container,
                           style: FlexStyle(width: .points(70), height: .points(40))),
            ]
        )
    }

    private func frames(_ host: FlexHostView) -> (a: CGRect, b: CGRect) {
        (host.currentRenderTree.view(id: "a")!.frame, host.currentRenderTree.view(id: "b")!.frame)
    }

    func testLeftToRightRowStartsAtTheLeft() {
        let (window, host) = HostHarness.mount(row, size: CGSize(width: 320, height: 100))
        defer { window.resignKey() }

        let (a, b) = frames(host)
        XCTAssertEqual(a.minX, 0, accuracy: 0.5)
        XCTAssertEqual(b.minX, 50, accuracy: 0.5)
    }

    func testRightToLeftRowIsMirrored() {
        let host = FlexHostView(tree: row)
        host.semanticContentAttribute = .forceRightToLeft
        let (window, _) = HostHarness.finishMount(host: host, size: CGSize(width: 320, height: 100))
        defer { window.resignKey() }

        let (a, b) = frames(host)
        XCTAssertEqual(a.maxX, 320, accuracy: 0.5, "first child hugs the right edge")
        XCTAssertEqual(b.maxX, 270, accuracy: 0.5, "second child sits to its left")
    }

    func testFlippingDirectionOnAMountedHostMirrorsOnTheNextPass() {
        let (window, host) = HostHarness.mount(row, size: CGSize(width: 320, height: 100))
        defer { window.resignKey() }

        host.semanticContentAttribute = .forceRightToLeft
        HostHarness.relayout(host)

        XCTAssertEqual(frames(host).a.maxX, 320, accuracy: 0.5)
    }
}
#endif
