# BLOCKERS — VK HIG

| Priority | Blocker | Required input/action | Safe fallback | Status |
|---|---|---|---|---|
| P0 | No macOS/Xcode on Cloud Linux VM | Build & test on Mac (local or Cursor Mac self-hosted worker) | Code + docs only; mark build/tests `NOT RUN` | OPEN |
| P0 | VK ID app credentials missing | Jessica: register own VK ID app; provide client id + redirect/URL scheme (no Fenrir/Phoenix keys) | Auth stub + fixture UI shell | OPEN |
| P0 | VKID iOS SDK not linked | Add official SPM dependency after credentials exist | `VKIDAuthCoordinator.authorize()` → `.sdkNotLinked` | OPEN |
| P0 | messages / newsfeed scopes unverified | Confirm official scopes for this app type; update `CapabilityRegistry.verifiedLiveFeatures` | Fixture repositories with orange banner; pending sends never auto-ACK | OPEN |
| P1 | Music/video legal/API rights unknown | Official VK approval + media rights | Honest unavailable screens | OPEN |
| P1 | Fenrir/Phoenix license | Do not copy code/assets; independent Swift only | Already followed | MITIGATED |
| P2 | App icon asset | Supply 1024×1024 marketing icon | Empty AppIcon slot | OPEN |

## Non-blockers (kit defaults applied)

- Tab set: Лента / Сервисы / Сообщения / Музыка / Профиль
- Min iOS 17
- App display name: **VK HIG**
- Fixture shell entry on auth screen for UI review without credentials
