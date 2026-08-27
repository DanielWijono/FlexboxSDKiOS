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
//  Full participation/hidden observation lands with the trait-handling step;
//  this file is the storage + the pure helpers.
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
#endif
