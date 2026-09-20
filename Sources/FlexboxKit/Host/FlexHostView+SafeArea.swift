//
//  FlexHostView+SafeArea.swift
//  FlexboxKit
//
//  Applies `FlexSafeAreaMode` to the live root node, once per pass (spec
//  Artefak 3 §"Dikembalikan karena produksi" — Safe area).
//
//  The decision the spec demands is EXPLICIT opt-in: a host does nothing with
//  the safe area until the app sets `safeAreaMode = .padRoot(...)`. A layout
//  payload cannot see the device it will render on, so silently insetting
//  server-authored content would be a surprise the sender cannot predict.
//
//  Mechanism and edge precedence: see `SafeAreaResolution`. The short version is
//  that the insets are written as root *border*, which Yoga adds to the root's
//  padding, so the payload's own root spacing survives untouched.
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

extension FlexHostView {

    // MARK: - UIKit entry point

    /// The safe area moved (rotation, Split View, a keyboard, a changed
    /// `additionalSafeAreaInsets`). Only a host that opted in cares.
    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        guard safeAreaMode != .ignore else { return }
        setNeedsLayout()
        invalidateIntrinsicContentSize()
    }

    // MARK: - Pass-time application

    /// The insets this host folds into its root, after the mode's edge filter.
    /// `.zero` when the mode is `.ignore`.
    var flexEffectiveSafeAreaInsets: SafeAreaResolution.Insets {
        guard case .padRoot(let edges) = safeAreaMode else { return .zero }
        let insets = safeAreaInsets
        return SafeAreaResolution.Insets(
            top: Double(insets.top),
            left: Double(insets.left),
            bottom: Double(insets.bottom),
            right: Double(insets.right)
        ).keeping(edges)
    }

    /// Writes `payload root border + safe area insets` to the root node, so the
    /// pass that follows lays children out inside the safe area.
    ///
    /// Recomputed from the payload every pass rather than accumulated, so the
    /// insets can shrink back to zero and repeated passes never drift. While the
    /// mode is `.ignore` and nothing was ever written, the root node is not
    /// touched at all.
    func flexApplySafeAreaToRoot(direction: FlexWritingDirection) {
        let insets = flexEffectiveSafeAreaInsets
        guard !insets.isZero || hasWrittenSafeAreaBorder else { return }

        let resolved = SafeAreaResolution.resolve(
            payloadBorder: currentRenderTree.tree.style.border,
            insets: insets,
            direction: direction
        )
        currentRenderTree.root.apply(FlexStyle(border: resolved))
        hasWrittenSafeAreaBorder = !insets.isZero
    }
}
#endif
