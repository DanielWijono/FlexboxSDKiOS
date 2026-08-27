//
//  GeometryApplier.swift
//  FlexboxKit
//
//  Writes one node's `FlexLayoutResult` onto its backing `UIView`, following the
//  spec's geometry rules (Artefak 3 §Inti "Geometri"):
//    • apply to `bounds.size` and `center`, never `frame` — so a `transform` set
//      by the app is not clobbered
//    • preserve the existing `bounds.origin` — overwriting it resets
//      `UIScrollView.contentOffset`
//    • do NOT round here — Yoga already rounded to `config.pointScaleFactor`
//

#if canImport(UIKit)
import UIKit
import FlexboxCore

@MainActor
enum GeometryApplier {

    /// Positions and sizes `view` from `layout`, which is relative to the parent
    /// node's origin (i.e. the superview's coordinate space).
    static func apply(_ layout: FlexLayoutResult, to view: UIView) {
        let size = flexBoundsSize(width: layout.width, height: layout.height)
        view.bounds = CGRect(origin: view.bounds.origin, size: size)
        view.center = flexCenter(
            left: layout.left,
            top: layout.top,
            width: layout.width,
            height: layout.height,
            anchorPoint: view.layer.anchorPoint
        )
    }
}
#endif
