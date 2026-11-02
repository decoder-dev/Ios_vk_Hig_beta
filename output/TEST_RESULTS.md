# Test results

2026-11-02. Local Linux validation:

- YAML parse: project.yml and iOS workflow — PASS.
- XML plist parse: Info.plist and PrivacyInfo.xcprivacy — PASS.
- bash -n scripts/write_secrets_xcconfig.sh — PASS.
- Config generation using public client ID — PASS; no client secret read/written.
- git diff --check — PASS.
- Swift tree-sitter parse: no ERROR nodes. Parser reports a missing token at Result<Void>.success(()); this is valid Swift syntax, compiler is authoritative.
- Xcode build, XCTest, UI screenshot tests: NOT RUN locally (no Apple SDK).
- Live VK API and OAuth device smoke: NOT RUN (no user session/confirmed app scope settings).

macOS workflow: `.github/workflows/ios-secrets-config.yml`, results artifact `ios-test-results`.
Auth code follows public OAuth parameters verified against VKCOM/vkid-ios-sdk tag 3.0.0; API adapters verified against VKCOM/vk-api-schema parameter definitions. No SDK source was copied into the app.

Main integration: PR #2 merged; subsequent work committed directly to main by decoder-dev. The first main runs failed compilation (including a multi-statement fixture closure without return). Both affected loaders were fixed/replaced. New main build is queued/running; a successful compile/test is not yet claimed. Swift parser and configuration validation repeated after comments/search/audio/calls/push changes; only known Result<Void> parser limitation remains. Real APNs delivery, audio route changes and VK calling: NOT RUN.
