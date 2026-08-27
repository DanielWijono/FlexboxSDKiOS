//
//  MeasureModeTranslationTests.swift
//  FlexboxKitTests
//
//  The "don't treat every constraint as a max bound" contract (spec Artefak 3
//  §Inti). Pure — runs under `swift test` on macOS.
//

import XCTest
import FlexboxCore
@testable import FlexboxKit

final class MeasureModeTranslationTests: XCTestCase {

    // MARK: request()

    func testRequestExactlyAsksForTheExactExtent() {
        XCTAssertEqual(MeasureAxis.request(.exactly(120)), 120)
    }

    func testRequestAtMostAsksForTheUpperBound() {
        XCTAssertEqual(MeasureAxis.request(.atMost(200)), 200)
    }

    func testRequestUnconstrainedAsksForInfinity() {
        XCTAssertEqual(MeasureAxis.request(.unconstrained), .greatestFiniteMagnitude)
    }

    // MARK: resolve()

    func testResolveExactlyIgnoresFit() {
        XCTAssertEqual(MeasureAxis.resolve(fitted: 40, .exactly(120)), 120)
        XCTAssertEqual(MeasureAxis.resolve(fitted: 999, .exactly(120)), 120)
    }

    func testResolveAtMostClampsToBound() {
        XCTAssertEqual(MeasureAxis.resolve(fitted: 40, .atMost(120)), 40)
        XCTAssertEqual(MeasureAxis.resolve(fitted: 400, .atMost(120)), 120)
    }

    func testResolveUnconstrainedReturnsFitVerbatim() {
        XCTAssertEqual(MeasureAxis.resolve(fitted: 37.5, .unconstrained), 37.5)
    }

    // MARK: the 9 (width x height) combinations round-tripped through the pair

    func testAllNineCombinationsClampIndependentlyPerAxis() {
        let widths: [FlexMeasureConstraint] = [.exactly(100), .atMost(100), .unconstrained]
        let heights: [FlexMeasureConstraint] = [.exactly(50), .atMost(50), .unconstrained]
        let fitted = CGSize(width: 300, height: 20)

        for w in widths {
            for h in heights {
                let out = flexClamp(fitted: fitted, width: w, height: h)
                switch w {
                case .exactly(let v): XCTAssertEqual(out.width, v)
                case .atMost(let v): XCTAssertEqual(out.width, min(300, v))
                case .unconstrained: XCTAssertEqual(out.width, 300)
                }
                switch h {
                case .exactly(let v): XCTAssertEqual(out.height, v)
                case .atMost(let v): XCTAssertEqual(out.height, min(20, v))
                case .unconstrained: XCTAssertEqual(out.height, 20)
                }
            }
        }
    }

    func testMeasureRequestPairsBothAxes() {
        let req = flexMeasureRequest(width: .exactly(120), height: .unconstrained)
        XCTAssertEqual(req.width, 120)
        XCTAssertEqual(req.height, .greatestFiniteMagnitude)
    }
}
