# Implementation status — 2026-11-02

Development branch: main. New commits use the decoder-dev account.
Status means source implementation, NOT verified production/API availability.

| Screens | Source implementation | Remaining acceptance |
|---|---|---|
| S01–S02 | ASWebAuthenticationSession; public OAuth 2.1; state validation; S256 PKCE; Keychain; serialized refresh; logout | Register callback and app settings; real device/account smoke |
| S03 | Existing onboarding and demo entry | Visual/accessibility QA |
| S04–S05 | Live feed repository; next_from pagination; deduplication; actual media; detail; likes and link copy | Approved scopes; real API QA; richer attachments |
| S06–S07 | Root comment pagination; independently paged reply threads; read/send/reply/edit/delete; persistent drafts; post photo upload | Real account acceptance; rich comment attachments; scopes |
| S08–S09 | Live inbox/history/send; offset pages; stable identities; pending/failed; persisted outbox/drafts; retry same random_id; foreground Long Poll, read receipts and photo/document rendering | Full rich attachment coverage; live account tests |
| S10–S11 | Group chat route; live participant/details loading; navigation | Advanced group administration controls |
| S12 | PhotosPicker/fileImporter; documented photo/doc upload/save/send; size limit; retry send identity | Camera/location; live upload smoke |
| S13–S14 | Copy/reply/edit/forward/delete-confirmation/retry; peer-scoped live search with offset pages and server-ID deduplication | Recipient picker pagination; live permission checks |
| S15–S22 | Live adapters including server-side friends.search and paged results for user/profile/friends/groups/members/requests; incoming/outgoing requests; friend add/accept; basic profile save; community wall | Remaining profile fields; advanced community admin; API grants |
| S23–S25 | Debounced/cancellable users/groups/newsfeed search; separate errors and pages; notification links/read marking | Real search and notification payload acceptance |
| S26–S30 | Albums; album photos; getAll; thumbnails/full-size; AVKit direct approved stream or official web player | Offset pagination implemented; image memory profiling and playback QA |
| S31–S33 | AVPlayer local audio import; persistent library, queue, seek, shuffle/repeat, AirPlay, Now Playing and remote commands | VK catalog/streams require approved music API; physical-device audio QA |
| S34–S39 | Theme/cache/logout; APNs delegate/token/error handling; account.registerDevice/unregisterDevice; push permission/retry/status; notification tap routes | Signed APNs provisioning and VK push-provider setup; physical-device delivery; privacy APIs |
| S40 | Paged fave.get with post/photo/video/link targets | Mutations and API acceptance |
| S41–S42 | Stories demo; calls.start conference creation, join/share official link, calls.forceFinish | Native incoming calls/media require an official SDK/access; real call QA |
| S43–S44 | Existing error/action demos; request errors/retry on live paths | Full state matrix and accessibility verification |

## Build and validation

Linux: no Xcode/Simulator. Swift parsed with tree-sitter; project/workflow YAML and resource plists parsed; shell syntax/config generation checked; git diff --check checked. These are NOT an iOS compile.

A macOS CI workflow now generates the project, builds/tests it and retains only test results. Unit regression cases cover callback forgery/duplicates, form encoding, scope gating and retry identity. UI tests cover launch/demo navigation and light/dark screenshots. See TEST_RESULTS.md for actual results.

## Verified simulator result

Source main @ 774b58efd6505eac280c44e5a98e13972ded349d: macOS CI build + 17 unit tests + 3 UI tests PASS (0 failures). Run 41496009543. This confirms simulator compilation and fixture regression paths; real API grants, APNs delivery and physical-device acceptance remain open.

## Remaining-feature revision (awaiting CI)
- S04–S09: shared photo/document/video/audio/voice/sticker/link/graffiti rendering; bounded reply/forward quotes.
- S10–S14: ACL-aware chat rename, invite/remove/leave, pin/unpin; paged recipient picker; camera, coordinate, video and OGG voice-file sending.
- S15–S22: profile country/city/partner and personal fields; community membership, settings, paged members and manager roles.
- S31–S33: grant-gated VK audio.get catalog with transient playback queue. Actual licensed stream access still requires VK approval.
- S40: paged typed saved items, add links/posts/pages and supported removal operations with confirmed server results.
- S41: live Stories list/viewer, expiry, image/video and safe links; demo remains explicitly labeled.
- CI now targets iOS 18 and iOS 27, with 33 unit tests and 5 UI tests per SDK, including large text and screenshot export. No new CI result is claimed yet.
- Physical-device/archive script and account diagnostics are provided; external acceptance is recorded in docs/DEVICE_AND_VK_ACCEPTANCE.md.

The remaining-acceptance column above describes the previous verified baseline. The source additions in this section replace its feature gaps; validation and external service requirements remain open.
