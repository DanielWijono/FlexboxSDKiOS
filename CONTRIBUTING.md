# Contributing

This project is maintained voluntarily with limited capacity. Well-scoped pull
requests land faster than issues get resolved.

## Developer Certificate of Origin (DCO)

There is no CLA. Every commit must be signed off:

```
git commit -s -m "your message"
```

which appends:

```
Signed-off-by: Your Name <you@example.com>
```

By signing off you assert the [DCO](https://developercertificate.org/) — that you
wrote the change or otherwise have the right to submit it under the project's
Apache-2.0 license. CI rejects unsigned commits.

## Running the gates

All of these must be green before a PR is reviewed:

```bash
swift build
swift test
swift test --sanitize=address
swift test -c release          # the production reject-and-continue paths
```

Grep gates (also enforced in CI):

```bash
! grep -rn "YGNodeFreeRecursive\|passRetained" Sources/
! grep -rn "import UIKit" Sources/FlexboxCore/
```

Anything under `Engine/YogaInterop.swift` is the only place a `YG*` symbol or
`import CYoga` may appear.

## Good places to start

| Area | Why it's a good entry point |
|---|---|
| `Reconcile/Reconciler.swift` | pure function over values, fully unit-testable, no engine knowledge needed. Minimising the op set for cross-parent moves is open. |
| `Schema/LayoutValidation.swift` | add checks, tighten messages; each has a matching test in `Tests/.../Schema`. |
| `Model/` codable round-trips | new `FlexStyle` fields land here; the policy (optional, absent-means-default) is uniform. |
| `Diagnostics/YogaAssertCatalog.swift` | keep the catalog in sync with `flexRequire` call sites. |

The UIKit renderer (`FlexboxKit`) is not open for contribution yet — its design
is still being written (see ARCHITECTURE.md).

## Style

Match the surrounding code. Public API gets a doc comment that says what the
value *is*, not how it's implemented. No marketing language in docs or messages.

## Versioning

The project stays on `0.x` until the maintainer's own app ships on it and the
API has been stable for two months. Breaking changes are expected until then and
do not need a major bump while we are `0.x`.
