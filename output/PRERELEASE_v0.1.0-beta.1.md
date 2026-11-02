# VK HIG 0.1.0-beta.1

First public pre-release of the native SwiftUI VK client. The release includes an unsigned iOS device IPA for owner-controlled signing.

## Included

- Native SwiftUI app structure with separate navigation stacks and Russian UI.
- Official VK ID OAuth 2.1 / PKCE login flow, session restore/refresh and Keychain storage.
- VK API adapters for messaging, feed, profiles/social, photos/video and supported community operations. Every feature remains dependent on grants for this app; the default scope is identity only.
- Chat history, paged inbox/search, drafts, durable outbox/retry identity, supported attachments and Long Poll while active.
- Offline/local media features, accessibility states, dark/light appearance and user controlled settings.
- Local music library/player; remote catalog remains gated by actual audio permission and valid VK-provided HTTPS streams.
- Push/APNs is intentionally excluded from this release.

## Verification

The simulator matrix is recorded in [CI run 41541746765](https://github.com/decoder-dev/Ios_vk_Hig_beta/actions/runs/41541746765): iOS 27 passed; iOS 18 passed all 42 unit tests but 2 of 7 UI tests failed in large-text music-player assertions (`testMusicPlayerLargeText` and `testMusicPlayerQueueLyricsAndEqualizer`).

The release also includes `VKHIG-v0.1.0-beta.1-unsigned.ipa`, built from the release source with Xcode 27. SHA-256: `c33c3368d56d0e173acf30d731400f036dc88750be11892f46a63e14d14de9a1`. It contains no code signature or provisioning profile. Re-sign it with an Apple-issued distribution certificate and a matching provisioning profile before installing on a regular iPhone.

## Known limits

- The attached IPA is unsigned; it is not directly installable until signed and provisioned for the target device(s).
- TestFlight/device distribution requires the owner's Apple Developer team, signing configuration and provisioning. No Apple signing secrets are configured in this repository.
- VK cabinet grants, real-account OAuth/API behavior, music rights/streams, and physical-device acceptance remain unverified; simulator/fixture success does not grant these rights.
- Native incoming VK calls are not implemented without an authorized native calls SDK/contract.
