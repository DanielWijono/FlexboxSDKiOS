//
//  FlexViewFactory.swift
//  FlexboxKit
//
//  The extension point for contributors and host apps (spec Artefak 3 §Inti
//  "Registry view"): a factory turns one `LayoutTree` node into a `UIView`,
//  refreshes that view when the node's content/props change, and — for a leaf —
//  reports its natural size under Yoga's per-axis constraints.
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

/// Creates and maintains the `UIView` for one content type.
///
/// Main-actor isolated: every method touches UIKit and the renderer is
/// main-thread confined (spec Artefak 1 §Konkurensi).
@MainActor
public protocol FlexViewFactory {

    /// Makes a fresh view for `tree`. Called once per node when it enters the
    /// tree. Do not read layout geometry here — the node has not been measured.
    func makeView(for tree: LayoutTree) -> UIView

    /// Re-applies `tree`'s content and `props` to an existing `view` (the node
    /// kept its `id` and `content` kind but its `props` changed).
    func update(_ view: UIView, for tree: LayoutTree)

    /// The view's natural size under the given per-axis constraints, or `nil` if
    /// this content does not measure itself (a plain container).
    ///
    /// Runs on the main thread. Translate all three constraint cases — do not
    /// treat `exactly` / `atMost` / `unconstrained` alike (spec Artefak 3 §Inti).
    func measure(
        _ view: UIView,
        width: FlexMeasureConstraint,
        height: FlexMeasureConstraint
    ) -> FlexSize?
}

public extension FlexViewFactory {
    func update(_ view: UIView, for tree: LayoutTree) {}
    func measure(
        _ view: UIView,
        width: FlexMeasureConstraint,
        height: FlexMeasureConstraint
    ) -> FlexSize? { nil }
}

/// Wraps a plain `make` closure as a factory (no update, no measure). Backs
/// `FlexViewRegistry.register(_:make:)`.
struct ClosureViewFactory: FlexViewFactory {
    let make: (LayoutTree) -> UIView
    func makeView(for tree: LayoutTree) -> UIView { make(tree) }
}
#endif
