import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

/// Exercises each guarded Yoga fatal-assert path in its RELEASE behaviour
/// (reject + telemetry + tree stays valid) by disabling the DEBUG trap.
final class DiagnosticsTests: XCTestCase {

    private final class Recorder: FlexObserver, @unchecked Sendable {
        var rejections: [(op: String, reason: String)] = []
        func flexDidRejectOperation(_ operation: String, reason: String) {
            rejections.append((operation, reason))
        }
    }

    private var recorder: Recorder!

    override func setUp() {
        super.setUp()
        recorder = Recorder()
        FlexTelemetry.observer = recorder
        FlexPrecondition.assertsAreFatal = false
        assertLiveNodeCountReturnsToBaseline()
    }

    override func tearDown() {
        FlexPrecondition.assertsAreFatal = true
        FlexTelemetry.observer = nil
        recorder = nil
        super.tearDown()
    }

    func testInsertingAnOwnedChildIsRejected() {
        let a = FlexNode(); let b = FlexNode(); let child = FlexNode()
        a.appendChild(child)
        b.appendChild(child)
        XCTAssertTrue(child.parent === a)
        XCTAssertEqual(b.childCount, 0)
        XCTAssertTrue(recorder.rejections.contains { $0.op == "FlexNode.insertChild" })
    }

    func testMeasureOnNonLeafIsRejected() {
        let parent = FlexNode()
        parent.appendChild(FlexNode())
        parent.setMeasure { _, _ in .zero }
        XCTAssertNil(parent.measureFunction)
        XCTAssertTrue(recorder.rejections.contains { $0.op == "FlexNode.setMeasure" })
    }

    func testAddingChildToMeasuredNodeIsRejected() {
        let leaf = FlexNode()
        leaf.setMeasure { _, _ in FlexSize(width: 10, height: 10) }
        leaf.appendChild(FlexNode())
        XCTAssertEqual(leaf.childCount, 0)
        XCTAssertTrue(recorder.rejections.contains { $0.op == "FlexNode.insertChild" })
    }

    func testMarkContentDirtyWithoutMeasureIsRejected() {
        let node = FlexNode()
        node.markContentDirty()
        XCTAssertTrue(recorder.rejections.contains { $0.op == "FlexNode.markContentDirty" })
    }

    func testRemovingANonChildIsRejected() {
        let root = FlexNode(); let stranger = FlexNode()
        root.removeChild(stranger)
        XCTAssertTrue(recorder.rejections.contains { $0.op == "FlexNode.removeChild" })
    }

    func testTreeStaysCalculableAfterRejectedOperations() {
        let root = FlexNode()
        root.apply(FlexStyle(width: .points(50), height: .points(50)))
        root.markContentDirty()                 // rejected
        root.removeChild(FlexNode())            // rejected
        root.calculate(availableWidth: 50, availableHeight: 50)
        XCTAssertEqual(root.layout.width, 50)
    }
}
