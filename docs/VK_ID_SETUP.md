# VK ID setup (Jessica)

## GitHub Actions repository secrets

In GitHub → **Settings → Secrets and variables → Actions**, create:

| Secret name | Purpose |
|---|---|
| `VK_ID_CLIENT_ID` | Public VK ID app / client id (safe to inject into the iOS app Info.plist) |
| `VK_ID_CLIENT_SECRET` | Secure key — **CI/backend only**; do **not** embed in the iOS binary |

The Cloud Agent token cannot create these (API 403). Add them in the GitHub UI if missing.

Verify names only:

```bash
gh secret list --repo decoder-dev/Ios_vk_Hig_beta
```

## Local Mac (`Secrets.xcconfig`, gitignored)

```bash
cp VKHIG/Config/Secrets.example.xcconfig VKHIG/Config/Secrets.xcconfig
# fill VK_CLIENT_ID / VK_ID_CLIENT_SECRET
# or: export VK_ID_CLIENT_ID=… VK_ID_CLIENT_SECRET=… && ./scripts/write_secrets_xcconfig.sh
```

`Shared.xcconfig` `#include? "Secrets.xcconfig"` so Xcode expands `$(VK_CLIENT_ID)` into Info.plist.

## Redirect URI to register in VK ID cabinet

- Redirect URI: **`https://com.decoderdev.vkhig`** (`VK_REDIRECT_SCHEME = https`, `VK_REDIRECT_HOST = com.decoderdev.vkhig` in `Shared.xcconfig`)
- It is not a domain the app owns, so ASWebAuthenticationSession cannot return to it. With an https redirect the
  app shows the official VK ID page in `VKIDWebLoginController` (WKWebView) and intercepts the final navigation to
  that address. A custom-scheme redirect such as `vkhig://vkid` (`VK_REDIRECT_SCHEME = vkhig`, `VK_REDIRECT_HOST = vkid`)
  still uses ASWebAuthenticationSession.

## Auth model

Prefer **VK ID OAuth 2.1 + PKCE** (public client). Ship only the client id in the app. Keep the secure key out of the binary; use it only if a confidential server-side exchange is required.

Then add the official SPM package: https://github.com/VKCOM/vkid-ios-sdk
