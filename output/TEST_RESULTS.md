# TEST RESULTS — VK HIG

| Suite | Command | Environment | Result | Evidence |
|---|---|---|---|---|
| Unit (`VKHIGTests`) | `xcodebuild -scheme VKHIG -destination 'platform=iOS Simulator,name=iPhone 16' test` | Cursor Cloud Linux | **NOT RUN** | No Xcode / iOS Simulator on this VM |
| App build | `xcodebuild -scheme VKHIG -destination 'platform=iOS Simulator,name=iPhone 16' build` | Cursor Cloud Linux | **NOT RUN** | Same |
| UI tests | — | — | **NOT RUN** | No UI test target yet |
| Manual Simulator smoke | — | — | **NOT RUN** | Requires Mac |

## Tests authored (awaiting Mac execution)

`VKHIGTests/VKHIGFoundationTests.swift`:

- Session shell sign-in/out local only
- Design token contract (spacing 16 / tap 44 / card radius 20)
- MessageReconciler idempotency per `random_id`
- Fixture inbox load
- Outgoing fixture message remains `.pending`
- VK ID authorize fails without credentials
- Music capability is `unavailable`

Do **not** treat this file as proof of PASS.
