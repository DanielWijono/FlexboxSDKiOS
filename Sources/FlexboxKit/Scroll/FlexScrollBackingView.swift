//
//  FlexScrollBackingView.swift
//  FlexboxKit
//
//  The `UIScrollView` that backs a `container` node with `overflow: scroll` when
//  the host's `scrollBehavior` is `.automatic`, the default (spec Artefak 3
//  §Inti "Scroll", SCHEMA.md §"FlexboxKit consumption").
//
//  The renderer is the sole authority on geometry here: it positions this view's
//  subviews from the Yoga pass and sets `contentSize` from the child extent
//  (`ScrollContentSizing`) after every pass. So this view opts out of the
//  implicit UIKit behaviours that would compete with that — automatic
//  content-inset adjustment above all, which would otherwise shift
//  `contentOffset` by the safe-area inset on the first layout inside a
//  scroll/nav context.
//
//  `contentOffset` is never written by the renderer: `GeometryApplier` preserves
//  `bounds.origin`, and on a scroll view `bounds.origin` *is* `contentOffset`.
//
//  EXPERIMENTAL API (until Artefak 4).
//

#if canImport(UIKit)
import UIKit

/// The scroll view a `FlexHostView` uses to back an `overflow: scroll` node.
public final class FlexScrollBackingView: UIScrollView {

    init() {
        super.init(frame: .zero)
        contentInsetAdjustmentBehavior = .never
        automaticallyAdjustsScrollIndicatorInsets = false
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("FlexScrollBackingView is created by the renderer, not from a nib")
    }
}
#endif
