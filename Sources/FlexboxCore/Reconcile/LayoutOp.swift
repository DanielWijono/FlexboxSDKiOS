//
//  LayoutOp.swift
//  FlexboxCore
//
//  The minimal set of mutations that turn one `LayoutTree` into another. Emitted
//  by `Reconciler` as pure data; consumed by `OpApplier` against a live
//  `FlexNode` tree.
//

public enum LayoutOp: Equatable, Sendable {
    /// Insert a whole new subtree under an existing node.
    case insert(id: String, parentID: String, index: Int, subtree: LayoutTree)

    /// Remove a subtree. Only the top-most removed node of a branch is emitted.
    case remove(id: String)

    /// Re-position an existing node within `parentID`'s children, or move it to
    /// a different `parentID`. `index` is the destination index.
    case move(id: String, parentID: String, index: Int)

    /// Apply a style delta to an existing node.
    case updateStyle(id: String, delta: FlexStyleDelta)

    /// The node's `content` or `props` changed; the renderer must refresh it
    /// and, for a leaf, call `markContentDirty()`.
    case updateContent(id: String)

    /// The root identity itself changed — the caller must rebuild from scratch.
    case replaceRoot(subtree: LayoutTree)

    public var id: String {
        switch self {
        case .insert(let id, _, _, _),
             .remove(let id),
             .move(let id, _, _),
             .updateStyle(let id, _),
             .updateContent(let id):
            return id
        case .replaceRoot(let subtree):
            return subtree.id
        }
    }
}
