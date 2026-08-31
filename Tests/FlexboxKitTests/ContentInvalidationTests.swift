//
//  ContentInvalidationTests.swift
//  FlexboxKitTests
//
//  Step 4: which `props` changes force a leaf re-measure. Pure — runs under
//  `swift test` on macOS.
//

import XCTest
import FlexboxCore
@testable import FlexboxKit

final class ContentInvalidationTests: XCTestCase {

    func testContainerNeverRemeasures() {
        XCTAssertFalse(ContentInvalidation.requiresRemeasure(
            content: .container,
            old: ["anything": .string("a")],
            new: ["anything": .string("b")]
        ))
    }

    func testTextRemeasuresWhenTextChanges() {
        XCTAssertTrue(ContentInvalidation.requiresRemeasure(
            content: .text,
            old: ["text": .string("one")],
            new: ["text": .string("two")]
        ))
    }

    func testTextRemeasuresWhenFontOrLineCountChanges() {
        XCTAssertTrue(ContentInvalidation.requiresRemeasure(
            content: .text,
            old: ["text": .string("x"), "numberOfLines": .number(0)],
            new: ["text": .string("x"), "numberOfLines": .number(2)]
        ))
        XCTAssertTrue(ContentInvalidation.requiresRemeasure(
            content: .text,
            old: ["text": .string("x"), "font": .object(["size": .number(12)])],
            new: ["text": .string("x"), "font": .object(["size": .number(20)])]
        ))
    }

    func testTextIgnoresColorOnlyChange() {
        XCTAssertFalse(ContentInvalidation.requiresRemeasure(
            content: .text,
            old: ["text": .string("x"), "textColor": .string("#000")],
            new: ["text": .string("x"), "textColor": .string("#fff")]
        ))
    }

    func testImageRemeasuresOnSourceChangeButNotTint() {
        XCTAssertTrue(ContentInvalidation.requiresRemeasure(
            content: .image,
            old: ["image": .string("a")],
            new: ["systemImage": .string("star")]
        ))
        XCTAssertFalse(ContentInvalidation.requiresRemeasure(
            content: .image,
            old: ["image": .string("a"), "tintColor": .string("#000")],
            new: ["image": .string("a"), "tintColor": .string("#fff")]
        ))
    }

    func testCustomContentIsConservative() {
        XCTAssertTrue(ContentInvalidation.requiresRemeasure(
            content: .custom("chart"),
            old: ["series": .string("a")],
            new: ["series": .string("b")]
        ))
        XCTAssertFalse(ContentInvalidation.requiresRemeasure(
            content: .custom("chart"),
            old: ["series": .string("a")],
            new: ["series": .string("a")]
        ))
    }

    func testNilPropsHandledOnEitherSide() {
        XCTAssertTrue(ContentInvalidation.requiresRemeasure(
            content: .text, old: nil, new: ["text": .string("hi")]
        ))
        XCTAssertFalse(ContentInvalidation.requiresRemeasure(
            content: .text, old: nil, new: nil
        ))
    }
}
