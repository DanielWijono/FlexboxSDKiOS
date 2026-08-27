import XCTest
@testable import FlexboxCore

final class LimitTests: XCTestCase {

    private func deepTree(depth: Int) -> LayoutTree {
        var node = LayoutTree(id: "leaf-\(depth)", content: .container)
        for level in stride(from: depth - 1, through: 1, by: -1) {
            node = LayoutTree(id: "n-\(level)", content: .container, children: [node])
        }
        return node
    }

    private func wideTree(count: Int) -> LayoutTree {
        LayoutTree(id: "root", content: .container,
                   children: (0 ..< count).map { LayoutTree(id: "c\($0)", content: .container) })
    }

    func testDepthLimitRejected() {
        let limits = LayoutLimits(maxDepth: 10)
        XCTAssertThrowsError(try LayoutValidation.validate(deepTree(depth: 50), limits: limits)) {
            guard case LayoutValidationError.depthExceeded = $0 else { return XCTFail("\($0)") }
        }
        XCTAssertNoThrow(try LayoutValidation.validate(deepTree(depth: 9), limits: limits))
    }

    func testNodeCountLimitRejected() {
        let limits = LayoutLimits(maxNodes: 100)
        XCTAssertThrowsError(try LayoutValidation.validate(wideTree(count: 500), limits: limits)) {
            guard case LayoutValidationError.nodeCountExceeded = $0 else { return XCTFail("\($0)") }
        }
    }

    func testHugePayloadFailsWithoutTrapping() {
        // ~20k nodes serialized then decoded — must throw, not crash, in DEBUG and RELEASE.
        let big = wideTree(count: 20_000)
        let data = try! JSONEncoder().encode(LayoutPayload(root: big))
        XCTAssertThrowsError(try LayoutDecoding.decode(data)) {
            guard case LayoutDecodingError.invalid(.nodeCountExceeded) = $0 else {
                return XCTFail("\($0)")
            }
        }
    }

    func testIDLengthLimit() {
        let longID = String(repeating: "x", count: 1000)
        let tree = LayoutTree(id: longID, content: .container)
        XCTAssertThrowsError(try LayoutValidation.validate(tree)) {
            guard case LayoutValidationError.idTooLong = $0 else { return XCTFail("\($0)") }
        }
    }
}
