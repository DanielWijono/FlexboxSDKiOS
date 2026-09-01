//
//  RenderItem.swift
//  FlexboxKit
//
//  One entry in `FlexRenderTree`'s `id → (node, view)` registry.
//
//  Ownership (spec Artefak 1 §"Kontrak kepemilikan", ARCHITECTURE.md):
//    • `node` is held STRONG here — the registry (together with each parent
//      node's own `children`) keeps the Yoga tree alive
//    • `view` is WEAK — the `UIView` hierarchy owns its views, and each view
//      owns its `FlexNode` strong via an associated object. The render layer
//      never owns a view.
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

struct RenderItem {
    let id: String
    let node: FlexNode
    weak var view: UIView?
    let content: ContentType

    /// `true` if this node was given a measure function (a `text` / `image` /
    /// `custom` leaf whose factory measures itself and that has no explicit
    /// width+height in its style).
    var isMeasuredLeaf: Bool

    /// The `display` value the tree's own style declared for this node, if any.
    /// `flexReconcileHiddenDisplay` restores this when the backing view is
    /// un-hidden (falling back to `.flex` when the style was silent).
    var styleDisplay: DisplayValue?
}
#endif
