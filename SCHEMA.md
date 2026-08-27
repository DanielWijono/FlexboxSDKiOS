# Layout payload schema

The contract a backend sends. Defined by the SDK, not the app.

## Envelope

```json
{
  "schemaVersion": 1,
  "root": { <node> }
}
```

- `schemaVersion` (int, **required**). A payload whose version is missing, below
  `LayoutSchema.minimumSupported`, or above `LayoutSchema.current` is rejected;
  the caller falls back to a bundled layout. Current: **1**.
- `root` (node, required).

**Unknown keys anywhere are ignored, not fatal.** A newer backend stays readable
by an older app. Do not rely on an app reacting to a key its schema version does
not define.

## Node

```json
{
  "id": "header",
  "content": "container",
  "style": { <style> },
  "children": [ <node>, ... ],
  "props": { <json> }
}
```

| Key | Type | Notes |
|---|---|---|
| `id` | string, **required** | unique within the tree; stable across versions (reconciliation keys on it) |
| `content` | string | `"container"` \| `"text"` \| `"image"` \| any other string ⇒ a custom view type the app has registered |
| `style` | object | omit when empty |
| `children` | array | omit when empty; a non-container `content` must have none |
| `props` | object | leaf parameters (label text, image name, custom props). JSON scalars / arrays / objects only — never code, expressions, or navigation |

## Style

Every key is optional. **A missing key means "use the engine default"** — there
is no encoding for "undefined" because `YGUndefined` is NaN and NaN has no JSON
form.

### Lengths (`FlexDimension`)

- points: a JSON number — `12`, `12.5`
- percent: a string ending in `%` — `"50%"`
- auto: the string `"auto"`

### Keys

| Key | Values |
|---|---|
| `flexDirection` | `row` \| `row-reverse` \| `column` \| `column-reverse` |
| `justifyContent` | `flex-start` \| `center` \| `flex-end` \| `space-between` \| `space-around` \| `space-evenly` |
| `alignItems`, `alignSelf`, `alignContent` | `auto` \| `flex-start` \| `center` \| `flex-end` \| `stretch` \| `baseline` \| `space-between` \| `space-around` \| `space-evenly` |
| `flexWrap` | `nowrap` \| `wrap` \| `wrap-reverse` |
| `flexGrow`, `flexShrink` | number ≥ 0 |
| `flexBasis` | length |
| `width`, `height`, `minWidth`, `minHeight`, `maxWidth`, `maxHeight` | length |
| `aspectRatio` | number > 0 |
| `margin`, `padding`, `inset` | length shorthand, or an edges object (below) |
| `border` | number shorthand, or an edges object with number values |
| `position` | `relative` \| `absolute` \| `static` |
| `gap`, `rowGap`, `columnGap` | length (point or percent) |
| `display` | `flex` \| `none` \| `contents` |
| `overflow` | `visible` \| `hidden` \| `scroll` |
| `boxSizing` | `border-box` \| `content-box` |

### Edges object

```json
"padding": { "top": 8, "horizontal": 16 }
```

Keys: `top`, `left`, `bottom`, `right`, `start`, `end`, `horizontal`,
`vertical`, `all`. Resolution, most specific wins:

```
top    → vertical   → all
bottom → vertical   → all
left   → horizontal → all
right  → horizontal → all
```

`start` / `end` are writing-direction relative and applied on top.

An unknown enum string (e.g. `"flexDirection": "diagonal"`) fails decoding of the
whole payload → fallback.

## Limits (`LayoutLimits`, host-overridable)

| Limit | Default |
|---|---|
| max tree depth | 64 |
| max node count | 2000 |
| max scalar leaves across all `props` | 10000 |
| max `id` length | 256 |

A payload exceeding any limit is rejected → fallback.

## Validation

Beyond the limits, a payload is rejected if:

- two nodes share an `id`
- a non-container node has children
- `flexGrow` or `flexShrink` is negative
- `aspectRatio` ≤ 0
- an `id` is empty

## Known limitations (schema v1)

- A reconciliation update that removes `minWidth` / `maxWidth` / `aspectRatio`
  from a node cannot restore Yoga's exact "unset". Prefer setting an explicit
  value over omitting a previously-present one for those three keys.

## Version history

| Version | Changes |
|---|---|
| 1 | Initial. Everything above. |
