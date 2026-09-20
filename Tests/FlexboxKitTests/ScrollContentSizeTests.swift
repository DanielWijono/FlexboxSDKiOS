//
//  ScrollContentSizeTests.swift
//  FlexboxKitTests
//
//  `ScrollContentSizing.contentSize(for:)` — the `UIScrollView.contentSize` a
//  scroll node's backing view is given after a pass. Pure (no UIKit); runs under
//  `swift test` on macOS.
//

import XCTest
import CoreGraphics
import FlexboxCore
@testable import FlexboxKit

final class ScrollContentSizeTests: XCTestCase {

    /// The recommended shape: one oversized content wrapper under the scroll
    /// node → contentSize is that wrapper's laid-out size.
    func testSingleContentChildDefinesTheExtent() {
        let content = FlexNode()
        content.apply(FlexStyle(width: .points(300), height: .points(900)))

        let scroll = FlexNode()
        scroll.apply(FlexStyle(width: .points(300), height: .points(400), overflow: .scroll))
        scroll.appendChild(content)

        scroll.calculate(availableWidth: 300, availableHeight: 400)

        XCTAssertEqual(
            ScrollContentSizing.contentSize(for: scroll),
            CGSize(width: 300, height: 900)
        )
    }

    /// Several stacked children (Yoga's default `flexShrink` is 0, so they keep
    /// their size past the viewport) → the union of their frames.
    func testUnionOfStackedChildren() {
        let scroll = FlexNode()
        scroll.apply(FlexStyle(
            flexDirection: .column,
            width: .points(200), height: .points(100), overflow: .scroll
        ))
        for _ in 0..<3 {
            let row = FlexNode()
            row.apply(FlexStyle(width: .points(200), height: .points(120)))
            scroll.appendChild(row)
        }

        scroll.calculate(availableWidth: 200, availableHeight: 100)

        XCTAssertEqual(
            ScrollContentSizing.contentSize(for: scroll),
            CGSize(width: 200, height: 360)
        )
    }

    func testNoChildrenIsZero() {
        let scroll = FlexNode()
        scroll.apply(FlexStyle(width: .points(200), height: .points(100), overflow: .scroll))
        scroll.calculate(availableWidth: 200, availableHeight: 100)

        XCTAssertEqual(ScrollContentSizing.contentSize(for: scroll), .zero)
    }
}
