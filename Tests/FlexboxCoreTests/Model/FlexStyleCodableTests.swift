import XCTest
@testable import FlexboxCore

final class FlexStyleCodableTests: XCTestCase {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = .sortedKeys
        return e
    }()
    private let decoder = JSONDecoder()

    func testAbsentKeyMeansNil() throws {
        let json = Data(#"{ "flexGrow": 1 }"#.utf8)
        let style = try decoder.decode(FlexStyle.self, from: json)
        XCTAssertEqual(style.flexGrow, 1)
        XCTAssertNil(style.width)
        XCTAssertNil(style.flexDirection)
        XCTAssertNil(style.padding)
    }

    func testEncodeOmitsUnspecifiedFields() throws {
        let style = FlexStyle(flexDirection: .row, gap: .points(8))
        let json = String(decoding: try encoder.encode(style), as: UTF8.self)
        XCTAssertTrue(json.contains("\"flexDirection\":\"row\""))
        XCTAssertTrue(json.contains("\"gap\":8"))
        XCTAssertFalse(json.contains("flexGrow"))
        XCTAssertFalse(json.contains("alignItems"))
    }

    func testEnumSpellings() throws {
        let json = Data(#"""
        { "justifyContent": "space-between", "alignItems": "flex-start", "position": "absolute" }
        """#.utf8)
        let style = try decoder.decode(FlexStyle.self, from: json)
        XCTAssertEqual(style.justifyContent, .spaceBetween)
        XCTAssertEqual(style.alignItems, .flexStart)
        XCTAssertEqual(style.position, .absolute)
    }

    func testFullRoundTripStability() throws {
        let style = FlexStyle(
            flexDirection: .columnReverse,
            justifyContent: .spaceEvenly,
            alignItems: .center,
            flexGrow: 2,
            flexShrink: 0,
            width: .percent(50),
            height: .points(44),
            maxWidth: .points(320),
            aspectRatio: 1.5,
            margin: Edges(top: .points(4)),
            padding: Edges(.points(12)),
            border: EdgeWidths(1),
            position: .relative,
            inset: Edges(left: .points(0)),
            gap: .points(6),
            display: .flex,
            overflow: .hidden,
            boxSizing: .borderBox
        )
        let once = try encoder.encode(style)
        let decoded = try decoder.decode(FlexStyle.self, from: once)
        XCTAssertEqual(decoded, style)
        let twice = try encoder.encode(decoded)
        XCTAssertEqual(once, twice)
    }

    func testUnknownEnumValueThrows() {
        let json = Data(#"{ "flexDirection": "diagonal" }"#.utf8)
        XCTAssertThrowsError(try decoder.decode(FlexStyle.self, from: json))
    }
}
