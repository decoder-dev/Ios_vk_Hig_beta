# Test results — 2026-11-02

## Current no-push source: PASS

Source 85450726b0a9dc1afc305d5f6d54f196a01e0cdc. Run https://github.com/decoder-dev/Ios_vk_Hig_beta/actions/runs/41521893697 passed Xcode 27/iOS 27 compilation and all 33 remaining unit tests (0 failures), job 125539754736. Push was removed by explicit user instruction, including its three tests. No new full UI/device pass is claimed for this scope change.

Static checks PASS: no notification authorization or APNs/VK registration calls; no signing entitlement; Info.plist has audio background mode only; shell syntax and git diff --check pass. A launch migration only unregisters previous remote registration and clears this app's pending/delivered notifications.

## Earlier async-safety revision: PASS

Source 33846a3 (main) adds guards that reject stale user/location-picker responses after query changes. Focused Xcode 27/iOS 27 compilation and all 33 unit tests passed (0 failures), job 125502580523: run https://github.com/decoder-dev/Ios_vk_Hig_beta/actions/runs/41511022163. This run intentionally excludes UI tests; it does not replace the UI result below.

## iOS 27 interface revision: PASS

Source a134aea8dcc965dca13e1ed2eefdf6df5f7f7227.
Run: https://github.com/decoder-dev/Ios_vk_Hig_beta/actions/runs/41509033714
Job: 125495749264, Xcode 27 / iOS 27 / iPhone 18 Pro simulator.

- Project generation and compilation: PASS.
- 33 unit tests: PASS, 0 failures.
- 5 UI tests: PASS, 0 failures: demo navigation, light/dark/large text and saved/Stories service screens.
- All 17 exported PNG attachments inspected. Pagination now sits in the inbox List instead of overlapping the last row at large text sizes. Content below the floating tab bar remains scrollable; these screenshots are not a full accessibility certification.
- Artifact: ios-27-test-results; verified SHA-256 4d4724b4dcd0a07aeeb0603e8c06b87f477845554f464657be2b47699070b599.
- UI hierarchy/rendering is unchanged by the later stale-response guards; those affect asynchronous results after a query change. Real-account search acceptance remains open.

## Cross-version feature revision: PASS

Source 6c02f898652f2e9b0b7dfb6ad1e4e55af6ac22d8, run https://github.com/decoder-dev/Ios_vk_Hig_beta/actions/runs/41506365100.
Both iOS 18/Xcode 16.4 (job 125486594384) and iOS 27/Xcode 27 (job 125486594891) completed compilation/tests successfully. This predates the pure inbox layout and stale-response fixes. Visual review of this first run found the overlap despite all screenshot tests passing, which prompted the correction and second UI run.

## Regression coverage and local checks

Unit coverage includes OAuth validation/scope gates/retry identity, comment reply mutations, cancellation, server ACL override and write guards, recipient pagination/deduplication, saved-item identities/payloads and failed deletion, profile IDs/birthday validation, media/quote mapping, Story expiry/visibility, safe upload names, integer bounds and music grant/stream checks. The final helper-view stale-response guards are checked by recompiling the app and running the existing unit suite; their race path is not directly exercised by that suite or a real-account test.

Resource/plist checks, shell syntax and git diff --check pass. Earlier Swift tree-sitter checks had one known false positive at valid Result<Void>.success(()) in VKIDAuthCoordinator; Xcode accepts it. The new revision is checked by the actual Xcode run above.

## External acceptance: NOT RUN

Real OAuth/account/API mutations and granted music streams; signed physical-device installation; native incoming VK calls; camera/location uploads; audio interruption/AirPlay; VoiceOver/Reduce Motion; performance and full screen/state coverage. Fixtures and simulators do not establish these capabilities.

Push/APNs delivery is excluded from acceptance for this release. The preceding APNs-only revision 12dcccd passed 36 unit tests in run 41517627368 before that functionality was removed.


## PrivateMusic2 adaptation (validation pending)
Native music module added using PrivateMusic2 @ 68d10a9 as a behavioral reference:
local playlists, persistent paused queue, global mini-player, account-isolated direct-file downloads,
LRC/LRCLIB lyrics and a real local ten-band equalizer. See docs/MUSIC_ADAPTATION.md for precise scope.
New simulator build/unit/UI checks: NOT RUN yet. Live VK music approval and device audio checks:
NOT RUN. Calls deferred; push remains disabled.

## First public source pre-release: 0.1.0-beta.1 (build 2)

Release tag `v0.1.0-beta.1` points to source `35689e48c6b92daad30b70c0df556385e5036cf4`.
Run: https://github.com/decoder-dev/Ios_vk_Hig_beta/actions/runs/41541746765
- Xcode 27 / iOS 27 simulator job `125607375292`: **PASS**, including the configured `xcodebuild ... test` step and result artifact upload.
- Xcode 16.4 / iOS 18 simulator job `125607374988`: **FAIL** overall. All 42 unit tests passed (0 failures); 5 of 7 UI tests passed. `testMusicPlayerLargeText` and `testMusicPlayerQueueLyricsAndEqualizer` failed at `VKHIGUITests/SmokeTests.swift:45`.
- Unsigned device IPA export: **PASS**, workflow run https://github.com/decoder-dev/Ios_vk_Hig_beta/actions/runs/41544690143. Asset `VKHIG-v0.1.0-beta.1-unsigned.ipa`, SHA-256 `c33c3368d56d0e173acf30d731400f036dc88750be11892f46a63e14d14de9a1`. Bundle ID `com.decoderdev.vkhig`, version `0.1.0` (build `2`); no `_CodeSignature` or embedded provisioning profile is present.
- This IPA must be signed with an Apple-issued certificate and a matching provisioning profile for device installation. Repository signing secrets are not configured.

## Multi-account auth
`VKHIGTests/VKAccountsTests.swift` (token parser, adapter, auth-challenge parsing, scopes): NOT RUN. Camera QR, WKWebView flow,
password grant against VK, account switching on device: NOT RUN.

## Password-grant hardening
`VKAccountsTests` extended: DTO parsing (secret/trusted_hash/validation_sid), account-type presets, MD5 `sig`
determinism, device_id stability, QR auth_hash extraction. NOT RUN (no Swift toolchain here). 2FA SMS fallback,
sig-signed live calls, QR login confirm against a real VK account: NOT RUN.
