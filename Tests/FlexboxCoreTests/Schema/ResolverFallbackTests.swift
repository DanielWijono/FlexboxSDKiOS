import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

final class ResolverFallbackTests: XCTestCase {

    private final class Recorder: FlexObserver, @unchecked Sendable {
        var fallbacks: [String] = []
        func flexDidUseFallback(reason: String) { fallbacks.append(reason) }
    }

    private var recorder: Recorder!
    private let fallback = LayoutTree(id: "bundled", content: .container)

    override func setUp() {
        super.setUp()
        recorder = Recorder()
        FlexTelemetry.observer = recorder
    }

    override func tearDown() {
        FlexTelemetry.observer = nil
        recorder = nil
        super.tearDown()
    }

    private func encoded(_ tree: LayoutTree, version: Int = LayoutSchema.current) -> Data {
        try! JSONEncoder().encode(LayoutPayload(schemaVersion: version, root: tree))
    }

    func testValidRemoteWins() {
        let remote = LayoutTree(id: "remote", content: .container)
        let result = LayoutResolver.resolve(remote: encoded(remote), fallback: fallback)
        XCTAssertEqual(result, .remote(remote))
        XCTAssertFalse(result.usedFallback)
        XCTAssertTrue(recorder.fallbacks.isEmpty)
    }

    func testNilDataFallsBack() {
        let result = LayoutResolver.resolve(remote: nil, fallback: fallback)
        XCTAssertEqual(result.tree, fallback)
        guard case .fallback(_, .noRemoteData) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(recorder.fallbacks, ["noRemoteData"])
    }

    func testMalformedJSONFallsBack() {
        let result = LayoutResolver.resolve(remote: Data("{not json".utf8), fallback: fallback)
        XCTAssertEqual(result.tree, fallback)
        guard case .fallback(_, .parseFailed) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(recorder.fallbacks.count, 1)
    }

    func testUnsupportedVersionFallsBack() {
        let data = encoded(LayoutTree(id: "r", content: .container), version: 999)
        let result = LayoutResolver.resolve(remote: data, fallback: fallback)
        guard case .fallback(_, .unsupportedVersion(let found)) = result else { return XCTFail("\(result)") }
        XCTAssertEqual(found, 999)
    }

    func testValidationFailureFallsBack() {
        let bad = LayoutTree(id: "root", content: .container, children: [
            LayoutTree(id: "dup", content: .container),
            LayoutTree(id: "dup", content: .container),
        ])
        let result = LayoutResolver.resolve(remote: encoded(bad), fallback: fallback)
        guard case .fallback(_, .validationFailed) = result else { return XCTFail("\(result)") }
    }
}
