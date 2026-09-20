//
//  SafeAreaResolutionTests.swift
//  FlexboxKitTests
//
//  The pure half of safe-area support: resolving `payload root border + insets`
//  to the value written on the root node. Runs under `swift test` on macOS.
//

import XCTest
import FlexboxCore
@testable import FlexboxKit

final class SafeAreaResolutionTests: XCTestCase {

    private let insets = SafeAreaResolution.Insets(top: 47, left: 0, bottom: 34, right: 0)

    // MARK: - Edge filtering

    func testKeepingZeroesEdgesOutsideTheSet() {
        let kept = SafeAreaResolution.Insets(top: 47, left: 5, bottom: 34, right: 7)
            .keeping(.top)
        XCTAssertEqual(kept, SafeAreaResolution.Insets(top: 47, left: 0, bottom: 0, right: 0))
    }

    func testKeepingAllIsIdentity() {
        let all = SafeAreaResolution.Insets(top: 47, left: 5, bottom: 34, right: 7)
        XCTAssertEqual(all.keeping(.all), all)
    }

    func testKeepingVerticalKeepsTopAndBottom() {
        let kept = SafeAreaResolution.Insets(top: 47, left: 5, bottom: 34, right: 7)
            .keeping(.vertical)
        XCTAssertEqual(kept, SafeAreaResolution.Insets(top: 47, left: 0, bottom: 34, right: 0))
    }

    func testZeroInsetsAreRecognised() {
        XCTAssertTrue(SafeAreaResolution.Insets.zero.isZero)
        XCTAssertFalse(insets.isZero)
    }

    // MARK: - Resolution

    func testNoPayloadBorderYieldsTheInsetsThemselves() {
        let resolved = SafeAreaResolution.resolve(
            payloadBorder: nil, insets: insets, direction: .ltr
        )
        XCTAssertEqual(resolved.top, 47)
        XCTAssertEqual(resolved.bottom, 34)
        XCTAssertEqual(resolved.left, 0)
        XCTAssertEqual(resolved.right, 0)
    }

    func testPayloadBorderStacksRatherThanBeingReplaced() {
        let resolved = SafeAreaResolution.resolve(
            payloadBorder: EdgeWidths(all: 2), insets: insets, direction: .ltr
        )
        XCTAssertEqual(resolved.top, 49)
        XCTAssertEqual(resolved.bottom, 36)
        XCTAssertEqual(resolved.left, 2)
        XCTAssertEqual(resolved.right, 2)
    }

    /// Yoga reads one physical edge as specific > horizontal/vertical > all;
    /// `resolve` has to read it the same way or the payload's value is lost.
    func testSpecificEdgeBeatsShorthandJustAsYogaResolvesIt() {
        let payload = EdgeWidths(top: 10, vertical: 5, all: 1)
        let resolved = SafeAreaResolution.resolve(
            payloadBorder: payload,
            insets: SafeAreaResolution.Insets(top: 47, left: 0, bottom: 34, right: 3),
            direction: .ltr
        )
        XCTAssertEqual(resolved.top, 57)       // top (10) wins over vertical/all
        XCTAssertEqual(resolved.bottom, 39)    // vertical (5) wins over all
        XCTAssertEqual(resolved.right, 4)      // all (1)
    }

    func testStartMapsToLeftInLTRAndToRightInRTL() {
        let payload = EdgeWidths(start: 20)
        let sideInsets = SafeAreaResolution.Insets(top: 0, left: 1, bottom: 0, right: 2)

        let ltr = SafeAreaResolution.resolve(
            payloadBorder: payload, insets: sideInsets, direction: .ltr
        )
        XCTAssertEqual(ltr.left, 21)
        XCTAssertEqual(ltr.right, 2)

        let rtl = SafeAreaResolution.resolve(
            payloadBorder: payload, insets: sideInsets, direction: .rtl
        )
        XCTAssertEqual(rtl.left, 1)
        XCTAssertEqual(rtl.right, 22)
    }

    /// Every key Yoga might consult is written, and they all agree — otherwise a
    /// leftover payload `start` would outrank the physical edge we resolved.
    func testEveryPrecedenceKeyIsWrittenConsistently() {
        let resolved = SafeAreaResolution.resolve(
            payloadBorder: EdgeWidths(start: 20, horizontal: 6),
            insets: SafeAreaResolution.Insets(top: 0, left: 1, bottom: 0, right: 2),
            direction: .ltr
        )
        XCTAssertEqual(resolved.start, resolved.left)
        XCTAssertEqual(resolved.end, resolved.right)
        XCTAssertNil(resolved.horizontal, "shorthand keys must not survive and outrank nothing")
        XCTAssertNil(resolved.vertical)
        XCTAssertNil(resolved.all)
    }

    /// The zero-inset case has to reproduce the payload exactly: it is what the
    /// host writes to restore the payload's own border after opting back out.
    func testZeroInsetsReproduceThePayloadBorder() {
        let resolved = SafeAreaResolution.resolve(
            payloadBorder: EdgeWidths(top: 3, horizontal: 8),
            insets: .zero,
            direction: .ltr
        )
        XCTAssertEqual(resolved.top, 3)
        XCTAssertEqual(resolved.bottom, 0)
        XCTAssertEqual(resolved.left, 8)
        XCTAssertEqual(resolved.right, 8)
    }
}
