# VK HIG 0.1.0-beta.1

First public source pre-release of the native SwiftUI VK client.

## Included

- Native SwiftUI app structure with separate navigation stacks and Russian UI.
- Official VK ID OAuth 2.1 / PKCE login flow, session restore/refresh and Keychain storage.
- VK API adapters for messaging, feed, profiles/social, photos/video and supported community operations. Every feature remains dependent on grants for this app; the default scope is identity only.
- Chat history, paged inbox/search, drafts, durable outbox/retry identity, supported attachments and Long Poll while active.
- Offline/local media features, accessibility states, dark/light appearance and user controlled settings.
- Local music library/player; remote catalog remains gated by actual audio permission and valid VK-provided HTTPS streams.
- Push/APNs is intentionally excluded from this release.

## Verification

The source commit immediately before this release passed the Xcode 27 / iOS 27 simulator CI job. This release increments the app build number; push to `main` triggers the repository's iOS 18 and iOS 27 build/test matrix. Record its result in `output/TEST_RESULTS.md` before calling the release validated.

## Known limits

- This GitHub pre-release contains source and CI evidence; no signed IPA is attached.
- TestFlight/device distribution requires the owner's Apple Developer team, signing configuration and provisioning. No Apple signing secrets are configured in this repository.
- VK cabinet grants, real-account OAuth/API behavior, music rights/streams, and physical-device acceptance remain unverified; simulator/fixture success does not grant these rights.
- Native incoming VK calls are not implemented without an authorized native calls SDK/contract.
