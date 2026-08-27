//
//  YogaAssertCatalog.swift
//  FlexboxCore
//
//  The checklist form of spec Pillar §"Tidak boleh ada assert fatal di build
//  release" and Artefak 2 §"Diagnostik produksi". Each entry is a Yoga path
//  that aborts the process on misuse, the FlexboxCore operation that fronts it,
//  and the guard that makes it a rejected no-op in RELEASE instead of a crash.
//
//  This type is data, not behaviour: it exists so the guarantees are
//  enumerable (tests iterate it; ARCHITECTURE.md is generated from it) rather
//  than scattered as ad-hoc checks.
//

/// One guarded Yoga fatal-assert path.
public struct YogaAssertGuard: Sendable, Equatable {
    /// The Yoga C call that asserts on misuse.
    public let yogaCall: String
    /// The FlexboxCore operation that guards it (matches the `operation:`
    /// label passed to `flexRequire`).
    public let operation: String
    /// What the guard checks before allowing the operation.
    public let guardCondition: String
}

public enum YogaAssertCatalog {
    /// Every guarded path. Keep in sync with the `flexRequire` call sites.
    public static let all: [YogaAssertGuard] = [
        YogaAssertGuard(
            yogaCall: "YGNodeInsertChild",
            operation: "FlexNode.insertChild",
            guardCondition: "child.parent == nil && YGNodeGetOwner(child) == nil"
        ),
        YogaAssertGuard(
            yogaCall: "YGNodeInsertChild (self-parent)",
            operation: "FlexNode.insertChild",
            guardCondition: "child !== self"
        ),
        YogaAssertGuard(
            yogaCall: "YGNodeInsertChild (measured owner)",
            operation: "FlexNode.insertChild",
            guardCondition: "owner has no measure function"
        ),
        YogaAssertGuard(
            yogaCall: "YGNodeSetMeasureFunc",
            operation: "FlexNode.setMeasure",
            guardCondition: "children.isEmpty (measure only on a leaf)"
        ),
        YogaAssertGuard(
            yogaCall: "YGNodeMarkDirty",
            operation: "FlexNode.markContentDirty",
            guardCondition: "YGNodeHasMeasureFunc(node) == true"
        ),
        YogaAssertGuard(
            yogaCall: "YGNodeRemoveChild",
            operation: "FlexNode.removeChild",
            guardCondition: "node is a current child of this node"
        ),
        YogaAssertGuard(
            yogaCall: "reconcile → OpApplier",
            operation: "OpApplier.apply",
            guardCondition: "referenced ids exist in the working tree"
        ),
        YogaAssertGuard(
            yogaCall: "YGNodeCalculateLayout",
            operation: "LayoutValidation.validate",
            guardCondition: "depth ≤ maxDepth && nodeCount ≤ maxNodes && dimensions finite"
        ),
    ]
}
