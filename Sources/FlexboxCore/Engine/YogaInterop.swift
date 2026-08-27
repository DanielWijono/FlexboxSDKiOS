//
//  YogaInterop.swift
//  FlexboxCore
//
//  The ONLY file in the package that may `import CYoga` or name a `YG*` symbol.
//  Everything Yoga-shaped is re-surfaced here behind Swift-native types, so no
//  `YG*` type appears in any other file — public or internal.
//
//  Keeping the C-ABI boundary in one file makes the memory-ownership rules
//  auditable and confines a future move to an isolated XCFramework to one place.
//  See ARCHITECTURE.md.
//

import CYoga

/// Opaque handle to a live Yoga node. Callers never hold a raw pointer;
/// `FlexNode` owns exactly one of these, uniquely.
typealias YogaNodeHandle = OpaquePointer

/// Opaque handle to a per-tree Yoga configuration.
typealias YogaConfigHandle = OpaquePointer

// MARK: - Callback protocols
//
// The C measure/dirtied hooks are context-free function pointers. The
// trampolines below recover the owning object from `YGNodeGetContext` and
// forward through these protocols, so YogaInterop need not know about `FlexNode`.

protocol YogaMeasuring: AnyObject {
    func yogaMeasure(width: FlexMeasureConstraint, height: FlexMeasureConstraint) -> FlexSize
}

protocol YogaDirtyObserving: AnyObject {
    func yogaDidDirty()
}

// MARK: - Config lifecycle

@inline(__always)
func yoga_configNew() -> YogaConfigHandle {
    YGConfigNew()
}

@inline(__always)
func yoga_configFree(_ config: YogaConfigHandle) {
    YGConfigFree(config)
}

@inline(__always)
func yoga_configSetPointScaleFactor(_ config: YogaConfigHandle, _ factor: Double) {
    YGConfigSetPointScaleFactor(config, Float(factor))
}

@inline(__always)
func yoga_configPointScaleFactor(_ config: YogaConfigHandle) -> Double {
    Double(YGConfigGetPointScaleFactor(config))
}

@inline(__always)
func yoga_configSetErrata(_ config: YogaConfigHandle, _ errata: FlexErrata) {
    switch errata {
    case .none: YGConfigSetErrata(config, YGErrata.none)
    case .classic: YGConfigSetErrata(config, YGErrata.classic)
    case .all: YGConfigSetErrata(config, YGErrata.all)
    }
}

// MARK: - Node lifecycle

@inline(__always)
func yoga_nodeNew(config: YogaConfigHandle) -> YogaNodeHandle {
    // Never returns null in practice; Yoga aborts the process on OOM.
    YGNodeNewWithConfig(config)
}

@inline(__always)
func yoga_nodeFree(_ node: YogaNodeHandle) {
    YGNodeFree(node)
}

@inline(__always)
func yoga_nodeReset(_ node: YogaNodeHandle) {
    YGNodeReset(node)
}

// MARK: - Tree structure

@inline(__always)
func yoga_insertChild(_ child: YogaNodeHandle, into parent: YogaNodeHandle, at index: Int) {
    YGNodeInsertChild(parent, child, index)
}

@inline(__always)
func yoga_removeChild(_ child: YogaNodeHandle, from parent: YogaNodeHandle) {
    YGNodeRemoveChild(parent, child)
}

@inline(__always)
func yoga_childCount(_ node: YogaNodeHandle) -> Int {
    YGNodeGetChildCount(node)
}

@inline(__always)
func yoga_owner(of node: YogaNodeHandle) -> YogaNodeHandle? {
    YGNodeGetOwner(node)
}

// MARK: - Dirty / measure state

@inline(__always)
func yoga_isDirty(_ node: YogaNodeHandle) -> Bool {
    YGNodeIsDirty(node)
}

@inline(__always)
func yoga_markDirty(_ node: YogaNodeHandle) {
    YGNodeMarkDirty(node)
}

@inline(__always)
func yoga_hasMeasureFunc(_ node: YogaNodeHandle) -> Bool {
    YGNodeHasMeasureFunc(node)
}

// MARK: - Context + callbacks

@inline(__always)
func yoga_setContext(_ node: YogaNodeHandle, _ context: UnsafeMutableRawPointer?) {
    YGNodeSetContext(node, context)
}

@inline(__always)
func yoga_clearContext(_ node: YogaNodeHandle) {
    YGNodeSetContext(node, nil)
}

private let measureTrampoline: YGMeasureFunc = { nodePtr, width, widthMode, height, heightMode in
    guard let nodePtr, let ctx = YGNodeGetContext(nodePtr) else {
        return YGSize(width: 0, height: 0)
    }
    let owner = Unmanaged<AnyObject>.fromOpaque(ctx).takeUnretainedValue()
    guard let measuring = owner as? YogaMeasuring else {
        return YGSize(width: 0, height: 0)
    }
    let size = measuring.yogaMeasure(
        width: mapConstraint(value: width, mode: widthMode),
        height: mapConstraint(value: height, mode: heightMode)
    )
    return YGSize(width: Float(size.width), height: Float(size.height))
}

private let dirtiedTrampoline: YGDirtiedFunc = { nodePtr in
    guard let nodePtr, let ctx = YGNodeGetContext(nodePtr) else { return }
    let owner = Unmanaged<AnyObject>.fromOpaque(ctx).takeUnretainedValue()
    (owner as? YogaDirtyObserving)?.yogaDidDirty()
}

private func mapConstraint(value: Float, mode: YGMeasureMode) -> FlexMeasureConstraint {
    switch mode {
    case .exactly: return .exactly(Double(value))
    case .atMost: return .atMost(Double(value))
    default: return .unconstrained
    }
}

@inline(__always)
func yoga_setMeasureEnabled(_ node: YogaNodeHandle, _ enabled: Bool) {
    YGNodeSetMeasureFunc(node, enabled ? measureTrampoline : nil)
}

@inline(__always)
func yoga_setDirtiedEnabled(_ node: YogaNodeHandle, _ enabled: Bool) {
    YGNodeSetDirtiedFunc(node, enabled ? dirtiedTrampoline : nil)
}

// MARK: - Calculation

@inline(__always)
func yoga_calculate(
    _ node: YogaNodeHandle,
    availableWidth: Double,
    availableHeight: Double,
    direction: FlexWritingDirection
) {
    let ygDirection: YGDirection
    switch direction {
    case .inherit: ygDirection = .inherit
    case .ltr: ygDirection = .LTR
    case .rtl: ygDirection = .RTL
    }
    YGNodeCalculateLayout(node, Float(availableWidth), Float(availableHeight), ygDirection)
}

// MARK: - Layout results

@inline(__always)
func yoga_layout(_ node: YogaNodeHandle) -> FlexLayoutResult {
    FlexLayoutResult(
        left: Double(YGNodeLayoutGetLeft(node)),
        top: Double(YGNodeLayoutGetTop(node)),
        width: Double(YGNodeLayoutGetWidth(node)),
        height: Double(YGNodeLayoutGetHeight(node))
    )
}

// MARK: - Style: engine-level enums (map 1:1 to Yoga, no YG* leakage)

enum YEdge { case left, top, right, bottom, start, end, horizontal, vertical, all }
enum YGutter { case column, row, all }
enum YFlexDirection { case row, rowReverse, column, columnReverse }
enum YJustify { case flexStart, center, flexEnd, spaceBetween, spaceAround, spaceEvenly }
enum YAlign { case auto, flexStart, center, flexEnd, stretch, baseline, spaceBetween, spaceAround, spaceEvenly }
enum YWrap { case noWrap, wrap, wrapReverse }
enum YOverflow { case visible, hidden, scroll }
enum YDisplay { case flex, none, contents }
enum YPositionType { case staticPosition, relative, absolute }
enum YBoxSizing { case borderBox, contentBox }

private func ygEdge(_ e: YEdge) -> YGEdge {
    switch e {
    case .left: return .left
    case .top: return .top
    case .right: return .right
    case .bottom: return .bottom
    case .start: return .start
    case .end: return .end
    case .horizontal: return .horizontal
    case .vertical: return .vertical
    case .all: return .all
    }
}

private func ygGutter(_ g: YGutter) -> YGGutter {
    switch g {
    case .column: return .column
    case .row: return .row
    case .all: return .all
    }
}

// MARK: - Style: enum setters

func yoga_setFlexDirection(_ node: YogaNodeHandle, _ v: YFlexDirection) {
    let m: YGFlexDirection
    switch v {
    case .row: m = .row
    case .rowReverse: m = .rowReverse
    case .column: m = .column
    case .columnReverse: m = .columnReverse
    }
    YGNodeStyleSetFlexDirection(node, m)
}

func yoga_setJustifyContent(_ node: YogaNodeHandle, _ v: YJustify) {
    let m: YGJustify
    switch v {
    case .flexStart: m = .flexStart
    case .center: m = .center
    case .flexEnd: m = .flexEnd
    case .spaceBetween: m = .spaceBetween
    case .spaceAround: m = .spaceAround
    case .spaceEvenly: m = .spaceEvenly
    }
    YGNodeStyleSetJustifyContent(node, m)
}

private func ygAlign(_ v: YAlign) -> YGAlign {
    switch v {
    case .auto: return .auto
    case .flexStart: return .flexStart
    case .center: return .center
    case .flexEnd: return .flexEnd
    case .stretch: return .stretch
    case .baseline: return .baseline
    case .spaceBetween: return .spaceBetween
    case .spaceAround: return .spaceAround
    case .spaceEvenly: return .spaceEvenly
    }
}

func yoga_setAlignItems(_ node: YogaNodeHandle, _ v: YAlign) { YGNodeStyleSetAlignItems(node, ygAlign(v)) }
func yoga_setAlignSelf(_ node: YogaNodeHandle, _ v: YAlign) { YGNodeStyleSetAlignSelf(node, ygAlign(v)) }
func yoga_setAlignContent(_ node: YogaNodeHandle, _ v: YAlign) { YGNodeStyleSetAlignContent(node, ygAlign(v)) }

func yoga_setFlexWrap(_ node: YogaNodeHandle, _ v: YWrap) {
    let m: YGWrap
    switch v {
    case .noWrap: m = .noWrap
    case .wrap: m = .wrap
    case .wrapReverse: m = .wrapReverse
    }
    YGNodeStyleSetFlexWrap(node, m)
}

func yoga_setOverflow(_ node: YogaNodeHandle, _ v: YOverflow) {
    let m: YGOverflow
    switch v {
    case .visible: m = .visible
    case .hidden: m = .hidden
    case .scroll: m = .scroll
    }
    YGNodeStyleSetOverflow(node, m)
}

func yoga_setDisplay(_ node: YogaNodeHandle, _ v: YDisplay) {
    let m: YGDisplay
    switch v {
    case .flex: m = .flex
    case .none: m = YGDisplay.none
    case .contents: m = .contents
    }
    YGNodeStyleSetDisplay(node, m)
}

func yoga_setPositionType(_ node: YogaNodeHandle, _ v: YPositionType) {
    let m: YGPositionType
    switch v {
    case .staticPosition: m = .static
    case .relative: m = .relative
    case .absolute: m = .absolute
    }
    YGNodeStyleSetPositionType(node, m)
}

func yoga_setBoxSizing(_ node: YogaNodeHandle, _ v: YBoxSizing) {
    let m: YGBoxSizing
    switch v {
    case .borderBox: m = .borderBox
    case .contentBox: m = .contentBox
    }
    YGNodeStyleSetBoxSizing(node, m)
}

// MARK: - Style: scalar setters

func yoga_setFlexGrow(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetFlexGrow(node, Float(v)) }
func yoga_setFlexShrink(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetFlexShrink(node, Float(v)) }
func yoga_setAspectRatio(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetAspectRatio(node, Float(v)) }

func yoga_setFlexBasisPoint(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetFlexBasis(node, Float(v)) }
func yoga_setFlexBasisPercent(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetFlexBasisPercent(node, Float(v)) }
func yoga_setFlexBasisAuto(_ node: YogaNodeHandle) { YGNodeStyleSetFlexBasisAuto(node) }

func yoga_setWidthPoint(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetWidth(node, Float(v)) }
func yoga_setWidthPercent(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetWidthPercent(node, Float(v)) }
func yoga_setWidthAuto(_ node: YogaNodeHandle) { YGNodeStyleSetWidthAuto(node) }

func yoga_setHeightPoint(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetHeight(node, Float(v)) }
func yoga_setHeightPercent(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetHeightPercent(node, Float(v)) }
func yoga_setHeightAuto(_ node: YogaNodeHandle) { YGNodeStyleSetHeightAuto(node) }

func yoga_setMinWidthPoint(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetMinWidth(node, Float(v)) }
func yoga_setMinWidthPercent(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetMinWidthPercent(node, Float(v)) }
func yoga_setMinHeightPoint(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetMinHeight(node, Float(v)) }
func yoga_setMinHeightPercent(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetMinHeightPercent(node, Float(v)) }

func yoga_setMaxWidthPoint(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetMaxWidth(node, Float(v)) }
func yoga_setMaxWidthPercent(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetMaxWidthPercent(node, Float(v)) }
func yoga_setMaxHeightPoint(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetMaxHeight(node, Float(v)) }
func yoga_setMaxHeightPercent(_ node: YogaNodeHandle, _ v: Double) { YGNodeStyleSetMaxHeightPercent(node, Float(v)) }

// MARK: - Style: edge setters

func yoga_setMarginPoint(_ node: YogaNodeHandle, _ edge: YEdge, _ v: Double) { YGNodeStyleSetMargin(node, ygEdge(edge), Float(v)) }
func yoga_setMarginPercent(_ node: YogaNodeHandle, _ edge: YEdge, _ v: Double) { YGNodeStyleSetMarginPercent(node, ygEdge(edge), Float(v)) }
func yoga_setMarginAuto(_ node: YogaNodeHandle, _ edge: YEdge) { YGNodeStyleSetMarginAuto(node, ygEdge(edge)) }

func yoga_setPaddingPoint(_ node: YogaNodeHandle, _ edge: YEdge, _ v: Double) { YGNodeStyleSetPadding(node, ygEdge(edge), Float(v)) }
func yoga_setPaddingPercent(_ node: YogaNodeHandle, _ edge: YEdge, _ v: Double) { YGNodeStyleSetPaddingPercent(node, ygEdge(edge), Float(v)) }

func yoga_setBorderPoint(_ node: YogaNodeHandle, _ edge: YEdge, _ v: Double) { YGNodeStyleSetBorder(node, ygEdge(edge), Float(v)) }

func yoga_setPositionPoint(_ node: YogaNodeHandle, _ edge: YEdge, _ v: Double) { YGNodeStyleSetPosition(node, ygEdge(edge), Float(v)) }
func yoga_setPositionPercent(_ node: YogaNodeHandle, _ edge: YEdge, _ v: Double) { YGNodeStyleSetPositionPercent(node, ygEdge(edge), Float(v)) }

func yoga_setGapPoint(_ node: YogaNodeHandle, _ gutter: YGutter, _ v: Double) { YGNodeStyleSetGap(node, ygGutter(gutter), Float(v)) }
func yoga_setGapPercent(_ node: YogaNodeHandle, _ gutter: YGutter, _ v: Double) { YGNodeStyleSetGapPercent(node, ygGutter(gutter), Float(v)) }
