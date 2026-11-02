# Test results — 2026-11-02

## Final source: compile/unit verification PASS

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

Swift tree-sitter parsing, YAML/plist parsing, shell syntax and git diff --check pass. The parser has one known false positive at valid Result<Void>.success(()) in VKIDAuthCoordinator; Xcode accepts it.

## External acceptance: NOT RUN

Real OAuth/account/API mutations and granted music streams; signed physical-device/APNs delivery; native incoming VK calls; camera/location uploads; audio interruption/AirPlay; VoiceOver/Reduce Motion; performance and full screen/state coverage. Fixtures and simulators do not establish these capabilities.

## APNs configuration follow-up
Push registration now uses the signing APNS_ENVIRONMENT via Info.plist, rejects unknown configuration and registers a rotated token after an in-flight request. A direct APNs smoke sender and four offline Node tests are added; those tests PASS. Three new Swift regression tests cover environment mapping, unknown configuration and token rotation (36 unit tests total; new Xcode run PENDING). Actual Apple/VK provider configuration and delivery remain BLOCKED: Apple sign-in is required; VK ID cabinet access is denied by this environment's browser site-safety policy. No native iOS calling SDK/authorization or music approval is available. See docs/DEVICE_AND_VK_ACCEPTANCE.md.
