# BLOCKERS — VK HIG

| Priority | Blocker | Required input/action | Safe fallback | Status |
|---|---|---|---|---|
| P0 | No macOS/Xcode on Cloud Linux VM | Jessica builds on Mac: `xcodebuild -scheme VKHIG -destination 'platform=iOS Simulator,name=iPhone 16' build test` | UI + fixtures shipped; build/tests marked `NOT RUN` | OPEN |
| P1 | VK ID credentials (Jessica later) | Fill `Secrets.xcconfig` / Info.plist placeholders when testing | Fixture UI shell; `AppSecrets.hasVKIDCredentials == false` | DEFERRED (not blocking implementation) |
| P1 | VKID SDK not linked | Add SPM `vkid-ios-sdk` on Mac when credentials exist | `authorize()` → `.sdkNotLinked` / `.missingCredentials` | DEFERRED |
| P1 | Official scopes unverified | Confirm messages/newsfeed/users/etc. before enabling `verifiedLiveFeatures` | Capability gates + fixtures | OPEN (honest) |
| P1 | Music / calling / stories live | Official rights/SDK | Unavailable / disabled UI shipped | MITIGATED in UI |
| P2 | App icon 1024×1024 | Supply marketing icon | Empty AppIcon slot | OPEN |

## Closed / mitigated

- Empty iOS repo → scaffolded on `main`
- PR #1 landed on `main`; further work commits directly to `main`
