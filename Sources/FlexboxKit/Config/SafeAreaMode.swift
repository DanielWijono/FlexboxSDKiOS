//
//  SafeAreaMode.swift
//  FlexboxKit
//
//  How a `FlexHostView` treats the device safe area, and how it backs scrollable
//  nodes. Both are host-level policy, not part of the payload.
//
//  Safe area is EXPLICIT opt-in (user decision, this artefact): the server that
//  sends the layout cannot see the safe area, so silently adding insets on top
//  of server-provided root padding is surprising. Default is `.ignore`.
//
//  `FlexHostView+SafeArea` applies the mode once per pass; `SafeAreaResolution`
//  is the pure resolution it uses, and documents why the insets are written as
//  the root's border.
//

/// A subset of a box's edges.
public struct FlexEdgeSet: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let top = FlexEdgeSet(rawValue: 1 << 0)
    public static let left = FlexEdgeSet(rawValue: 1 << 1)
    public static let bottom = FlexEdgeSet(rawValue: 1 << 2)
    public static let right = FlexEdgeSet(rawValue: 1 << 3)

    public static let horizontal: FlexEdgeSet = [.left, .right]
    public static let vertical: FlexEdgeSet = [.top, .bottom]
    public static let all: FlexEdgeSet = [.top, .left, .bottom, .right]
}

/// Whether — and on which edges — a `FlexHostView` folds `safeAreaInsets` into
/// the root node's box on every layout pass.
public enum FlexSafeAreaMode: Sendable, Equatable {
    /// Do nothing with the safe area. The default.
    case ignore
    /// Inset the root node's children by `safeAreaInsets` on the named edges,
    /// stacked on top of any padding or border the payload set on the root.
    ///
    /// The root view itself still fills the host, so a root background keeps
    /// running edge to edge; only its children move in.
    case padRoot(FlexEdgeSet)
}

/// Whether a `FlexHostView` honours `overflow: scroll` by backing that node with
/// a `UIScrollView`.
public enum FlexScrollBehavior: Sendable, Equatable {
    /// A node with `overflow: scroll` is backed by a scroll view and its
    /// `contentSize` tracks the laid-out content. The default.
    case automatic
    /// `overflow: scroll` is treated like `hidden`; no scroll view is created.
    case disabled
}
