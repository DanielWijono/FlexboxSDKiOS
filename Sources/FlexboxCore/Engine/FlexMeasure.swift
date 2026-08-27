//
//  FlexMeasure.swift
//  FlexboxCore
//
//  Leaf measurement. A leaf node (text, image, custom view) tells Yoga its
//  natural size under the constraints Yoga supplies on each axis.
//
//  Contract (spec Artefak 1 §Konkurensi): a measure function that consults
//  UIKit (`sizeThatFits`) must run on the main thread. FlexboxCore does not
//  enforce that — it cannot see UIKit — but the renderer in FlexboxKit will,
//  and it is documented in ARCHITECTURE.md.
//
//  The stored closure MUST NOT strongly capture its `FlexNode` or any view;
//  doing so reintroduces the retain cycle the ownership contract removes.
//

/// Measures a leaf under per-axis constraints. Pure with respect to the tree —
/// it may read external content (a string, an image) but must not mutate nodes.
public typealias FlexMeasureFunction = @Sendable (
    _ width: FlexMeasureConstraint,
    _ height: FlexMeasureConstraint
) -> FlexSize
