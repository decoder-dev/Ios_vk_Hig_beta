# API CAPABILITIES — VK HIG

Statuses: `ENABLED`, `NEEDS_PERMISSION`, `NEEDS_CONFIG`, `UNAVAILABLE`, `BLOCKED`, `UNKNOWN`.  
Live HTTP against VK: **NOT RUN** (no VK ID app credentials; Linux agent).

| Screen / Feature | Method / SDK | Permission & app type | Actual test | Status | Evidence |
|---|---|---|---|---|---|
| S01/S02 Sign-in | VK ID iOS SDK (OAuth 2.1 + PKCE) | Own VK ID app required | NOT RUN | NEEDS_CONFIG | `VKIDAuthCoordinator` returns `.missingCredentials` / `.sdkNotLinked`; no password UI |
| Session storage | Keychain | N/A | NOT RUN on device | NEEDS_CONFIG | `KeychainTokenStore` implemented; empty until live auth |
| S08 Inbox | `messages.getConversations` | Scope + app type unverified | NOT RUN | NEEDS_CONFIG | Fixture path via `ConversationRepository`; live gated |
| S09 History | `messages.getHistory` | Scope unverified | NOT RUN | NEEDS_CONFIG | Fixture history + pending local compose |
| S09 Send | `messages.send` + `random_id` | Scope unverified | NOT RUN | NEEDS_CONFIG | Enqueue stays `.pending` in fixtures — **no fake ACK** |
| S04 Feed | `newsfeed.get` / `wall.get` | Scope unverified | NOT RUN | NEEDS_CONFIG | Fixture posts + orange banner |
| S15 Profile | `users.get` | Scope unverified | NOT RUN | NEEDS_CONFIG | Fixture profile labeled |
| Friends / Communities / Photos | `friends.get` / `groups.get` / `photos.get` | Unverified | NOT RUN | NEEDS_CONFIG | Services list placeholders only |
| Music | Official audio / licensed streams | Likely unavailable for 3p apps | NOT RUN | UNAVAILABLE | `MusicPlaceholderView` + capability `.unavailable` |
| Video / Calls / Stories | Official APIs TBD | Unverified | NOT RUN | UNKNOWN / UNAVAILABLE | Not implemented; no fake success |

## Transport sketch

- `VKAPIClient` actor: POST `https://api.vk.com/method/<method>` with token in body (never logged).
- **Not invoked** from UI repositories until `CapabilityRegistry.verifiedLiveFeatures` is non-empty and a Keychain token exists.

## Credentials required from Jessica

1. VK ID **client/app id**
2. Redirect URI / URL scheme
3. Confirmation of granted scopes (especially `messages`, newsfeed/wall, friends)
4. Decision to add SPM package `https://github.com/VKCOM/vkid-ios-sdk`
