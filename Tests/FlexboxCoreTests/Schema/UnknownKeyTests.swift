import XCTest
@testable import FlexboxCore

final class UnknownKeyTests: XCTestCase {

    func testUnknownKeysAreIgnoredNotFatal() throws {
        let data = Data(#"""
        {
          "schemaVersion": \#(LayoutSchema.current),
          "futureTopLevel": { "anything": true },
          "root": {
            "id": "root",
            "content": "container",
            "unknownNodeKey": 42,
            "style": { "flexGrow": 1, "unknownStyleKey": "ignored" },
            "children": [
              { "id": "a", "content": "text", "brandNewField": [1, 2, 3] }
            ]
          }
        }
        """#.utf8)

        let tree = try LayoutDecoding.decode(data)
        XCTAssertEqual(tree.id, "root")
        XCTAssertEqual(tree.style.flexGrow, 1)
        XCTAssertEqual(tree.children.first?.id, "a")
    }

    func testForwardCompatibleStylePayload() throws {
        let data = Data(#"""
        { "schemaVersion": \#(LayoutSchema.current), "root":
          { "id": "r", "content": "container",
            "style": { "gap": 8, "someV2Property": { "nested": 1 } } } }
        """#.utf8)
        let tree = try LayoutDecoding.decode(data)
        XCTAssertEqual(tree.style.gap, .points(8))
    }
}
