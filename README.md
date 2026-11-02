# VK HIG

Native SwiftUI VK client (Apple HIG–oriented) for repository `Ios_vk_Hig_beta`.

> Working name **VK HIG**. Not an official VK or Apple product.  
> Handoff kit: see `README_START_HERE.md`, `AGENTS.md`, `PROMPT_FOR_CURSOR.md`.

## Status

- **Stage 0** audit docs in `output/`
- **Stage 1** TabView foundation + design tokens
- **P0 slices (fixture-backed):** Auth stub, Inbox, Conversation, Feed, Profile, Settings entry
- **Xcode build / XCTest / Simulator:** not run on Linux CI agents — use a Mac

Live VK API success is **not** simulated. Fixture data shows an orange banner.

## Open on Mac

```bash
git clone https://github.com/decoder-dev/Ios_vk_Hig_beta.git
cd Ios_vk_Hig_beta
# optional: brew install xcodegen && xcodegen generate
open VKHIG.xcodeproj
```

### Build & test

```bash
xcodebuild -scheme VKHIG \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -configuration Debug build

xcodebuild -scheme VKHIG \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test
```

Min deployment: **iOS 17**.

## VK ID credentials (required for live auth)

1. Create your own app in the VK ID console  
2. Set client/app id + redirect URI / URL scheme in the project (do not commit secrets)  
3. Add [VKID iOS SDK](https://github.com/VKCOM/vkid-ios-sdk) via SPM  
4. Wire `VKIDConfiguration` in `VKIDAuthCoordinator`  
5. Verify scopes before enabling features in `CapabilityRegistry`

Never use Fenrir/Phoenix keys or private VK APIs.

## Layout

| Path | Purpose |
|---|---|
| `VKHIG/` | App sources |
| `VKHIGTests/` | Unit tests |
| `docs/`, `design/`, `examples/` | Kit specs / tokens / reference |
| `output/` | Audit & delivery status |
| `project.yml` | XcodeGen definition |

## License / legal

See `README_LICENSE.md` and `docs/LEGAL_AND_BRANDING.md`. Independent implementation — no Fenrir/Phoenix source copied.
