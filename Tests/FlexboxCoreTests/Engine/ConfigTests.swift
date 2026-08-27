import XCTest
@testable import FlexboxCore
import FlexboxCoreTestSupport

final class ConfigTests: XCTestCase {

    override func setUp() {
        super.setUp()
        assertLiveNodeCountReturnsToBaseline()
    }

    func testPointScaleFactorRoundsIndependentlyPerTree() {
        let whole = FlexConfig(pointScaleFactor: 1)
        let half = FlexConfig(pointScaleFactor: 2)

        func widthUnderGrow(_ config: FlexConfig) -> Double {
            let root = FlexNode(config: config)
            root.apply(FlexStyle(flexDirection: .row, width: .points(101), height: .points(10)))
            let a = FlexNode(config: config); a.apply(FlexStyle(flexGrow: 1))
            let b = FlexNode(config: config); b.apply(FlexStyle(flexGrow: 1))
            root.appendChild(a); root.appendChild(b)
            root.calculate(availableWidth: 101, availableHeight: 10)
            return a.layout.width
        }

        // 101 / 2 = 50.5. Scale 1 must land on a whole point; scale 2 keeps the
        // half point. The two configs must not round identically.
        let w1 = widthUnderGrow(whole)
        let w2 = widthUnderGrow(half)
        XCTAssertEqual(w1, w1.rounded(), "scale 1 should round to whole points, got \(w1)")
        XCTAssertEqual(w2, 50.5, "scale 2 should preserve the half point, got \(w2)")
        XCTAssertNotEqual(w1, w2)
    }

    func testErrataLevelIsRecorded() {
        XCTAssertEqual(FlexConfig(errata: .none).errata, .none)
        XCTAssertEqual(FlexConfig(errata: .classic).errata, .classic)
        XCTAssertEqual(FlexConfig(errata: .all).errata, .all)
    }

    func testConfigFreesWithoutLeak() {
        weak var weakConfig: FlexConfig?
        autoreleasepool {
            let config = FlexConfig()
            weakConfig = config
            _ = FlexNode(config: config)
        }
        XCTAssertNil(weakConfig)
    }
}
