# REPO AUDIT — VK HIG / Ios_vk_Hig_beta

- Date: 2026-11-02
- Branch: `cursor/stage0-stage1-foundation-6d76`
- Repo: https://github.com/decoder-dev/Ios_vk_Hig_beta
- Workspace path: `/workspace` (Cursor Cloud Linux VM)

## Baseline (before this PR)

| Item | Finding |
|---|---|
| Prior content | Nearly empty: `README.md` title only (`# Ios_vk_Hig_beta`) |
| `.xcodeproj` / `.xcworkspace` | Absent |
| SPM packages | Absent |
| Tests | Absent |
| Min iOS / Swift | N/A (greenfield) |

## After this PR (scaffold + P0 foundation)

| Item | Finding |
|---|---|
| Xcode project | `VKHIG.xcodeproj` (generated via `scripts/generate_pbxproj.py`; also `project.yml` for XcodeGen on Mac) |
| App target | `VKHIG` → product **VK HIG**, bundle `com.decoderdev.vkhig` |
| Test target | `VKHIGTests` |
| Min deployment | **iOS 17.0** |
| Swift | 5.x (project setting `SWIFT_VERSION = 5.0`) |
| UI | SwiftUI `TabView` + per-tab `NavigationStack` |
| Kit handoff | Copied `AGENTS.md`, `PROMPT_FOR_CURSOR.md`, `.cursor/rules/`, `docs/`, `design/` (tokens, preview, boards, wireframes), `examples/`, `output/` templates, `README_LICENSE.md` |

## Architecture (observed / created)

| Path | Meaning | How verified |
|---|---|---|
| `VKHIG/App/` | `@main` entry, root tabs, auth gate | file read |
| `VKHIG/DesignSystem/` | Tokens + shared state views | file read |
| `VKHIG/Domain/` | Models + message reconciler | file read |
| `VKHIG/Data/` | Fixtures, repositories, VKAPIClient, capabilities | file read |
| `VKHIG/Security/` | Session, Keychain store, VK ID coordinator stub | file read |
| `VKHIG/Features/{Auth,Feed,Messages,Music,Profile,Services}` | P0 screens / honest stubs | file read |
| `examples/SwiftUIReference/` | Non-production reference snippets | copied from kit |
| Fenrir / Phoenix | **Not vendored**; functional reference only via kit docs | not checked out |

## Build / tests baseline

| Check | Status | Notes |
|---|---|---|
| `xcodebuild` | **NOT RUN** | Linux cloud VM — no macOS / Xcode |
| Simulator | **NOT RUN** | requires Mac |
| XCTest | **NOT RUN** | requires Mac |
| Instruments | **NOT RUN** | requires Mac |

### Mac commands (run locally or on Mac self-hosted worker)

```bash
cd /path/to/Ios_vk_Hig_beta
# Optional regenerate from XcodeGen:
# brew install xcodegen && xcodegen generate
open VKHIG.xcodeproj
xcodebuild -scheme VKHIG -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build
xcodebuild -scheme VKHIG -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Fenrir / Phoenix comparative note

| Source | Role in this repo | Copy status |
|---|---|---|
| Fenrir (`umerov1999/Fenrir-for-VK`) | Functional/feature reference via kit `docs/RESEARCH_*` | **Not copied** |
| Phoenix (`PhoenixDevTeam/Phoenix-for-VK`) | Functional reference; GPL implications | **Not copied** |
| VKID iOS SDK | Planned Stage 2 dependency | **Not linked yet** — needs Jessica credentials |

External GitHub checkouts of Fenrir/Phoenix: **NOT CHECKED** on this Linux agent (network/reference docs used from kit only).
