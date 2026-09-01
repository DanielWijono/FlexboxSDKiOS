//
//  LayoutParticipation.swift
//  FlexboxKit
//
//  Which subviews take part in the flex layout, and the writing direction fed
//  to a layout pass.
//
//    • `isIncludedInLayout` (default `true`) — set `false` on a subview the
//      renderer should leave completely alone: no `FlexNode` is created for it,
//      its frame is untouched, and it is excluded from the DEBUG
//      "node child count == participating subview count" invariant.
//    • `isHidden == true` maps to an effective `display: none` on that node, so
//      siblings reflow (spec Artefak 3 §"Dikembalikan karena produksi").
//    • the pass direction comes from `effectiveUserInterfaceLayoutDirection`
//      (RTL support), forwarded to `FlexNode.calculate(direction:)`.
//
//  `isIncludedInLayout` storage plus the pass-time helpers the host calls:
//  `flexReconcileHiddenDisplay` (isHidden → display) and `flexWritingDirection`
//  (RTL). See `FlexHostView+Traits` for the trait-change reactions.
//

#if canImport(UIKit)
import UIKit
import ObjectiveC.runtime
import FlexboxCore

private enum FlexParticipationKeys {
    nonisolated(unsafe) static var includedInLayout: UInt8 = 0
}

public extension UIView {

    /// Whether the renderer manages this subview. Default `true`. Set `false`
    /// for a view you position yourself inside a flex container.
    nonisolated var isIncludedInLayout: Bool {
        get {
            (objc_getAssociatedObject(
                self, &FlexParticipationKeys.includedInLayout
            ) as? Bool) ?? true
        }
        set {
            objc_setAssociatedObject(
                self, &FlexParticipationKeys.includedInLayout, newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

/// The writing direction for a layout pass rooted at `view`.
@MainActor
func flexWritingDirection(for view: UIView) -> FlexWritingDirection {
    switch view.effectiveUserInterfaceLayoutDirection {
    case .rightToLeft: return .rtl
    default: return .ltr
    }
}

/// Reconciles each managed node's `display` to its backing view's `isHidden`:
/// a hidden view collapses to `display: none` (siblings reflow), an un-hidden
/// one is restored to the `display` its tree style declared (`.flex` when the
/// style was silent).
///
/// Idempotent — Yoga only marks itself dirty on an actual change — so the host
/// runs this at the top of every pass, catching an `isHidden` toggle that came
/// with no tree update.
@MainActor
func flexReconcileHiddenDisplay(in renderTree: FlexRenderTree) {
    for item in renderTree.allItems {
        guard let view = item.view else { continue }
        let target: DisplayValue = view.isHidden ? DisplayValue.none : (item.styleDisplay ?? .flex)
        item.node.apply(FlexStyle(display: target))
    }
}
#endif
