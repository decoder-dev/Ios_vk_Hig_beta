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
