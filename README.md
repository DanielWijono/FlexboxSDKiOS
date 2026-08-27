# Flexbox SDK for iOS

Layout as data. `FlexStyle` and `LayoutTree` are plain `Equatable` / `Codable` /
`Sendable` values; [Yoga](https://github.com/facebook/yoga) executes them; UIKit
is the render target. Because the description is an inert value and not a chain of
calls that mutate views, it can be serialized from a server, diffed so only what
changed touches C++, and unit-tested without a simulator.

```swift
import FlexboxCore

let card = LayoutTree(
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
            ]
        ),
        LayoutTree(id: "body", content: .text, style: FlexStyle(flexGrow: 1)),
    ]
)

// Bind the value to a live Yoga tree and lay it out headless.
let binding = FlexLayoutBinding(tree: card)
binding.root.calculate(availableWidth: 320, availableHeight: .nan)
let titleFrame = binding.node(id: "title")?.layout   // left / top / width / height

// A new version of the layout produces the minimal set of mutations.
binding.update(to: nextVersionOfCard)
```

The same `LayoutTree` is JSON:

```json
{
  "schemaVersion": 1,
  "root": {
    "id": "card",
    "content": "container",
    "style": { "flexDirection": "column", "padding": 16, "gap": 8 },
    "children": [ ... ]
  }
}
```

Load it with a bundled fallback so a bad payload never blanks a screen:

```swift
let resolution = LayoutResolver.resolve(remote: dataFromServer, fallback: bundledCard)
let binding = FlexLayoutBinding(tree: resolution.tree)
```

## Status

**0.x — pre-release.** Breaking changes are expected until 1.0. This build ships:

| Module | Contents |
|---|---|
| `FlexboxCore` | Yoga engine bridge with a strict memory-ownership contract; the `LayoutTree` / `FlexStyle` value model; JSON schema + version negotiation + validation; the reconciliation diff engine. Headless — does not link UIKit. |
| `FlexboxKit` | Placeholder. The UIKit renderer (measure functions, `layoutSubviews` integration, scroll content sizing, Auto Layout coexistence) is not implemented yet. |

So today you can build and diff and test layouts as values. Rendering them into
`UIView`s, and driving a real screen from server JSON end to end, are the next
milestones — see [ARCHITECTURE.md](ARCHITECTURE.md).

## Requirements

- iOS 15.0+
- Xcode 16+, Swift 6 language mode
- [Yoga](https://github.com/facebook/yoga) 3.x (resolved via SwiftPM)

## Installation

```swift
.package(url: "https://github.com/OWNER/flexbox-sdk-ios.git", "0.1.0" ..< "1.0.0")
```

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) — ownership contract, teardown order, concurrency model, diagnostics checklist
- [SCHEMA.md](SCHEMA.md) — the JSON contract a backend sends
- [CONTRIBUTING.md](CONTRIBUTING.md) — how to run the gates, where contributions are welcome

## Maintenance

This project is maintained voluntarily with limited capacity. Issues are likely
to arrive faster than they can be resolved; well-scoped pull requests for the
areas flagged in `CONTRIBUTING.md` are the fastest path to a change landing.

## License

Apache-2.0 with DCO sign-off (see [CONTRIBUTING.md](CONTRIBUTING.md)). Bundles
Yoga, which is MIT-licensed — see [NOTICE](NOTICE).
