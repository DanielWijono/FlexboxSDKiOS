# Architecture

This is the document that decides whether a contributor can change the code
without breaking an invariant. It grows one section per artefact; today it
covers Artefact 1 (engine bridge) and Artefact 2 (value layer + reconciliation).

## Module layout

```
CYoga            internal C shim — re-exports <yoga/Yoga.h> as one module
  └─ FlexboxCore   headless. Engine + Model + Schema + Reconcile. No UIKit.
       └─ FlexboxKit   UIKit renderer. Placeholder in this build (Artefact 3).
```

`FlexboxCore` must never `import UIKit`. CI greps for it.

## The C-ABI boundary

Exactly one file — `Engine/YogaInterop.swift` — may `import CYoga` or name a
`YG*` symbol. Everything else in `FlexboxCore` talks to Yoga through the
`yoga_*` free functions and the Swift-native types (`FlexLayoutResult`,
`FlexMeasureConstraint`, the `Y*` engine enums) defined there.

We bind Yoga's **C ABI** and do not enable C++ interop. `@_exported import` is
not used and no `YG*` type appears in any public signature. Yoga's SwiftPM
module is named `core`; the `CYoga` shim exists so the dependency graph imports
one clearly-named module instead.

Apps that also link another copy of Yoga (commonly via React Native on
CocoaPods) can hit symbol collisions. Full isolation needs XCFramework
distribution, which is out of scope while we are 0.x.

## Ownership contract (normative)

| Reference | Strength | Rationale |
|---|---|---|
| parent → child (`FlexNode.children`) | **strong** | the tree is usable headless, without views |
| child → parent (`FlexNode.parent`) | **weak** | reversing this creates a retain cycle |
| `FlexNode` → `YGNodeRef` (`handle`) | **exclusive, unique** | one Swift object owns one Yoga node |
| stored closures on a node (`onDirtied`, measure) | **must not capture** a node or view strongly | same cycle |

The `UIView` ↔ `FlexNode` association (view holds node strong via associated
object; node holds view weak) is **Artefact 3** and not present yet.

Failure mode to know about: if a subview is detached without its node being
removed from the parent node, the node stays reachable and leaks. The DEBUG
invariant `children.count == YGNodeGetChildCount(handle)` after every mutation
and every pass is the automatic check for it.

### Lifetime during calculation

`calculate(...)` borrows the tree. The caller must keep the root alive for the
whole call. Dropping the root mid-pass trades a leak for a use-after-free.

## Teardown order (do not reorder)

`FlexNode.deinit`, in order:

1. clear the measure function, the dirtied hook, and the Yoga context
2. detach any children still parented at the Yoga level (Swift releases the
   `children` array *after* this body runs, so their own `deinit` would
   otherwise read a freed owner pointer), then detach self from its own Yoga
   owner
3. `YGNodeFree(handle)` — this node only

Rules:

- `YGNodeFreeRecursive` is **forbidden**. CI greps for it.
- Reparenting calls `YGNodeRemoveChild` **before** re-inserting.
- The measure context is `Unmanaged.passUnretained(self).toOpaque()`.
  `passRetained` is **forbidden** — it leaks every node. CI greps for it.

## Concurrency

- No `@MainActor` anywhere in `FlexboxCore`.
- `FlexNode` is a `final class` with non-`Sendable` stored state, so Swift 6
  forbids sharing it across concurrency domains. The tree is thread-confined by
  construction; there is no runtime lock.
- A measure function that consults UIKit (`sizeThatFits`) must run on the main
  thread. `FlexboxCore` cannot enforce this; `FlexboxKit` will.

## Per-tree configuration

`FlexConfig` wraps one `YGConfig`; it is never a singleton. `pointScaleFactor`
must come from `traitCollection.displayScale` (not `UIScreen.main`) because
Split View / Slide Over / Stage Manager make it differ per scene and change at
runtime. `errata` is set explicitly (default `.none`).

## Invalidation

- Style setters do **not** call `YGNodeMarkDirty`; Yoga dirties itself on a
  style change.
- A leaf with a measure function must be told about external content changes via
  `markContentDirty()`.
- `YGNodeSetDirtiedFunc` is surfaced as `FlexNode.onDirtied`. It is
  edge-triggered (`setDirty` exits early if the state is unchanged; propagation
  stops at an already-dirty ancestor). Treat it as a complementary signal, not
  the only source of invalidation.

## Value layer

- Every `FlexStyle` field is `Optional`. `nil` == "unspecified" == absent from
  JSON == Yoga's own default. This is the schema's answer to `YGUndefined`
  (which is NaN and has no JSON form).
- `LayoutTree.id` is required and must be stable across versions of a tree.
  Without it, reconciliation degrades to a full rebuild.
- `props` is a closed `JSONValue` enum: it can carry data (a title string) but
  has no case that can carry code, an expression, or a navigation target. This
  is the App Store policy boundary in the type system.

## Reconciliation

`Reconciler.reconcile(from:to:)` is a **pure** function `(LayoutTree, LayoutTree)
-> [LayoutOp]`: no Yoga, no views, no traps. Children are matched by `id`, so a
reorder is a `move`, not remove + insert. A node that changes parent is
expressed as remove-under-old + insert-under-new — correct, though not the
theoretical minimum.

`FlexLayoutBinding` applies the ops to a live `FlexNode` tree and keeps an
`id → FlexNode` registry. Every id lookup that could miss is guarded: a bad op
sequence is a rejected no-op, never a trap.

Known limitation: a reconciliation delta that CLEARS `minWidth` / `maxWidth` /
`aspectRatio` cannot express Yoga's true "unset"; the applier writes an
approximate default. Avoid clearing those in payloads for now (see SCHEMA.md).

## Production diagnostics

`Diagnostics/FlexPrecondition.swift` + `Diagnostics/YogaAssertCatalog.swift`.

Every Yoga path that aborts the process on misuse is fronted by `flexRequire`:

- DEBUG: `assertionFailure` (trap) — unless `FlexPrecondition.assertsAreFatal`
  is set to `false`, which tests do to exercise the release path.
- RELEASE: emit `FlexObserver.flexDidRejectOperation`, return `false`, leave the
  tree in its last valid state.

Guarded paths (keep in sync with `YogaAssertCatalog.all`):

| Yoga call | Guard |
|---|---|
| `YGNodeInsertChild` | child has no parent and no Yoga owner; not self; owner has no measure function |
| `YGNodeSetMeasureFunc` | node has no children (leaf only) |
| `YGNodeMarkDirty` | node has a measure function |
| `YGNodeRemoveChild` | node is a current child |
| `YGNodeCalculateLayout` | depth ≤ maxDepth, node count ≤ maxNodes, dimensions finite (enforced by `LayoutValidation`) |

## Leak gates (CI, permanent)

- `LiveNodeCounter` (DEBUG) returns to baseline on every test teardown.
- `weak` references to nodes are `nil` after scope exit.
- `children.count == YGNodeGetChildCount` after every mutation / pass (DEBUG).
- `grep` gate: no `YGNodeFreeRecursive`, no `passRetained`, no `import UIKit` in
  `FlexboxCore`.
- `swift test --sanitize=address` blocks merge.
- Pending (needs a host app, Artefact 3/4): a 100× push/pop screen cycle under
  Instruments Allocations.
