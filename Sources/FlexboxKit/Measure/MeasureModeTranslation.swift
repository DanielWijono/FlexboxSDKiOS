//
//  MeasureModeTranslation.swift
//  FlexboxKit
//
//  Translates Yoga's per-axis measure constraints to and from a `sizeThatFits`
//  request. Pure — no UIKit — so `swift test` covers it on macOS.
//
//  The bug this file exists to prevent (spec Artefak 3 §Inti): treating
//  `.exactly`, `.atMost` and `.unconstrained` as if they were all "at most".
//    • .exactly(v)     → ask for v; the answer IS v, regardless of fit
//    • .atMost(v)      → ask for v; the answer is min(fit, v)
//    • .unconstrained  → ask for infinity; the answer is the natural fit
//

import CoreGraphics
import FlexboxCore

enum MeasureAxis {

    /// The extent to pass to `sizeThatFits` on one axis.
    static func request(_ constraint: FlexMeasureConstraint) -> CGFloat {
        switch constraint {
        case .exactly(let v), .atMost(let v): return CGFloat(v)
        case .unconstrained: return .greatestFiniteMagnitude
        }
    }

    /// The extent to report back to Yoga, given what the view fitted into.
    static func resolve(fitted: CGFloat, _ constraint: FlexMeasureConstraint) -> CGFloat {
        switch constraint {
        case .exactly(let v): return CGFloat(v)
        case .atMost(let v): return Swift.min(fitted, CGFloat(v))
        case .unconstrained: return fitted
        }
    }
}

/// The `CGSize` to hand a `sizeThatFits(_:)` call for the given constraints.
func flexMeasureRequest(
    width: FlexMeasureConstraint,
    height: FlexMeasureConstraint
) -> CGSize {
    CGSize(width: MeasureAxis.request(width), height: MeasureAxis.request(height))
}

/// The `FlexSize` to return to Yoga, given the size a view fitted into and the
/// original constraints.
func flexClamp(
    fitted: CGSize,
    width: FlexMeasureConstraint,
    height: FlexMeasureConstraint
) -> FlexSize {
    FlexSize(
        width: Double(MeasureAxis.resolve(fitted: fitted.width, width)),
        height: Double(MeasureAxis.resolve(fitted: fitted.height, height))
    )
}
