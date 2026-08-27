//
//  FlexboxKit.swift
//
//  The UIKit renderer for FlexboxCore (spec Artefak 3). Turns a `LayoutTree`
//  value into a live `UIView` hierarchy: `FlexHostView` owns the tree, runs a
//  Yoga pass from its `layoutSubviews`, and applies the result to `bounds.size`
//  and `center`.
//
//  EXPERIMENTAL: every public symbol in FlexboxKit is provisional until the
//  dogfood app (Artefak 4) has exercised it. Expect source-breaking change on
//  any 0.x bump. FlexboxCore's value model and schema are the stable surface.
//

/// Umbrella namespace and version marker for the renderer.
///
/// - Note: FlexboxKit's public API is experimental until Artefak 4. See the
///   file header and `ARCHITECTURE.md` §"Artefact 3 — UIKit renderer".
public enum FlexboxKit {
    /// Marks the renderer's API as not yet frozen. Purely informational.
    public static let isExperimental = true
}
