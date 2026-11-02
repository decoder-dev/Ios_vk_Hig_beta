# IMPLEMENTATION STATUS — VK HIG

**Updated:** 2026-11-02 · Branch **`main`**  
Build/tests: **NOT RUN** (Linux).

## Credentials wiring (no secrets in git)

| Item | Status |
|---|---|
| GitHub Actions secret names | `VK_ID_CLIENT_ID`, `VK_ID_CLIENT_SECRET` (set in GitHub UI — agent API 403) |
| Local `VKHIG/Config/Secrets.xcconfig` | gitignored; present on agent disk for Mac copy, **not committed** |
| `Secrets.example.xcconfig` / `docs/VK_ID_SETUP.md` | placeholders + instructions only |
| Info.plist | `$(VK_CLIENT_ID)` / scheme `vkhig` → redirect **`vkhig://vkid`** |
| App binary | reads **client id only** via `AppSecrets`; secret not loaded in Swift |
| Live API stubs | repositories accept token via `LiveAPIGate`; honest `.notAuthenticated` / capability errors |
| CI | `.github/workflows/ios-secrets-config.yml` materializes xcconfig **without logging values** |

## Screens S01–S44

See prior matrix: all `UI_DONE` with fixtures. Live path activates only when client id configured **and** Keychain token present **and** feature in `verifiedLiveFeatures`.

## Auth

- `VKIDAuthCoordinator` uses configured client id + `vkhig://vkid`
- Still returns `.sdkNotLinked` until VKID SPM is added on Mac
