//
//  TreeFixtures.swift
//  FlexboxCoreTestSupport
//
//  Sample values and a deterministic random tree generator for round-trip and
//  reconciliation tests.
//

import Foundation
@testable import FlexboxCore

public enum TreeFixtures {

    /// A three-level card: header row (avatar / title / chevron) + body text.
    public static var card: LayoutTree {
        LayoutTree(
            id: "card",
            content: .container,
            style: FlexStyle(flexDirection: .column, padding: Edges(.points(16)), gap: .points(8)),
            children: [
                LayoutTree(
                    id: "header",
                    content: .container,
                    style: FlexStyle(flexDirection: .row, alignItems: .center, gap: .points(12)),
                    children: [
                        LayoutTree(id: "avatar", content: .image,
                                   style: FlexStyle(width: .points(40), height: .points(40))),
                        LayoutTree(id: "title", content: .text,
                                   style: FlexStyle(flexGrow: 1),
                                   props: ["text": .string("Hello")]),
                        LayoutTree(id: "chevron", content: .image,
                                   style: FlexStyle(width: .points(12), height: .points(12))),
                    ]
                ),
                LayoutTree(id: "body", content: .text,
                           style: FlexStyle(flexGrow: 1),
                           props: ["text": .string("Body copy.")]),
            ]
        )
    }

    /// A row 100pt wide with two `flexGrow: 1` children → 50 / 50.
    public static var evenSplitRow: LayoutTree {
        LayoutTree(
            id: "row",
            content: .container,
            style: FlexStyle(flexDirection: .row, width: .points(100), height: .points(20)),
            children: [
                LayoutTree(id: "left", content: .container, style: FlexStyle(flexGrow: 1)),
                LayoutTree(id: "right", content: .container, style: FlexStyle(flexGrow: 1)),
            ]
        )
    }

    /// Deterministic pseudo-random valid tree, for encode/decode fuzzing.
    public static func randomTree(seed: UInt64, maxDepth: Int = 4) -> LayoutTree {
        var rng = SplitMix64(seed: seed)
        var counter = 0
        func make(depth: Int) -> LayoutTree {
            counter += 1
            let id = "n\(counter)"
            let leaf = depth >= maxDepth || rng.next() % 3 == 0
            let style = FlexStyle(
                flexDirection: (rng.next() % 2 == 0) ? .row : .column,
                flexGrow: Double(rng.next() % 3),
                width: (rng.next() % 2 == 0) ? .points(Double(rng.next() % 200)) : nil,
                padding: (rng.next() % 2 == 0) ? Edges(.points(Double(rng.next() % 16))) : nil
            )
            if leaf {
                return LayoutTree(id: id, content: .text, style: style,
                                  props: ["text": .string("t\(counter)")])
            }
            let childCount = Int(rng.next() % 4)
            let children = (0 ..< childCount).map { _ in make(depth: depth + 1) }
            return LayoutTree(id: id, content: .container, style: style, children: children)
        }
        return make(depth: 1)
    }
}

/// Tiny deterministic RNG so fuzz tests are reproducible.
public struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
