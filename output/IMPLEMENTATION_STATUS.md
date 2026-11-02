# Implementation status — 2026-11-02

Base audited: main @ da368e08a1e455bcd1aa97b7b826efed81058339.
Status means source implementation, NOT verified production/API availability.

| Screens | Source implementation | Remaining acceptance |
|---|---|---|
| S01–S02 | ASWebAuthenticationSession; public OAuth 2.1; state validation; S256 PKCE; Keychain; serialized refresh; logout | Register callback and app settings; real device/account smoke |
| S03 | Existing onboarding and demo entry | Visual/accessibility QA |
| S04–S05 | Live feed repository; next_from pagination; deduplication; actual media; detail; likes and link copy | Approved scopes; real API QA; richer attachments |
| S06–S07 | Live comment read/send/reply; post publish; persistent text draft | Wall attachment upload; threads pagination; scopes |
| S08–S09 | Live inbox/history/send; offset pages; stable identities; pending/failed; persisted outbox/drafts; retry same random_id; active foreground refresh | Long Poll; full attachment rendering; read receipts; live account tests |
| S10–S11 | Group chat route; info validation; navigation | Full live participants/details/admin controls |
| S12 | PhotosPicker/fileImporter; documented photo/doc upload/save/send; size limit; retry send identity | Camera/location; live upload smoke |
| S13–S14 | Copy/reply/forward/delete-confirmation/retry; peer-scoped live search | Edit; multiple recipient picker pagination; live permission checks |
| S15–S22 | Live adapters for user/profile/friends/groups/members/requests; friend add/accept; basic profile save | Outgoing requests; community wall; remaining forms; API grants |
| S23–S25 | Debounced/cancellable live users/groups search; notifications adapter; services routing | Post search; notification target navigation/read state; large lists pagination |
| S26–S30 | Albums; album photos; getAll; thumbnails/full-size; AVKit direct approved stream or official web player | Pagination beyond first 100; image memory profiling; playback QA |
| S31–S33 | Explicit unavailable state and demo library | Official audio rights required |
| S34–S39 | Local theme; system notification permission; actual cache size/clear; session logout; capability diagnostics; official VK privacy link | Push backend; server privacy APIs; autoload policy wiring |
| S40 | fave.get adapter and list | Item-specific routing/mutations |
| S41–S42 | Demo-only stories; disabled calling | Official capability/SDK integration required |
| S43–S44 | Existing error/action demos; request errors/retry on live paths | Full state matrix and accessibility verification |

## Build and validation

Linux: no Xcode/Simulator. Swift parsed with tree-sitter; project/workflow YAML and resource plists parsed; shell syntax/config generation checked; git diff --check checked. These are NOT an iOS compile.

A macOS CI workflow now generates the project, builds/tests it and retains only test results. Unit regression cases cover callback forgery/duplicates, form encoding, scope gating and retry identity. UI tests cover launch/demo navigation and light/dark screenshots. See TEST_RESULTS.md for actual results.
