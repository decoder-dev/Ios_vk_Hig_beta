# VK ID setup (Jessica)

## Client ID in CI

The public client ID (`54879294`) is committed: `scripts/write_secrets_xcconfig.sh` writes it into
`Secrets.xcconfig` and the redirect scheme `vk54879294` is derived from it. CI no longer reads the
`VK_ID_CLIENT_ID` repository secret, which held a stale ID. No secret is needed: the app uses the
public PKCE flow and never ships the VK client secret.

## Local Mac (`Secrets.xcconfig`, gitignored)

```bash
cp VKHIG/Config/Secrets.example.xcconfig VKHIG/Config/Secrets.xcconfig
# fill VK_CLIENT_ID / VK_ID_CLIENT_SECRET
# or: export VK_ID_CLIENT_ID=… VK_ID_CLIENT_SECRET=… && ./scripts/write_secrets_xcconfig.sh
```

`Shared.xcconfig` `#include? "Secrets.xcconfig"` so Xcode expands `$(VK_CLIENT_ID)` into Info.plist.

## Redirect URI to register in VK ID cabinet

- Redirect URI: **`vk<client id>://vk.com/blank.html`**, currently `vk54879294://vk.com/blank.html`
  (`VK_REDIRECT_SCHEME = vk$(VK_CLIENT_ID)`, `VK_REDIRECT_HOST = vk.com`, `VK_REDIRECT_PATH = /blank.html`).
  VK ID accepts it for iOS apps without cabinet setup; the scheme is registered in `Info.plist` from the same setting.
  Checked against id.vk.ru/authorize for app 54879294: `https://com.decoderdev.vkhig` and `vkhig://vkid` were rejected
  with `redirect_uri is missing or invalid`, `vk54879294://vk.com/blank.html` opened the login form.
- Custom-scheme redirects use ASWebAuthenticationSession. If an https redirect is ever configured, the app falls back
  to `VKIDWebLoginController` (WKWebView), which intercepts the final navigation to that address.

## Auth model

Prefer **VK ID OAuth 2.1 + PKCE** (public client). Ship only the client id in the app. Keep the secure key out of the binary; use it only if a confidential server-side exchange is required.

Then add the official SPM package: https://github.com/VKCOM/vkid-ios-sdk
