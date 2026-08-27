//
//  LayoutTree.swift
//  FlexboxCore
//
//  A whole screen's layout as one nested value (spec Artefak 2 §"Model data").
//  `Equatable`, `Codable`, `Sendable`.
//
//  `id` is REQUIRED and must be stable across versions of a tree. Without a
//  stable key, reconciliation degrades to a full rebuild and half the thesis is
//  lost (spec: "Identitas stabil wajib").
//

public struct LayoutTree: Equatable, Sendable {
    /// Stable identity. Unique within a tree.
    public var id: String

    /// What this node renders.
    public var content: ContentType

    /// Layout rules. Absent in JSON ⇒ `.empty`.
    public var style: FlexStyle

    /// Child subtrees. Absent in JSON ⇒ `[]`. A leaf `content` must have none.
    public var children: [LayoutTree]

    /// Leaf parameters (text, image name, custom-view props). Data only.
    public var props: PropBag?

    public init(
        id: String,
        content: ContentType,
        style: FlexStyle = .empty,
        children: [LayoutTree] = [],
        props: PropBag? = nil
    ) {
        self.id = id
        self.content = content
        self.style = style
        self.children = children
        self.props = props
    }

    /// Every id in the subtree, pre-order.
    public var allIDs: [String] {
        [id] + children.flatMap(\.allIDs)
    }

    /// Depth of the subtree (a single node is depth 1).
    public var depth: Int {
        1 + (children.map(\.depth).max() ?? 0)
    }

    /// Node count of the subtree, inclusive.
    public var nodeCount: Int {
        1 + children.reduce(0) { $0 + $1.nodeCount }
    }
}

extension LayoutTree: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, content, style, children, props
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.content = try c.decode(ContentType.self, forKey: .content)
        self.style = try c.decodeIfPresent(FlexStyle.self, forKey: .style) ?? .empty
        self.children = try c.decodeIfPresent([LayoutTree].self, forKey: .children) ?? []
        self.props = try c.decodeIfPresent(PropBag.self, forKey: .props)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(content, forKey: .content)
        if !style.isEmpty {
            try c.encode(style, forKey: .style)
        }
        if !children.isEmpty {
            try c.encode(children, forKey: .children)
        }
        try c.encodeIfPresent(props, forKey: .props)
    }
}
