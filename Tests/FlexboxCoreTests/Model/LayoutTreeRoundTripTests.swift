import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

final class LayoutTreeRoundTripTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func testCardFixtureRoundTrips() throws {
        let tree = TreeFixtures.card
        let decoded = try decoder.decode(LayoutTree.self, from: try encoder.encode(tree))
        XCTAssertEqual(decoded, tree)
    }

    func testDefaultsAreOmittedThenRestored() throws {
        let tree = LayoutTree(id: "x", content: .container) // empty style, no children
        let json = String(decoding: try encoder.encode(tree), as: UTF8.self)
        XCTAssertFalse(json.contains("style"))
        XCTAssertFalse(json.contains("children"))
        let back = try decoder.decode(LayoutTree.self, from: Data(json.utf8))
        XCTAssertEqual(back.style, .empty)
        XCTAssertEqual(back.children, [])
    }

    func testMissingIDFailsDecoding() {
        let json = Data(#"{ "content": "container" }"#.utf8)
        XCTAssertThrowsError(try decoder.decode(LayoutTree.self, from: json))
    }

    func testDeterministicFuzzRoundTrip() throws {
        for seed in UInt64(1) ... 50 {
            let tree = TreeFixtures.randomTree(seed: seed)
            let decoded = try decoder.decode(LayoutTree.self, from: try encoder.encode(tree))
            XCTAssertEqual(decoded, tree, "seed \(seed)")
        }
    }

    func testContentTypeCustomRoundTrips() throws {
        let tree = LayoutTree(id: "r", content: .custom("RatingStars"),
                              props: ["value": .number(4)])
        let decoded = try decoder.decode(LayoutTree.self, from: try encoder.encode(tree))
        XCTAssertEqual(decoded.content, .custom("RatingStars"))
        XCTAssertEqual(decoded.props?["value"], .number(4))
    }
}
