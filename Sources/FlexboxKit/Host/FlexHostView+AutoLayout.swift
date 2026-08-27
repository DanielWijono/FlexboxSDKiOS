//
//  FlexHostView+AutoLayout.swift
//  FlexboxKit
//
//  Auto Layout coexistence contract (spec Artefak 3 §"Dikembalikan karena
//  produksi", and the schedule-risk note: do this EARLY, it is the rollback
//  path from whole-app adoption).
//
//  NORMATIVE RULES for embedding a `FlexHostView` in an Auto Layout hierarchy:
//
//    1. Put constraints on the `FlexHostView` itself (pin it, or give it a size).
//       Never add an Auto Layout constraint to any view INSIDE it — the renderer
//       owns those frames and a constraint will fight it, producing confusing
//       drift rather than a crash.
//    2. The renderer sets `translatesAutoresizingMaskIntoConstraints = true` on
//       every managed subview it creates. Do not change this.
//    3. `FlexHostView.intrinsicContentSize` is valid after the first pass, so a
//       host placed in a `UIStackView` / constraint layout behaves as one
//       Auto Layout leaf. Give the host a width (or let its container define one)
//       and it reports the height its content needs.
//    4. The host does NOT touch its own `translatesAutoresizingMaskIntoConstraints`
//       — the app decides whether the host is frame-driven or constraint-driven.
//

#if canImport(UIKit)
import UIKit

extension FlexHostView {

    /// Call when the tree or a size-affecting trait changed, so a surrounding
    /// Auto Layout pass re-queries `intrinsicContentSize`.
    func flexInvalidateIntrinsicContentSize() {
        invalidateIntrinsicContentSize()
    }

    /// DEBUG / test helper: every managed subview must be autoresizing-driven
    /// and carry no constraints of its own. Returns the ids that violate the
    /// contract (empty when compliant).
    func flexAutoLayoutContractViolations() -> [String] {
        var offenders: [String] = []
        func walk(_ view: UIView) {
            for sub in view.subviews where sub.isIncludedInLayout && sub.flexNode != nil {
                if !sub.translatesAutoresizingMaskIntoConstraints || !sub.constraints.isEmpty {
                    offenders.append(currentRenderTree.idForNode(sub.flexNode!) ?? "<unknown>")
                }
                walk(sub)
            }
        }
        walk(currentRenderTree.rootView)
        return offenders
    }
}
#endif
