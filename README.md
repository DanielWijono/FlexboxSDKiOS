# Flexbox SDK for iOS

Layout as data. `FlexStyle` and `LayoutTree` are plain `Equatable` / `Codable` /
`Sendable` values; [Yoga](https://github.com/facebook/yoga) executes them; UIKit
is the render target. Because the description is an inert value and not a chain of
calls that mutate views, it can be serialized from a server, diffed so only what
changed touches C++, and unit-tested without a simulator.

> **New here? Start with the [UIKit developer guide](GUIDE.md).** It shows how to
> build a screen step by step — parent views, stack views, scroll views, labels,
> images, text fields and buttons — with a UIKit → Flexbox cheat sheet and a list
> of common mistakes.

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

## Rendering with UIKit

`FlexHostView` is a plain `UIView` that renders a `LayoutTree` as real views
(`.text` → `UILabel`, `.image` → `UIImageView`, `.container` → `UIView`).
Updating it diffs the old and new trees and only touches what changed.

```swift
import FlexboxKit

let host = FlexHostView(tree: card)
host.safeAreaMode = .padRoot(.all)   // keep content out of the notch / home indicator
view.addSubview(host)

host.update(to: nextVersionOfCard)   // minimal view mutations, identity preserved
```

In lists, use the self-sizing cells and let UIKit ask them for their height:

```swift
tableView.register(FlexTableViewCell.self, forCellReuseIdentifier: "row")
tableView.rowHeight = UITableView.automaticDimension

let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath) as! FlexTableViewCell
cell.host.update(to: rowLayout(for: item))
```

`FlexCollectionViewCell` does the same for collection views. A container with
`overflow: scroll` is backed by a `UIScrollView`. Built-in text follows Dynamic
Type, and layouts mirror under right-to-left languages.

[`Examples/FlexDemo`](Examples/FlexDemo) is a small app (a self-sizing list that
pushes a scrolling detail screen) for trying the renderer on a simulator or device.

For every building block (stacks, scroll views, text fields, buttons, background
colours…) see the [guide](GUIDE.md).

## Status

**0.x — pre-release.** Breaking changes are expected until 1.0. This build ships:

| Module | Contents |
|---|---|
| `FlexboxCore` | Yoga engine bridge with a strict memory-ownership contract; the `LayoutTree` / `FlexStyle` value model; JSON schema + version negotiation + validation; the reconciliation diff engine. Headless — does not link UIKit. |
| `FlexboxKit` | UIKit renderer: `FlexHostView`, text and image measurement, diff-driven view updates, scroll views, safe-area modes, Auto Layout coexistence, `FlexTableViewCell` / `FlexCollectionViewCell`, right-to-left and Dynamic Type. Its public API is marked experimental. |

Known gaps:

- An explicit `font` prop creates a fixed-size font, so that text does not
  scale with Dynamic Type. Leave `font` unset to get the scaling body style.
- There is no end-to-end sample that fetches a screen's JSON from a server and
  renders it; the pieces (`LayoutResolver` + `FlexHostView`) exist separately.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the design.

## Requirements

- iOS 15.0+
- Xcode 16+, Swift 6 language mode
- [Yoga](https://github.com/facebook/yoga) 3.x (resolved via SwiftPM)

## Installation

```swift
.package(url: "https://github.com/DanielWijono/FlexboxSDKiOS.git", "0.1.0" ..< "1.0.0")
```

## Documentation

- [GUIDE.md](GUIDE.md) — how to build screens: UIKit → Flexbox cheat sheet, stacks, scroll views, text fields, buttons, cells, common mistakes
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
