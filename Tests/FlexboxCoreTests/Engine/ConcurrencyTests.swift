import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

final class ConcurrencyTests: XCTestCase {

    /// The core is not `@MainActor`: a headless tree calculates on a background
    /// queue without any main-thread assertion (spec §Konkurensi).
    func testHeadlessCalculationOffMainThread() {
        let expectation = expectation(description: "calculated off main")
        let width = 120.0

        DispatchQueue.global().async {
            XCTAssertFalse(Thread.isMainThread)
            var result = 0.0
            do {
                let root = FlexNode(config: FlexConfig(pointScaleFactor: 1))
                root.apply(FlexStyle(flexDirection: .row, width: .points(width), height: .points(10)))
                let a = FlexNode(); a.apply(FlexStyle(flexGrow: 1))
                let b = FlexNode(); b.apply(FlexStyle(flexGrow: 1))
                root.appendChild(a); root.appendChild(b)
                root.calculate(availableWidth: width, availableHeight: 10)
                result = a.layout.width
            }
            XCTAssertEqual(result, width / 2)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    /// `FlexNode` is a non-Sendable final class — Swift 6 forbids sharing it
    /// across concurrency domains. This compiles only because each closure
    /// builds and confines its own tree, tearing it down before signalling.
    func testEachThreadConfinesItsOwnTree() {
        #if DEBUG
        let baseline = LiveNodeCounter.current
        #endif
        let group = DispatchGroup()
        for _ in 0 ..< 8 {
            group.enter()
            DispatchQueue.global().async {
                do {
                    let root = FlexNode()
                    root.appendChild(FlexNode())
                    root.calculate(availableWidth: 10, availableHeight: 10)
                }
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)

        #if DEBUG
        // Every per-thread tree is scoped, so the census must settle back.
        let settled = poll(timeout: 2) { LiveNodeCounter.current == baseline }
        XCTAssertTrue(settled, "live node count \(LiveNodeCounter.current) != baseline \(baseline)")
        #endif
    }

    private func poll(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return condition()
    }
}
