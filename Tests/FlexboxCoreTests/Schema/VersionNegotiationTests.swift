import XCTest
@testable import FlexboxCore

final class VersionNegotiationTests: XCTestCase {

    private func payload(version: String, rootID: String = "root") -> Data {
        Data(#"{ "schemaVersion": \#(version), "root": { "id": "\#(rootID)", "content": "container" } }"#.utf8)
    }

    func testCurrentVersionDecodes() throws {
        let tree = try LayoutDecoding.decode(payload(version: "\(LayoutSchema.current)"))
        XCTAssertEqual(tree.id, "root")
    }

    func testNewerVersionIsRejected() {
        XCTAssertThrowsError(try LayoutDecoding.decode(payload(version: "999"))) { error in
            guard case LayoutDecodingError.unsupportedVersion(let found, _) = error else {
                return XCTFail("wrong error: \(error)")
            }
            XCTAssertEqual(found, 999)
        }
    }

    func testMissingVersionIsTreatedAsUnsupported() {
        let data = Data(#"{ "root": { "id": "root", "content": "container" } }"#.utf8)
        XCTAssertThrowsError(try LayoutDecoding.decode(data)) { error in
            guard case LayoutDecodingError.unsupportedVersion(let found, _) = error else {
                return XCTFail("wrong error: \(error)")
            }
            XCTAssertEqual(found, 0)
        }
    }

    func testDecodingNeverTraps() {
        // Whatever we throw at it, we get a thrown error, not a crash.
        for bytes in ["", "{", "null", "[]", #"{"schemaVersion":"x"}"#, #"{"root":5}"#] {
            XCTAssertThrowsError(try LayoutDecoding.decode(Data(bytes.utf8)))
        }
    }
}
