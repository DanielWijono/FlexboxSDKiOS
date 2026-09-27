//
//  TextFactoryTests.swift
//  FlexboxKitTests
//
//  Built-in text follows Dynamic Type: without a `font` prop the label starts
//  from a text-style font, the only kind `adjustsFontForContentSizeCategory`
//  can scale.
//
//  iOS Simulator only.
//

#if canImport(UIKit)
import XCTest
import UIKit
import FlexboxCore
@testable import FlexboxKit

@MainActor
final class TextFactoryTests: XCTestCase {

    func testDefaultTextUsesTheBodyTextStyle() {
        let label = TextViewFactory().makeView(
            for: LayoutTree(id: "t", content: .text, props: ["text": .string("Hi")])
        ) as! UILabel

        XCTAssertTrue(label.adjustsFontForContentSizeCategory)
        XCTAssertEqual(label.font.fontDescriptor.object(forKey: .textStyle) as? UIFont.TextStyle, .body)
    }
}
#endif
