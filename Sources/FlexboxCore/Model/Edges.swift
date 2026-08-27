//
//  Edges.swift
//  FlexboxCore
//
//  Per-edge values for margin / padding / inset (each an optional `FlexDimension`)
//  and per-edge widths for border (each an optional point length).
//
//  JSON accepts either a shorthand scalar that means "all edges":
//      "padding": 16
//  or an object with any subset of edge keys:
//      "padding": { "top": 8, "horizontal": 16 }
//
//  Resolution order for a physical edge, most specific wins:
//      top    → vertical   → all
//      bottom → vertical   → all
//      left   → horizontal → all
//      right  → horizontal → all
//  `start` / `end` are direction-relative and applied on top of the above.
//

public struct Edges: Equatable, Sendable {
    public var top: FlexDimension?
    public var left: FlexDimension?
    public var bottom: FlexDimension?
    public var right: FlexDimension?
    public var start: FlexDimension?
    public var end: FlexDimension?
    public var horizontal: FlexDimension?
    public var vertical: FlexDimension?
    public var all: FlexDimension?

    public init(
        top: FlexDimension? = nil, left: FlexDimension? = nil,
        bottom: FlexDimension? = nil, right: FlexDimension? = nil,
        start: FlexDimension? = nil, end: FlexDimension? = nil,
        horizontal: FlexDimension? = nil, vertical: FlexDimension? = nil,
        all: FlexDimension? = nil
    ) {
        self.top = top; self.left = left; self.bottom = bottom; self.right = right
        self.start = start; self.end = end
        self.horizontal = horizontal; self.vertical = vertical; self.all = all
    }

    /// Shorthand: the same value on every edge.
    public init(_ all: FlexDimension) { self.init(all: all) }

    var isEmpty: Bool {
        top == nil && left == nil && bottom == nil && right == nil
            && start == nil && end == nil
            && horizontal == nil && vertical == nil && all == nil
    }

    var isAllOnly: Bool {
        all != nil && top == nil && left == nil && bottom == nil && right == nil
            && start == nil && end == nil && horizontal == nil && vertical == nil
    }
}

extension Edges: Codable {
    private enum CodingKeys: String, CodingKey {
        case top, left, bottom, right, start, end, horizontal, vertical, all
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let scalar = try? single.decode(FlexDimension.self) {
            self.init(all: scalar)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            top: try c.decodeIfPresent(FlexDimension.self, forKey: .top),
            left: try c.decodeIfPresent(FlexDimension.self, forKey: .left),
            bottom: try c.decodeIfPresent(FlexDimension.self, forKey: .bottom),
            right: try c.decodeIfPresent(FlexDimension.self, forKey: .right),
            start: try c.decodeIfPresent(FlexDimension.self, forKey: .start),
            end: try c.decodeIfPresent(FlexDimension.self, forKey: .end),
            horizontal: try c.decodeIfPresent(FlexDimension.self, forKey: .horizontal),
            vertical: try c.decodeIfPresent(FlexDimension.self, forKey: .vertical),
            all: try c.decodeIfPresent(FlexDimension.self, forKey: .all)
        )
    }

    public func encode(to encoder: Encoder) throws {
        if isAllOnly, let all {
            var single = encoder.singleValueContainer()
            try single.encode(all)
            return
        }
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(top, forKey: .top)
        try c.encodeIfPresent(left, forKey: .left)
        try c.encodeIfPresent(bottom, forKey: .bottom)
        try c.encodeIfPresent(right, forKey: .right)
        try c.encodeIfPresent(start, forKey: .start)
        try c.encodeIfPresent(end, forKey: .end)
        try c.encodeIfPresent(horizontal, forKey: .horizontal)
        try c.encodeIfPresent(vertical, forKey: .vertical)
        try c.encodeIfPresent(all, forKey: .all)
    }
}

/// Border widths only. Points, no percent / auto.
public struct EdgeWidths: Equatable, Sendable, Codable {
    public var top: Double?
    public var left: Double?
    public var bottom: Double?
    public var right: Double?
    public var start: Double?
    public var end: Double?
    public var horizontal: Double?
    public var vertical: Double?
    public var all: Double?

    public init(
        top: Double? = nil, left: Double? = nil,
        bottom: Double? = nil, right: Double? = nil,
        start: Double? = nil, end: Double? = nil,
        horizontal: Double? = nil, vertical: Double? = nil,
        all: Double? = nil
    ) {
        self.top = top; self.left = left; self.bottom = bottom; self.right = right
        self.start = start; self.end = end
        self.horizontal = horizontal; self.vertical = vertical; self.all = all
    }

    public init(_ all: Double) { self.init(all: all) }

    private enum CodingKeys: String, CodingKey {
        case top, left, bottom, right, start, end, horizontal, vertical, all
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let scalar = try? single.decode(Double.self) {
            self.init(all: scalar)
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            top: try c.decodeIfPresent(Double.self, forKey: .top),
            left: try c.decodeIfPresent(Double.self, forKey: .left),
            bottom: try c.decodeIfPresent(Double.self, forKey: .bottom),
            right: try c.decodeIfPresent(Double.self, forKey: .right),
            start: try c.decodeIfPresent(Double.self, forKey: .start),
            end: try c.decodeIfPresent(Double.self, forKey: .end),
            horizontal: try c.decodeIfPresent(Double.self, forKey: .horizontal),
            vertical: try c.decodeIfPresent(Double.self, forKey: .vertical),
            all: try c.decodeIfPresent(Double.self, forKey: .all)
        )
    }
}
