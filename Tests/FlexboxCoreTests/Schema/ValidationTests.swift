import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

final class ValidationTests: XCTestCase {

    func testCardFixtureIsValid() {
        XCTAssertNoThrow(try LayoutValidation.validate(TreeFixtures.card))
    }

    func testDuplicateIDRejected() {
        let tree = LayoutTree(id: "root", content: .container, children: [
            LayoutTree(id: "dup", content: .container),
            LayoutTree(id: "dup", content: .container),
        ])
        XCTAssertThrowsError(try LayoutValidation.validate(tree)) {
            guard case LayoutValidationError.duplicateID("dup") = $0 else { return XCTFail("\($0)") }
        }
    }

    func testLeafWithChildrenRejected() {
        let tree = LayoutTree(id: "root", content: .container, children: [
            LayoutTree(id: "txt", content: .text, children: [
                LayoutTree(id: "inner", content: .container),
            ]),
        ])
        XCTAssertThrowsError(try LayoutValidation.validate(tree)) {
            guard case LayoutValidationError.leafHasChildren(let id, _) = $0 else { return XCTFail("\($0)") }
            XCTAssertEqual(id, "txt")
        }
    }

    func testNegativeGrowRejected() {
        let tree = LayoutTree(id: "root", content: .container,
                              style: FlexStyle(flexGrow: -1))
        XCTAssertThrowsError(try LayoutValidation.validate(tree)) {
            guard case LayoutValidationError.negativeGrow = $0 else { return XCTFail("\($0)") }
        }
    }

    func testNonPositiveAspectRatioRejected() {
        let tree = LayoutTree(id: "root", content: .container,
                              style: FlexStyle(aspectRatio: 0))
        XCTAssertThrowsError(try LayoutValidation.validate(tree)) {
            guard case LayoutValidationError.nonPositiveAspectRatio = $0 else { return XCTFail("\($0)") }
        }
    }

    func testEmptyIDRejected() {
        let tree = LayoutTree(id: "", content: .container)
        XCTAssertThrowsError(try LayoutValidation.validate(tree)) {
            guard case LayoutValidationError.emptyID = $0 else { return XCTFail("\($0)") }
        }
    }
}
