# Flexbox SDK — UIKit developer guide

This guide is for iOS developers who know UIKit and want to build screens with
this SDK. It maps the UIKit things you already know (`UIView`, `UIStackView`,
`UIScrollView`, `UILabel`, `UITextField`, `UIButton`) to what you write here.

> **The one idea to hold on to:** you don't create views or constraints. You
> describe the screen as a tree of `LayoutTree` values, hand it to a
> `FlexHostView`, and the SDK creates the UIKit views and positions them.

- [1. The mental model](#1-the-mental-model)
- [2. Putting a layout on screen](#2-putting-a-layout-on-screen)
- [3. UIKit → Flexbox cheat sheet](#3-uikit--flexbox-cheat-sheet)
- [4. Parent view / container (`UIView`)](#4-parent-view--container-uiview)
- [5. Stack views (`UIStackView`)](#5-stack-views-uistackview)
- [6. Sizes, spacing and pushing things apart](#6-sizes-spacing-and-pushing-things-apart)
- [7. Text (`UILabel`)](#7-text-uilabel)
- [8. Images (`UIImageView`)](#8-images-uiimageview)
- [9. Scroll view (`UIScrollView`)](#9-scroll-view-uiscrollview)
- [10. Your own views: `UITextField`, `UIButton`, anything](#10-your-own-views-uitextfield-uibutton-anything)
- [11. Background colour and rounded corners](#11-background-colour-and-rounded-corners)
- [12. Safe area](#12-safe-area)
- [13. Changing the screen later](#13-changing-the-screen-later)
- [14. Table and collection view cells](#14-table-and-collection-view-cells)
- [15. The same layout as JSON](#15-the-same-layout-as-json)
- [16. Common mistakes](#16-common-mistakes)
- [17. Full example: a sign-up form](#17-full-example-a-sign-up-form)

---

## 1. The mental model

Every node in the tree has four things:

```swift
LayoutTree(
    id: "title",                  // unique in the tree; used to track the view across updates
    content: .text,               // WHAT view it is: .container, .text, .image, .custom("…")
    style: FlexStyle(...),        // HOW it is laid out: size, spacing, direction…
    props: ["text": .string("Hi")] // WHAT it shows: text, image name, colour…
)
```

| `content` | UIKit view created | Can have children? |
|---|---|---|
| `.container` | `UIView` (or `UIScrollView` with `overflow: .scroll`) | Yes |
| `.text` | `UILabel` | No |
| `.image` | `UIImageView` | No |
| `.custom("name")` | whatever you register (e.g. `UITextField`, `UIButton`) | No |

Only `.container` nodes have children. Text, images and custom views are leaves.

The arguments always go in this order: `id`, `content`, `style`, `children`, `props`.
All but `id` and `content` are optional.

Imports: `FlexboxCore` has the tree types (`LayoutTree`, `FlexStyle`…);
`FlexboxKit` has the UIKit side (`FlexHostView`, cells, registry).

```swift
import UIKit
import FlexboxCore
import FlexboxKit
```

## 2. Putting a layout on screen

The easiest way: make a `FlexHostView` the view controller's `view`.

```swift
final class ProfileViewController: UIViewController {
    override func loadView() {
        let host = FlexHostView(tree: Self.layout)
        host.backgroundColor = .systemBackground
        host.safeAreaMode = .padRoot(.all)   // keep content clear of notch / home indicator
        view = host
    }

    static let layout = LayoutTree(
        id: "root", content: .container,
        style: FlexStyle(flexDirection: .column, padding: Edges(.points(20)), gap: .points(8)),
        children: [
            LayoutTree(id: "name", content: .text, props: ["text": .string("Jane Appleseed")]),
            LayoutTree(id: "role", content: .text, props: ["text": .string("iOS developer")]),
        ]
    )
}
```

`FlexHostView` is an ordinary `UIView`, so you can also add it as a subview and
position it with Auto Layout or frames like any other view. The root node always
fills the host.

## 3. UIKit → Flexbox cheat sheet

| You want (UIKit) | You write (Flexbox) |
|---|---|
| A plain parent `UIView` | `content: .container` |
| Vertical `UIStackView` | `.container` + `flexDirection: .column` |
| Horizontal `UIStackView` | `.container` + `flexDirection: .row` |
| `stackView.spacing = 12` | `gap: .points(12)` |
| `layoutMargins` / insets inside a view | `padding: Edges(.points(16))` |
| Space outside a view | `margin: Edges(.points(16))` |
| `widthAnchor.constraint(equalToConstant: 100)` | `width: .points(100)` |
| Width = 50% of parent | `width: .percent(50)` |
| Fill remaining space (content hugging low) | `flexGrow: 1` |
| Allowed to get smaller (compression resistance low) | `flexShrink: 1` |
| `alignment = .center` (cross axis) | `alignItems: .center` |
| `alignment = .fill` | `alignItems: .stretch` (the default) |
| `distribution = .equalSpacing` | `justifyContent: .spaceBetween` |
| Center a child on both axes | `justifyContent: .center, alignItems: .center` |
| One child aligned differently | `alignSelf: .flexEnd` on that child |
| `UIScrollView` | `.container` + `overflow: .scroll` |
| `clipsToBounds = true` | `overflow: .hidden` |
| `isHidden = true` (and takes no space) | `display: DisplayValue.none` — not `.none`, see §16 |
| Square view | `width: .points(80), aspectRatio: 1` |
| Overlay pinned to a corner | `position: .absolute, inset: Edges(top: .points(8), right: .points(8))` |
| `UILabel` | `content: .text` |
| `UIImageView` | `content: .image` |
| `UITextField`, `UIButton`, any other view | `content: .custom("…")` + register it (§10) |

Values:
- `.points(16)` — points, like UIKit.
- `.percent(50)` — percent of the parent.
- `.auto` — size from content (the default).

## 4. Parent view / container (`UIView`)

A `.container` is a `UIView` that lays out its children. By default:

- children stack **top to bottom** (`flexDirection: .column`),
- each child is **stretched to the container's width** (`alignItems: .stretch`),
- the container is as tall as its children need.

```swift
LayoutTree(
    id: "box", content: .container,
    style: FlexStyle(width: .points(200), height: .points(120), padding: Edges(.points(12))),
    children: [ /* … */ ]
)
```

## 5. Stack views (`UIStackView`)

There is no separate stack view type: every container *is* a stack.

**Vertical stack**

```swift
LayoutTree(
    id: "column", content: .container,
    style: FlexStyle(flexDirection: .column, gap: .points(12)),
    children: [a, b, c]
)
```

**Horizontal stack**, children vertically centred:

```swift
LayoutTree(
    id: "row", content: .container,
    style: FlexStyle(flexDirection: .row, alignItems: .center, gap: .points(8)),
    children: [icon, label]
)
```

**Nested stacks** — a row with an avatar and a column of two labels:

```swift
LayoutTree(
    id: "header", content: .container,
    style: FlexStyle(flexDirection: .row, alignItems: .center, gap: .points(12)),
    children: [
        LayoutTree(id: "avatar", content: .image,
                   style: FlexStyle(width: .points(48), height: .points(48)),
                   props: ["systemImage": .string("person.circle")]),
        LayoutTree(
            id: "names", content: .container,
            style: FlexStyle(flexDirection: .column, flexShrink: 1, gap: .points(2)),
            children: [
                LayoutTree(id: "name", content: .text, props: ["text": .string("Jane")]),
                LayoutTree(id: "handle", content: .text,
                           props: ["text": .string("@jane"), "textColor": .string("#8E8E93")]),
            ]
        ),
    ]
)
```

## 6. Sizes, spacing and pushing things apart

- `padding` — space **inside** the view, around its children.
- `margin` — space **outside** the view.
- `gap` — space **between** children (like `UIStackView.spacing`).

`Edges` accepts one value for all sides, or specific sides:

```swift
Edges(.points(16))                                        // all four sides
Edges(horizontal: .points(20), vertical: .points(12))     // left+right, top+bottom
Edges(top: .points(8), bottom: .points(24))               // just these
```

**Push the last child to the bottom** (e.g. a button at the bottom of a
screen): put an empty container with `flexGrow: 1` before it. It takes all the
free space.

```swift
children: [
    field1, field2,
    LayoutTree(id: "spacer", content: .container, style: FlexStyle(flexGrow: 1)),
    button,
]
```

Or use `justifyContent: .spaceBetween` on the parent to spread children out.

**Two columns splitting the width equally:** give both `flexGrow: 1` and `flexBasis: .points(0)`.

## 7. Text (`UILabel`)

```swift
LayoutTree(
    id: "title", content: .text,
    props: [
        "text": .string("Hello"),
        "textColor": .string("#1C1C1E"),
        "numberOfLines": .number(2),
        "textAlignment": .string("center"),
    ]
)
```

| Prop | Value | Notes |
|---|---|---|
| `text` | `.string("…")` | |
| `textColor` | `.string("#RRGGBB")` | also `#RGB`, `#RRGGBBAA` |
| `numberOfLines` | `.number(2)` | default is `0` (unlimited — text wraps) |
| `textAlignment` | `.string("left" / "center" / "right" / "justified" / "natural")` | |
| `lineBreakMode` | `.string("byTruncatingTail")` etc. | |
| `font` | `.object(["size": .number(20), "weight": .string("semibold")])` | see warning |

Text measures itself, so you normally don't give it a width or height — it
takes the width its parent allows and grows to fit.

> **Dynamic Type:** text without a `font` prop uses the body text style and
> scales with the user's text size setting. **A `font` prop gives a fixed size
> that does not scale.** Leave `font` out if you need Dynamic Type.

## 8. Images (`UIImageView`)

```swift
LayoutTree(
    id: "hero", content: .image,
    style: FlexStyle(height: .points(180)),
    props: ["image": .string("banner"), "contentMode": .string("scaleAspectFill")]
)
```

| Prop | Value |
|---|---|
| `image` | name of an image in your asset catalog |
| `systemImage` | SF Symbol name, e.g. `"star.fill"` |
| `contentMode` | `"scaleAspectFit"`, `"scaleAspectFill"`, `"scaleToFill"`, `"center"`, `"top"`, `"bottom"`, `"left"`, `"right"` |
| `tintColor` | `"#RRGGBB"` |

Give images a size (`width`/`height`, or one of them plus `aspectRatio`) —
otherwise they take the image's own pixel size.

## 9. Scroll view (`UIScrollView`)

Set `overflow: .scroll` on a container. The SDK backs it with a real
`UIScrollView` and sets `contentSize` for you.

The recommended shape is **scroll container → one content container → your
views**:

```swift
LayoutTree(
    id: "scroll", content: .container,
    style: FlexStyle(overflow: .scroll),                 // the UIScrollView
    children: [
        LayoutTree(
            id: "content", content: .container,          // everything that scrolls
            style: FlexStyle(flexDirection: .column, padding: Edges(.points(20)), gap: .points(16)),
            children: paragraphs
        ),
    ]
)
```

- It scrolls **vertically** by default. For a **horizontal** scroller, put
  `flexDirection: .row` on the scroll container and give the content a width
  (or let a row of fixed-width children define it).
- A scroll container that is **not** the root needs a limited height, or it
  just grows to fit its content and never scrolls. Either give it a fixed
  `height`, or let it fill the leftover space with **both**
  `flexGrow: 1` and `flexBasis: .points(0)` (`flexGrow` alone is not enough):

  ```swift
  LayoutTree(id: "list", content: .container,
             style: FlexStyle(flexGrow: 1, flexBasis: .points(0), overflow: .scroll),
             children: [content])
  ```
- The scroll position is kept when you call `update(to:)`.

## 10. Your own views: `UITextField`, `UIButton`, anything

The SDK only has built-in text and image views. For everything else you
**register** a factory for a `.custom("name")` type, then use that name in the
tree.

**Quick way — a closure** (creates the view; can't resize itself, so give it a height):

```swift
var registry = FlexViewRegistry.default

registry.register(.custom("textField")) { tree in
    let field = UITextField()
    field.borderStyle = .roundedRect
    if case .string(let placeholder)? = tree.props?["placeholder"] {
        field.placeholder = placeholder
    }
    return field
}

registry.register(.custom("button")) { tree in
    var config = UIButton.Configuration.filled()
    if case .string(let title)? = tree.props?["title"] { config.title = title }
    return UIButton(configuration: config, primaryAction: UIAction { _ in
        print("tapped")
    })
}

let host = FlexHostView(tree: layout, registry: registry)
```

Then in the tree:

```swift
LayoutTree(id: "email", content: .custom("textField"),
           style: FlexStyle(height: .points(44)),
           props: ["placeholder": .string("Email")])

LayoutTree(id: "submit", content: .custom("button"),
           style: FlexStyle(height: .points(50)),
           props: ["title": .string("Sign up")])
```

Notes:
- `props` is optional, so read it with `tree.props?["key"]`.
- **Reading values back:** the SDK has no public "get view by id" call. Keep
  your own references when the factory creates them, e.g. a
  `[String: UITextField]` dictionary keyed by `tree.id` (see §17).
- **Updating props later:** the closure only runs when the view is created. If
  a prop can change (a button title, a field's enabled state), write a full
  factory and implement `update(_:for:)`.

**Full factory** — can update and measure itself (here: a button sized to its title):

```swift
struct ButtonFactory: FlexViewFactory {
    let onTap: (String) -> Void   // receives the node id

    func makeView(for tree: LayoutTree) -> UIView {
        let button = UIButton(configuration: .filled())
        button.addAction(UIAction { _ in onTap(tree.id) }, for: .touchUpInside)
        update(button, for: tree)
        return button
    }

    func update(_ view: UIView, for tree: LayoutTree) {
        guard let button = view as? UIButton else { return }
        if case .string(let title)? = tree.props?["title"] {
            button.configuration?.title = title
        }
    }

    func measure(_ view: UIView, width: FlexMeasureConstraint,
                 height: FlexMeasureConstraint) -> FlexSize? {
        let size = view.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                            height: CGFloat.greatestFiniteMagnitude))
        return FlexSize(width: Double(size.width), height: Double(size.height))
    }
}

registry.register(ButtonFactory(onTap: { id in print("tapped", id) }), for: .custom("button"))
```

With `measure`, you don't need to give the node a height.

You can also register on an existing host: `host.register(ButtonFactory(...), for: .custom("button"))`
(this rebuilds the views).

## 11. Background colour and rounded corners

Built-in containers have **no** props for background colour, border colour or
corner radius. Register your own factory for `.container` that reads them. It
replaces the default one for every container in that host:

```swift
struct StyledContainerFactory: FlexViewFactory {
    func makeView(for tree: LayoutTree) -> UIView {
        let view = UIView()
        update(view, for: tree)
        return view
    }

    func update(_ view: UIView, for tree: LayoutTree) {
        let props = tree.props ?? [:]
        if case .string(let hex)? = props["backgroundColor"] { view.backgroundColor = UIColor(hex: hex) }
        if case .number(let radius)? = props["cornerRadius"] { view.layer.cornerRadius = radius }
        view.clipsToBounds = tree.style.overflow == .hidden || view.layer.cornerRadius > 0
    }
}

registry.register(StyledContainerFactory(), for: .container)
```

`UIColor(hex:)` is not part of UIKit — write a small helper, or pass colours
another way. Scroll containers (`overflow: .scroll`) are always a
`UIScrollView` and don't use this factory.

The `border` style (`border: EdgeWidths(1)`) only reserves layout space like
CSS border width; it does **not** draw a line. Draw it in your factory
(`view.layer.borderWidth`).

## 12. Safe area

By default the root fills the whole host, **under** the notch and home
indicator. To keep content inside the safe area:

```swift
host.safeAreaMode = .padRoot(.all)      // all edges
host.safeAreaMode = .padRoot(.vertical) // top + bottom only
host.safeAreaMode = .padRoot([.bottom]) // just the bottom
```

The safe-area inset is added on top of the root's own `padding`.

If the host is inside a `UINavigationController`, the top safe area already
includes the navigation bar.

## 13. Changing the screen later

Build a new tree and call `update(to:)`. The SDK compares it with the current
one and only changes what's different. Views keep their identity when their
`id` stays the same, so a text field keeps its text and focus, and a scroll
view keeps its position.

```swift
host.update(to: Self.layout(isLoading: false, items: items))
```

Write your layout as a function of your state:

```swift
static func layout(isLoading: Bool, items: [Item]) -> LayoutTree {
    LayoutTree(
        id: "root", content: .container,
        style: FlexStyle(flexDirection: .column, gap: .points(8)),
        children: isLoading
            ? [LayoutTree(id: "loading", content: .text, props: ["text": .string("Loading…")])]
            : items.map { item in
                LayoutTree(id: "item-\(item.id)", content: .text, props: ["text": .string(item.name)])
            }
    )
}
```

- Use **stable ids** from your data (`"item-\(item.id)"`), not array indexes —
  otherwise inserting one item makes every view below it update.
- Ids must be unique within a tree.
- To hide something but keep it in the tree, set `display: DisplayValue.none`
  (write the type name — plain `.none` means "not set", see §16).

## 14. Table and collection view cells

Use `FlexTableViewCell` / `FlexCollectionViewCell`. They size themselves to
their content.

```swift
tableView.register(FlexTableViewCell.self, forCellReuseIdentifier: "row")
tableView.rowHeight = UITableView.automaticDimension
tableView.estimatedRowHeight = 80

override func tableView(_ tableView: UITableView,
                        cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "row", for: indexPath) as! FlexTableViewCell
    cell.host.update(to: rowLayout(for: items[indexPath.row]))
    return cell
}
```

- Don't add other subviews to the cell's `contentView`.
- For collection views, the layout decides the **width** (e.g. the flow
  layout's `estimatedItemSize.width`); the cell's height comes from its
  content.
- For a big list, use a table or collection view with these cells — not a
  scroll container with hundreds of children.

## 15. The same layout as JSON

Every tree can be sent from a server as JSON. Style keys use CSS names:

```json
{
  "schemaVersion": 1,
  "root": {
    "id": "root",
    "content": "container",
    "style": { "flexDirection": "column", "padding": 20, "gap": 12 },
    "children": [
      { "id": "title", "content": "text", "props": { "text": "Hello" } },
      { "id": "email", "content": "textField", "style": { "height": 44 },
        "props": { "placeholder": "Email" } }
    ]
  }
}
```

A custom type is just its name (`"textField"`) — the app must register it. Load
JSON with a bundled fallback so a bad payload never shows a blank screen:

```swift
let resolution = LayoutResolver.resolve(remote: dataFromServer, fallback: bundledLayout)
let host = FlexHostView(tree: resolution.tree, registry: registry)
```

The full JSON contract is in [SCHEMA.md](SCHEMA.md).

## 16. Common mistakes

| Symptom | Cause | Fix |
|---|---|---|
| A custom view (text field, button) is invisible | It has height 0 — closure factories can't measure | Give it `height`, or implement `measure` |
| A scroll container doesn't scroll | It isn't limited in height, so it grows to fit its content | Make it the root, give it a `height`, or `flexGrow: 1` **plus** `flexBasis: .points(0)` |
| `display: .none` doesn't hide anything | Swift reads `.none` as "no value" (`nil`) because the field is optional; the compiler only warns | Write `display: DisplayValue.none` |
| Compile error "argument 'children' must precede argument 'props'" | `LayoutTree` arguments have a fixed order | `id, content, style, children, props` |
| Children don't sit side by side | The default direction is column | `flexDirection: .row` |
| Button isn't at the bottom | Nothing takes the free space | Spacer with `flexGrow: 1` before it |
| Content under the notch / home indicator | Safe area is ignored by default | `host.safeAreaMode = .padRoot(.all)` |
| Text doesn't grow with Dynamic Type | A `font` prop is set | Remove `font` |
| Every row updates when one item is inserted | Ids are array indexes | Use ids from your data |
| Can't find a view to read its value | No public lookup by id | Keep references in your factory |
| Background colour has no effect | Containers ignore colour props | §11 |
| Keyboard covers the text fields | No built-in keyboard avoidance | Wrap the form in a scroll container and adjust for the keyboard yourself |

## 17. Full example: a sign-up form

Three text fields in a vertical stack and a button pinned to the bottom. This
is the Form screen in [`Examples/FlexDemo`](Examples/FlexDemo).

```swift
import UIKit
import FlexboxCore
import FlexboxKit

final class SignUpViewController: UIViewController {
    private var fields: [String: UITextField] = [:]   // our handles, keyed by node id

    override func loadView() {
        var registry = FlexViewRegistry.default

        registry.register(.custom("textField")) { [unowned self] tree in
            let field = UITextField()
            field.borderStyle = .roundedRect
            if case .string(let placeholder)? = tree.props?["placeholder"] {
                field.placeholder = placeholder
            }
            field.isSecureTextEntry = tree.props?["secure"] == .bool(true)
            self.fields[tree.id] = field
            return field
        }

        registry.register(.custom("button")) { [unowned self] tree in
            var config = UIButton.Configuration.filled()
            if case .string(let title)? = tree.props?["title"] { config.title = title }
            return UIButton(configuration: config, primaryAction: UIAction { _ in self.submit() })
        }

        let host = FlexHostView(tree: Self.form, registry: registry)
        host.backgroundColor = .systemBackground
        host.safeAreaMode = .padRoot(.all)
        view = host
    }

    static let form = LayoutTree(
        id: "form", content: .container,
        style: FlexStyle(flexDirection: .column, padding: Edges(.points(20)), gap: .points(12)),
        children: [
            field("name", "Name"),
            field("email", "Email"),
            field("password", "Password", secure: true),
            LayoutTree(id: "spacer", content: .container, style: FlexStyle(flexGrow: 1)),
            LayoutTree(id: "submit", content: .custom("button"),
                       style: FlexStyle(height: .points(50)),
                       props: ["title": .string("Sign up")]),
        ]
    )

    static func field(_ id: String, _ placeholder: String, secure: Bool = false) -> LayoutTree {
        LayoutTree(id: id, content: .custom("textField"),
                   style: FlexStyle(height: .points(44)),
                   props: ["placeholder": .string(placeholder), "secure": .bool(secure)])
    }

    private func submit() {
        print("email:", fields["email"]?.text ?? "")
    }
}
```
