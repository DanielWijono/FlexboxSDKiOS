//
//  LayoutValidation.swift
//  FlexboxCore
//
//  Structural checks that a well-formed-JSON payload still has to pass before
//  it can drive a tree (spec Artefak 2 §"Rekonsiliasi" relies on these
//  invariants; Pillar §"Validasi payload" requires the limits).
//

/// Why a `LayoutTree` was rejected.
public enum LayoutValidationError: Error, Equatable, Sendable {
    case duplicateID(String)
    case emptyID
    case idTooLong(String, length: Int, limit: Int)
    case depthExceeded(Int, limit: Int)
    case nodeCountExceeded(Int, limit: Int)
    case propScalarsExceeded(Int, limit: Int)
    case leafHasChildren(id: String, content: String)
    case negativeGrow(id: String, value: Double)
    case negativeShrink(id: String, value: Double)
    case nonPositiveAspectRatio(id: String, value: Double)
}

public enum LayoutValidation {

    /// Validates `tree` against `limits`. Throws the first violation found.
    public static func validate(
        _ tree: LayoutTree,
        limits: LayoutLimits = .default
    ) throws {
        if tree.depth > limits.maxDepth {
            throw LayoutValidationError.depthExceeded(tree.depth, limit: limits.maxDepth)
        }
        let count = tree.nodeCount
        if count > limits.maxNodes {
            throw LayoutValidationError.nodeCountExceeded(count, limit: limits.maxNodes)
        }

        var seen = Set<String>()
        var propScalars = 0
        try walk(tree, limits: limits, seen: &seen, propScalars: &propScalars)

        if propScalars > limits.maxPropScalars {
            throw LayoutValidationError.propScalarsExceeded(propScalars, limit: limits.maxPropScalars)
        }
    }

    private static func walk(
        _ node: LayoutTree,
        limits: LayoutLimits,
        seen: inout Set<String>,
        propScalars: inout Int
    ) throws {
        if node.id.isEmpty {
            throw LayoutValidationError.emptyID
        }
        if node.id.count > limits.maxIDLength {
            throw LayoutValidationError.idTooLong(node.id, length: node.id.count, limit: limits.maxIDLength)
        }
        guard seen.insert(node.id).inserted else {
            throw LayoutValidationError.duplicateID(node.id)
        }

        if node.content.isLeaf, !node.children.isEmpty {
            throw LayoutValidationError.leafHasChildren(
                id: node.id,
                content: describe(node.content)
            )
        }

        if let grow = node.style.flexGrow, grow < 0 {
            throw LayoutValidationError.negativeGrow(id: node.id, value: grow)
        }
        if let shrink = node.style.flexShrink, shrink < 0 {
            throw LayoutValidationError.negativeShrink(id: node.id, value: shrink)
        }
        if let ratio = node.style.aspectRatio, ratio <= 0 {
            throw LayoutValidationError.nonPositiveAspectRatio(id: node.id, value: ratio)
        }

        for value in node.props?.values ?? Dictionary<String, JSONValue>().values {
            propScalars += value.scalarCount
        }

        for child in node.children {
            try walk(child, limits: limits, seen: &seen, propScalars: &propScalars)
        }
    }

    private static func describe(_ content: ContentType) -> String {
        switch content {
        case .container: return "container"
        case .text: return "text"
        case .image: return "image"
        case .custom(let name): return "custom(\(name))"
        }
    }
}
