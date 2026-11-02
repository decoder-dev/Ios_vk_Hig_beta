# VK ID credentials (Jessica)

1. Copy `VKHIG/Config/Secrets.example.xcconfig` → `VKHIG/Config/Secrets.xcconfig` (gitignored).
2. Set `VK_CLIENT_ID` to your VK ID app client id.
3. Align `VK_REDIRECT_SCHEME` with VK ID console and `Info.plist` `CFBundleURLSchemes` (default `vkhig`).
4. Optionally override the same keys in `VKHIG/Resources/Info.plist` for Simulator smoke tests.
5. Add the official [VKID iOS SDK](https://github.com/VKCOM/vkid-ios-sdk) via SPM in Xcode.
6. Never commit real secrets, Fenrir/Phoenix keys, or client secrets in the binary if confidential.

Placeholders currently ship as `YOUR_VK_ID_CLIENT_ID` — the app runs the fixture UI shell without them.
