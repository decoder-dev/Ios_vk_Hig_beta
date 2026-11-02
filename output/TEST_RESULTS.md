# Test results — 2026-11-02

## macOS CI: PASS

Verified source commit: `774b58efd6505eac280c44e5a98e13972ded349d` (main).
Run: https://github.com/decoder-dev/Ios_vk_Hig_beta/actions/runs/41496009543

- Xcode 16.4, iOS 18.5 iPhone simulator on macos-15-intel.
- XcodeGen project generation and iOS compilation: PASS.
- 17 unit tests: PASS, 0 failures.
- 3 UI tests: PASS, 0 failures; launch/demo navigation and light/dark screenshot attachments.
- xcodebuild final result: **TEST SUCCEEDED**.
- Results retained in the `ios-test-results` artifact (`TestResults.xcresult`).

Regression coverage includes OAuth callback validation, form encoding, scope gates, message retry identity, comment reply edit/delete counts, and cancellation of debounced search. Music capability tests concern the unavailable VK catalog; imported local audio playback is implemented separately.

## Local checks: PASS

49 Swift source/test files parsed; only the tree-sitter limitation at valid `Result<Void>.success(())` remains. Compiler acceptance is confirmed by CI. Project/workflow YAML, Info.plist, privacy manifest and entitlements parse; shell syntax and git diff --check pass.

## NOT RUN

Real VK OAuth/API acceptance with approved application scopes; physical-device APNs delivery and provisioning; licensed VK music streams; native incoming VK calls; audio interruption/AirPlay device QA; full accessibility and performance matrix. CI uses demo fixtures and does not prove availability of VK rights.

Earlier main runs failed due to fixture closures without return and an unsupported multi-variable Observable declaration. These were fixed. Router destination types were simplified; CI now compiles files separately with timing diagnostics.
