import XCTest
@testable import FlexboxCore

final class FlexDimensionCodableTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private func roundTrip(_ value: FlexDimension) throws -> FlexDimension {
        try decoder.decode(FlexDimension.self, from: try encoder.encode(value))
    }

    func testPointsEncodeAsNumber() throws {
        let data = try encoder.encode(FlexDimension.points(12))
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "12")
        XCTAssertEqual(try roundTrip(.points(12)), .points(12))
        XCTAssertEqual(try roundTrip(.points(12.5)), .points(12.5))
    }

    func testPercentEncodesAsString() throws {
        let data = try encoder.encode(FlexDimension.percent(50))
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"50%\"")
        XCTAssertEqual(try roundTrip(.percent(50)), .percent(50))
        XCTAssertEqual(try roundTrip(.percent(33.3)), .percent(33.3))
    }

    func testAutoEncodesAsString() throws {
        let data = try encoder.encode(FlexDimension.auto)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"auto\"")
        XCTAssertEqual(try roundTrip(.auto), .auto)
    }

    func testDecodesFromRawJSON() throws {
        XCTAssertEqual(try decoder.decode(FlexDimension.self, from: Data("8".utf8)), .points(8))
        XCTAssertEqual(try decoder.decode(FlexDimension.self, from: Data("\"25%\"".utf8)), .percent(25))
        XCTAssertEqual(try decoder.decode(FlexDimension.self, from: Data("\"auto\"".utf8)), .auto)
    }

    func testRejectsNonFiniteAndGarbage() {
        XCTAssertThrowsError(try decoder.decode(FlexDimension.self, from: Data("\"wide\"".utf8)))
        XCTAssertThrowsError(try decoder.decode(FlexDimension.self, from: Data("\"%\"".utf8)))
        XCTAssertThrowsError(try decoder.decode(FlexDimension.self, from: Data("true".utf8)))
    }

    func testNaNIsNeverEmitted() throws {
        // A FlexStyle with no width must produce NO "width" key — absence, not NaN.
        let json = String(decoding: try encoder.encode(FlexStyle.empty), as: UTF8.self)
        XCTAssertFalse(json.contains("width"))
        XCTAssertFalse(json.lowercased().contains("nan"))
        XCTAssertEqual(json, "{}")
    }
}
