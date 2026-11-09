# Implementation status — 2026-11-02

Branch: main. New commits: decoder-dev. Source implementation does not imply VK application rights or production acceptance.

| Screens | Implemented source paths | Remaining acceptance |
|---|---|---|
| S01–S03 | Public OAuth 2.1/PKCE, state validation, Keychain, serialized refresh, logout, onboarding and labeled demo | Approved callback/scopes; real account/device |
| S04–S07 | Paged live feed/posts; likes; post creation/photo upload; root comments and independently paged reply threads; send/reply/edit/delete/drafts; rich attachment rendering | Real permissions, payloads and mutation smoke |
| S08–S14 | Paged inbox/history/search; foreground Long Poll/read receipts; outbox/drafts and stable retry random_id; replies/forwards with quotes; paged recipient picker; ACL-aware chat rename/invite/remove/leave/pin/unpin | Real account, chat ACL and upload checks |
| S12 media | Shared photo/document/video/audio/voice/sticker/link/graffiti rendering; camera/photo/document/video/OGG voice-file uploads and coordinate sending; unsupported formats remain visible | Real camera/location/uploads; no native OGG recorder is implemented |
| S15–S22 | Profiles/friends/requests/community wall; personal/profile fields with official country/city/partner IDs; community join/leave/settings/members/moderation/manager roles | Real granted APIs and administrator accounts |
| S23–S25 | Debounced/cancellable people/community/post search; paged friend and peer-message search; notifications with targets/read marking | Real search and notification payloads |
| S26–S30 | Paged albums/photos/videos; full-size photo viewer; AVKit approved stream or official VK player | Device playback, memory/performance |
| S31–S33 | Local audio import/library/queue/seek/shuffle/repeat/AirPlay/Now Playing; paged audio.get catalog and transient remote queue only with actual audio grant and VK-provided HTTPS stream | VK music approval and licensed streams; real audio interruption/AirPlay checks |
| S34–S39 | Theme/cache/logout; read-only VK account diagnostics; push explicitly excluded from current scope | Normal app signing and device/account checks; no APNs/provider gate |
| S40 | Paged typed saved items; link/post/video/page addition; supported post/video/product/article/page/link removal with server confirmation | Real bookmark API acceptance |
| S41 | Live stories.get/getById list and image/video viewer, expiry/visibility checks and safe links; labeled demo remains separate | Real Stories grants and media |
| S42 | calls.start/forceFinish and official conference join/share links | Native incoming media needs supplied official VK SDK/docs/access |
| S43–S44 | Loading/empty/error/retry, confirmation dialogs and action demos | Complete state matrix, VoiceOver and physical-device QA |

## Verification

Source 6c02f89 passed compilation/tests on iOS 18/Xcode 16.4 and iOS 27/Xcode 27 (run 41506365100). A screenshot-detected large-text inbox pagination overlap was corrected in 3b77c51. Source a134aea then passed all 33 unit and 5 UI tests on iOS 27 (run 41509033714); all 17 screenshots were inspected again. Final source 33846a3 additionally rejects stale user/location-picker pages after query changes; its focused Xcode 27/iOS 27 compilation and all 33 unit tests passed in run 41511022163.

See TEST_RESULTS.md for exact results and docs/DEVICE_AND_VK_ACCEPTANCE.md for real-account, signed-device and SDK requirements. No full release-readiness claim is made.

## Current scope — notifications excluded

By user instruction on 02.11.2026, this release has no push notification permission request, APNs/VK registration, push routing, settings toggle, signing entitlement or remote-notification background mode. Launch cleanup unregisters previous local registration and removes this app's pending/delivered notifications. APNs credentials and provider configuration are not release requirements. The direct APNs diagnostic sender and its tests were removed. Normal app signing is still required for physical-device installation.

Current source 8545072 passed Xcode 27/iOS 27 compilation and all 33 unit tests (0 failures) in run 41521893697, job 125539754736. Earlier successful results refer to their recorded source commits. Music rights and native incoming-call SDK/access remain unprovided. VK ID cabinet access is denied by this environment's browser site-safety policy.


## PrivateMusic2 adaptation (validation pending)
Native music module added using PrivateMusic2 @ 68d10a9 as a behavioral reference:
local playlists, persistent paused queue, global mini-player, account-isolated direct-file downloads,
LRC/LRCLIB lyrics and a real local ten-band equalizer. See docs/MUSIC_ADAPTATION.md for precise scope.
New simulator build/unit/UI checks: NOT RUN yet. Live VK music approval and device audio checks:
NOT RUN. Calls deferred; push remains disabled.

## Multi-account auth (validation pending)
Added `VKHIG/Accounts` + `Features/Auth/MultiAccount`: Keychain multi-account storage, request adapter with error-5 handling,
password grant (2FA/captcha), WKWebView flow, token paste, QR scanner, `AccountManager`, `VKSession` bridge, account switcher in
Settings. Wired into `AppEnvironment`/`SessionStore`/token provider. Build, unit tests (`VKAccountsTests`) and live VK checks: NOT RUN
(no Swift toolchain in authoring environment).

## Password-grant hardening (validation pending)
`AuthModels.swift` (full `VKLoginResponseDTO`, `VKAccountType` x5, ecosystem OTP DTOs), `VKDeviceIdentity`/
`TrustedHashStore` (device_id + trusted_hash, survives sign-out), `sig` MD5 signing in `VKAPISession.call`,
transparent error 14/17 retry via `VKChallengeResolving` (not wired to any UI yet), `VKQRLoginService`
(auth.processAuthCode confirm flow) + `QRConfirmLoginView`. `VKAccount.accountType` now drives both
User-Agent and `sig` for every call made with that account, fixing Kate/Android/iOS/VK Me/VK Admin tokens
being treated as a generic "official" session after login. Build, tests, device/live-VK checks: NOT RUN.
Declined: WebView captcha bypass with CoreMotion sensor spoofing (bot-detection evasion).

## Board alignment — design/boards (validation pending)
Screens restyled to `design/boards/01–04`: shared components in `DesignSystem/HIGComponents.swift`
(filter chips, pill segments, unread badge, section header with «Все ›», stat/action tiles, accent icon rows,
row button style without chevrons, story ring, cover background) and `VKAvatar` with real photo + online dot.
Feed (source chips Для вас/Друзья/Сообщества split by owner sign, story rings, post sections with counters/views,
share menu), inbox (chips Все/Непрочитанные/Личные/Беседы/Сообщества, mute glyph, muted badge), chat (avatar header,
inline time/delivery glyph in bubbles, capsule composer), profile (cover, avatar, counters from `users.get counters`,
education/city), settings (profile card, values, search), friends (Все/Онлайн, last seen, message shortcut),
community (cover/verified/activity, subscribe via `groups.join`, action tiles, wall as post cards), notifications
(category chips/badges), global search (chips, grouped sections), services grid, photo grid/albums, video cards.
Live mapping now reads `photo_100/200`, `last_seen`, `push_settings`, group `cover/activity/verified`, video previews/views,
album covers and post reposts/views. Music screens and the player are not restyled yet.
Build, unit/UI tests and screenshot review: NOT RUN (no Swift toolchain in authoring environment).

## Sign-in hardening (validation pending)
- Web form (OAuth implicit): the landing page is recognised on `oauth.vk.com` and `oauth.vk.ru`, from the
  navigation policy, server redirects and committed URL; cancelled/interrupted navigations (-999, WebKit 102)
  no longer latch a failure, so the token redirect after them still signs in. Web tokens carry the Kate UA.
- Password grant: login trimmed / phone normalised; `invalid_scope` retried once with the core scope set;
  wrong 2FA code keeps the code sheet open with an error; flood/brute-force, blocked account (`ban_info`,
  restore link), security-check page (`need_validation` + `redirect_uri`) and unknown answers (VK's own text)
  each get their own message; numeric `captcha_sid` accepted; SMS is requested via `auth.validatePhone` as soon
  as VK asks for `2fa_sms`, with a resend countdown; call-reset/e-mail code hints; web-form fallback link.
- A token VK issued is kept even if the follow-up `users.get` fails (network/captcha): the account is saved
  under the granted user id and its profile refreshed later. `sig` failures (error 4) retry unsigned.
- Error 5 from one method no longer deletes the account: the token is re-checked with `users.get` first and
  only a confirmed revocation signs out, with a notice on the sign-in screen.
- Data calls (`VKAPIClient`) send the account client's User-Agent and handle error 14 (captcha) / 17
  (validation) through `VKChallengeCenter` sheets, retrying the call once.
- Granted scopes: one retry, then the last answer VK gave for this account (never a guessed set).
Unit tests added in `VKAccountsTests`. Build, tests and live VK sign-in: NOT RUN.
