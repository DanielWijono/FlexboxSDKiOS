//
//  FlexHostView+Traits.swift
//  FlexboxKit
//
//  Reacts to the trait changes that invalidate a Yoga pass (spec Artefak 3
//  §Inti "Perubahan trait", ARCHITECTURE.md):
//
//    • displayScale                 → `FlexConfig.pointScaleFactor` is baked in
//                                     and immutable in Core, so a change means a
//                                     fresh config and a rebound node tree.
//    • preferredContentSizeCategory → every cached text metric is stale: flush
//                                     the whole `MeasureCache`, mark every
//                                     measured leaf content-dirty, relayout.
//    • layoutDirection             → the pass reads direction fresh from the
//                                     view each time (`flexWritingDirection`);
//                                     the trait change only needs to schedule a
//                                     pass.
//
//  The isHidden → `display: none` mapping is reconciled every pass in
//  `runPass` via `flexReconcileHiddenDisplay`, not here — a subview's
//  `isHidden` toggle raises no trait change.
//
//  EXPERIMENTAL API (until Artefak 4).
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

extension FlexHostView {

    // MARK: - UIKit entry point

    /// iOS 15 deployment floor: `traitCollectionDidChange` is the only trait
    /// hook available below iOS 17 — `registerForTraitChanges` is 17+. The
    /// method is deprecated in the iOS 17 SDK; the deprecation on this override
    /// is declared to match, so the reference stays warning-free until the floor
    /// rises.
    @available(iOS, deprecated: 17.0, message: "Move to registerForTraitChanges when the deployment floor reaches iOS 17.")
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        flexApplyTraitChange(previous: previousTraitCollection, current: traitCollection)
    }

    // MARK: - Reactions (testable core)

    /// Responds to the three traits that affect a Yoga pass. Split from the
    /// UIKit hook so a test can drive it with two `UITraitCollection` values
    /// rather than a live trait environment.
    func flexApplyTraitChange(previous: UITraitCollection?, current: UITraitCollection) {
        if previous?.displayScale != current.displayScale {
            flexHandleDisplayScaleChange(newScale: current.displayScale)
        }
        if previous?.preferredContentSizeCategory != current.preferredContentSizeCategory {
            flexHandleContentSizeCategoryChange()
        }
        if previous?.layoutDirection != current.layoutDirection {
            setNeedsLayout()
            invalidateIntrinsicContentSize()
            renderObserver?.flexHostDidRebuildForTraitChange("layoutDirection")
        }
    }

    /// A new display scale changes `FlexConfig.pointScaleFactor`, which Core
    /// bakes in per tree and never mutates: swap in a fresh config, rebind the
    /// tree to it (that schedules a pass), and drop the now differently-rounded
    /// cached measurements.
    private func flexHandleDisplayScaleChange(newScale: CGFloat) {
        rebindToConfig(FlexConfigFactory.makeConfig(displayScale: newScale, errata: errata))
        currentCache().flushAll()
        invalidateIntrinsicContentSize()
        renderObserver?.flexHostDidRebuildForTraitChange("displayScale")
    }

    /// Dynamic Type moved: every cached text metric is stale. Empty the cache,
    /// mark every measured leaf content-dirty so Yoga re-measures it next pass,
    /// and schedule that pass.
    private func flexHandleContentSizeCategoryChange() {
        currentCache().flushAll()
        for leaf in currentRenderTree.measuredLeaves {
            leaf.node.markContentDirty()
        }
        setNeedsLayout()
        invalidateIntrinsicContentSize()
        renderObserver?.flexHostDidRebuildForTraitChange("preferredContentSizeCategory")
    }
}
#endif
