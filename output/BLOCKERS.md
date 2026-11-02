# BLOCKERS — VK HIG

| Priority | Blocker | Required input/action | Safe fallback | Status |
|---|---|---|---|---|
| P0 | No macOS/Xcode on Cloud Linux VM | Jessica: `xcodebuild -scheme VKHIG -destination 'platform=iOS Simulator,name=iPhone 16' build test` | UI + fixtures; build/tests `NOT RUN` | OPEN |
| P0 | GitHub Actions secrets API 403 for agent token | Jessica: add `VK_ID_CLIENT_ID` and `VK_ID_CLIENT_SECRET` in repo **Settings → Secrets and variables → Actions** | Local gitignored `Secrets.xcconfig` on Mac; workflow ready | OPEN (needs human) |
| P1 | VKID iOS SDK not linked | Add SPM `vkid-ios-sdk` on Mac after secrets exist | `authorize()` → `.sdkNotLinked` when client id configured | OPEN |
| P1 | Official scopes unverified | Confirm scopes; set `CapabilityRegistry.verifiedLiveFeatures` | Fixtures + honest errors without token | OPEN |
| P1 | Music / calling live | Official rights/SDK | Unavailable UI | MITIGATED |
| P2 | App icon 1024×1024 | Supply marketing icon | Empty AppIcon slot | OPEN |

## Credentials handling

- Values live in **gitignored** `VKHIG/Config/Secrets.xcconfig` (local) and intended GitHub Actions secrets (`VK_ID_CLIENT_ID`, `VK_ID_CLIENT_SECRET`).
- Client secret is **not** wired into Info.plist / app binary APIs (PKCE public client).
- Agent could **not** call `gh secret set` (HTTP 403 Resource not accessible by integration).
