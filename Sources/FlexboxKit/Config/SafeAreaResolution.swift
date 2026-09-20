//
//  SafeAreaResolution.swift
//  FlexboxKit
//
//  Folding `safeAreaInsets` into the root node's box (spec Artefak 3
//  §"Dikembalikan karena produksi" — Safe area).
//
//  WHY BORDER AND NOT PADDING
//
//  The API promise is that the safe area *stacks on top of* whatever spacing the
//  payload already put on its root. Yoga's box model insets the content box by
//  `border + padding`, and the two are independent, so writing the insets as
//  border is literally that sum — including when the payload's root padding is a
//  percentage, which no points-based merge could express. The root view still
//  fills the host's whole `bounds`, so a root background colour keeps running
//  under the status bar and home indicator; only the children move in.
//
//  The cost is that the root's *border* is now host-owned: the resolved value
//  written each pass is `payload root border + inset`, recomputed from the
//  payload every time, so the payload's own border is preserved and never
//  accumulates.
//
//  EDGE PRECEDENCE
//
//  Yoga resolves one physical edge as `start`/`end` (direction-relative) >
//  physical > `horizontal`/`vertical` > `all` (see `Style::computeLeftEdge`).
//  `resolve` mirrors that order to read the payload's value, then writes the
//  answer to every key that could win — physical *and* `start`/`end`, mapped for
//  the direction in force — so the result is the same whichever branch Yoga
//  takes.
//
//  Pure and UIKit-free: it runs under `swift test` on macOS.
//

import FlexboxCore

enum SafeAreaResolution {

    /// Physical inset values in points, in the order Yoga thinks of them.
    struct Insets: Equatable {
        var top: Double
        var left: Double
        var bottom: Double
        var right: Double

        static let zero = Insets(top: 0, left: 0, bottom: 0, right: 0)

        /// `self` with every edge outside `edges` zeroed.
        func keeping(_ edges: FlexEdgeSet) -> Insets {
            Insets(
                top: edges.contains(.top) ? top : 0,
                left: edges.contains(.left) ? left : 0,
                bottom: edges.contains(.bottom) ? bottom : 0,
                right: edges.contains(.right) ? right : 0
            )
        }

        var isZero: Bool { self == .zero }
    }

    /// The border to write on the root node: the payload's own root border,
    /// resolved per physical edge, plus `insets`.
    ///
    /// - Parameters:
    ///   - payloadBorder: the root's `border` as the payload declared it.
    ///   - insets: the safe area insets, already filtered to the opted-in edges.
    ///   - direction: the writing direction of the pass — it decides which
    ///     physical edge `start` / `end` refer to.
    static func resolve(
        payloadBorder: EdgeWidths?,
        insets: Insets,
        direction: FlexWritingDirection
    ) -> EdgeWidths {
        let base = payloadBorder ?? EdgeWidths()
        let isRTL = direction == .rtl

        // Yoga's precedence, per physical edge.
        let leading = isRTL ? base.end : base.start
        let trailing = isRTL ? base.start : base.end
        let top = base.top ?? base.vertical ?? base.all ?? 0
        let bottom = base.bottom ?? base.vertical ?? base.all ?? 0
        let left = leading ?? base.left ?? base.horizontal ?? base.all ?? 0
        let right = trailing ?? base.right ?? base.horizontal ?? base.all ?? 0

        let resolvedTop = top + insets.top
        let resolvedBottom = bottom + insets.bottom
        let resolvedLeft = left + insets.left
        let resolvedRight = right + insets.right

        // Write every key that Yoga might consult, so no branch of its
        // precedence chain can reach a stale payload value.
        return EdgeWidths(
            top: resolvedTop,
            left: resolvedLeft,
            bottom: resolvedBottom,
            right: resolvedRight,
            start: isRTL ? resolvedRight : resolvedLeft,
            end: isRTL ? resolvedLeft : resolvedRight,
            horizontal: nil,
            vertical: nil,
            all: nil
        )
    }
}
