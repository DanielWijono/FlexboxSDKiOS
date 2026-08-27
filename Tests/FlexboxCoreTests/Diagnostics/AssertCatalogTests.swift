import XCTest
@testable import FlexboxCore

final class AssertCatalogTests: XCTestCase {

    func testCatalogEnumeratesGuards() {
        XCTAssertFalse(YogaAssertCatalog.all.isEmpty)
        for guardEntry in YogaAssertCatalog.all {
            XCTAssertFalse(guardEntry.yogaCall.isEmpty)
            XCTAssertFalse(guardEntry.operation.isEmpty)
            XCTAssertFalse(guardEntry.guardCondition.isEmpty)
        }
    }

    func testEveryGuardedOperationHasACatalogEntry() {
        let operations = Set(YogaAssertCatalog.all.map(\.operation))
        for expected in [
            "FlexNode.insertChild",
            "FlexNode.setMeasure",
            "FlexNode.markContentDirty",
            "FlexNode.removeChild",
        ] {
            XCTAssertTrue(operations.contains(expected), "missing catalog entry for \(expected)")
        }
    }

    func testAssertGateDefaultsToFatal() {
        XCTAssertTrue(FlexPrecondition.assertsAreFatal)
    }
}
