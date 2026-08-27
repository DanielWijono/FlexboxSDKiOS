import XCTest
@testable import FlexboxCore

final class EdgesCodableTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func testScalarShorthandDecodesToAll() throws {
        let edges = try decoder.decode(Edges.self, from: Data("16".utf8))
        XCTAssertEqual(edges.all, .points(16))
        XCTAssertNil(edges.top)
    }

    func testScalarShorthandRoundTripsAsScalar() throws {
        let edges = Edges(.points(16))
        let data = try encoder.encode(edges)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "16")
        XCTAssertEqual(try decoder.decode(Edges.self, from: data), edges)
    }

    func testObjectFormRoundTrips() throws {
        let edges = Edges(top: .points(8), horizontal: .points(16))
        let data = try encoder.encode(edges)
        let back = try decoder.decode(Edges.self, from: data)
        XCTAssertEqual(back, edges)
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("\"top\":8"))
        XCTAssertTrue(json.contains("\"horizontal\":16"))
        XCTAssertFalse(json.contains("bottom"))
    }

    func testPercentAndAutoEdges() throws {
        let edges = Edges(left: .percent(10), right: .auto)
        XCTAssertEqual(try decoder.decode(Edges.self, from: try encoder.encode(edges)), edges)
    }

    func testBorderWidthsShorthandAndObject() throws {
        XCTAssertEqual(try decoder.decode(EdgeWidths.self, from: Data("2".utf8)), EdgeWidths(2))
        let w = EdgeWidths(top: 1, bottom: 3)
        XCTAssertEqual(try decoder.decode(EdgeWidths.self, from: try encoder.encode(w)), w)
    }
}
