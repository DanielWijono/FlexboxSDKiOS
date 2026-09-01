//
//  FlexHostView+SelfSizing.swift
//  FlexboxKit
//
//  The self-size entry points (spec Artefak 3 §Inti "titik masuk ukuran-diri"):
//  `sizeThatFits`, `intrinsicContentSize`, `systemLayoutSizeFitting`. Each runs
//  its OWN Yoga pass that only measures — geometry is never applied — so it is
//  fully independent of `layoutSubviews`.
//
//  These are what let a `FlexHostView` be a `UITableViewCell` / `UICollectionViewCell`
//  content view, sit in a `UIStackView`, or back a host-written
//  `UIViewRepresentable`.
//
//  Recursion (`intrinsicContentSize → calculate → measure → sizeThatFits →
//  intrinsicContentSize`) is broken by `MeasureReentrancyGuard`: while any pass
//  is running, a nested self-size query returns `lastSelfSizedResult` instead of
//  starting a second pass.
//
//  Per-axis constraint handling (the "don't treat every bound as a max" rule
//  from `MeasureModeTranslation`, applied at the host level):
//    • a finite, positive offer  → a real bound; the answer is `min(natural, offer)`
//    • 0 / negative / non-finite / `.greatestFiniteMagnitude` → unconstrained;
//      the answer is the natural extent Yoga produced
//
//  EXPERIMENTAL API (until Artefak 4).
//

#if canImport(UIKit)
import UIKit

extension FlexHostView {

    // MARK: - UIView overrides

    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        flexSelfSizedPass(width: size.width, height: size.height)
    }

    public override var intrinsicContentSize: CGSize {
        // If the app has given the host a width (a constraint, or an explicit
        // frame), measure the content height at that width and let Auto Layout
        // keep driving the width. Otherwise report both extents.
        let hasWidth = bounds.width > 0
        let fitted = flexSelfSizedPass(
            width: hasWidth ? bounds.width : .greatestFiniteMagnitude,
            height: .greatestFiniteMagnitude
        )
        return CGSize(
            width: hasWidth ? UIView.noIntrinsicMetric : fitted.width,
            height: fitted.height
        )
    }

    public override func systemLayoutSizeFitting(_ targetSize: CGSize) -> CGSize {
        flexSelfSizedPass(width: targetSize.width, height: targetSize.height)
    }

    public override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        // A `.required` fitting priority pins that axis to the target; anything
        // less lets the content pick its natural extent.
        let pinH = horizontalFittingPriority == .required
        let pinV = verticalFittingPriority == .required
        let fitted = flexSelfSizedPass(
            width: pinH ? targetSize.width : .greatestFiniteMagnitude,
            height: pinV ? targetSize.height : .greatestFiniteMagnitude
        )
        return CGSize(
            width: pinH ? targetSize.width : fitted.width,
            height: pinV ? targetSize.height : fitted.height
        )
    }

    // MARK: - Core

    /// Runs one measure-only Yoga pass for the given per-axis offers and returns
    /// the resolved size. While another pass is active this is a no-op that
    /// returns the last size produced — the reentrancy terminator.
    func flexSelfSizedPass(width: CGFloat, height: CGFloat) -> CGSize {
        // `enter()` always bumps the depth counter — pair it with `leave()`
        // unconditionally. A re-entrant query returns the last result instead of
        // starting a nested pass (the recursion terminator).
        let outermost = reentrancy.enter()
        defer { reentrancy.leave() }
        guard outermost else { return lastSelfSizedResult }

        let fitted = runPass(
            availableWidth: FlexHostView.flexConstrainAxis(width),
            availableHeight: FlexHostView.flexConstrainAxis(height),
            applyGeometry: false
        )
        let resolved = CGSize(
            width: FlexHostView.flexResolveAxis(fitted: fitted.width, offered: width),
            height: FlexHostView.flexResolveAxis(fitted: fitted.height, offered: height)
        )
        lastSelfSizedResult = resolved
        return resolved
    }

    /// The value to hand `FlexNode.calculate` on one axis: the offer itself when
    /// it is a real bound, else `NaN` ("unconstrained — natural extent").
    static func flexConstrainAxis(_ offered: CGFloat) -> CGFloat {
        flexIsRealBound(offered) ? offered : .nan
    }

    /// The extent to report back, given what the content fitted into: clamp to a
    /// real bound (AtMost), otherwise return the natural fit verbatim.
    static func flexResolveAxis(fitted: CGFloat, offered: CGFloat) -> CGFloat {
        flexIsRealBound(offered) ? Swift.min(fitted, offered) : fitted
    }

    private static func flexIsRealBound(_ v: CGFloat) -> Bool {
        v.isFinite && v > 0 && v < .greatestFiniteMagnitude
    }
}
#endif
