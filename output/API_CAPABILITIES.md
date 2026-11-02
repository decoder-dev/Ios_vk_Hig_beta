# API CAPABILITIES — VK HIG

Live HTTP against VK: **NOT RUN** (credentials deferred to Jessica; Linux agent).

| Feature | Candidate | Status | UI path |
|---|---|---|---|
| VK ID sign-in | VKID iOS SDK | NEEDS_CONFIG | S01/S02 placeholders |
| Inbox / chat / send | messages.* | NEEDS_CONFIG | S08–S14 fixtures; send stays pending |
| Feed / post / comments | newsfeed/wall.* | NEEDS_CONFIG | S04–S07 fixtures |
| Profile / friends / groups | users/friends/groups.* | NEEDS_CONFIG | S15–S22 fixtures |
| Search / notifications | users.search / notifications.get | NEEDS_CONFIG | S23–S24 fixtures |
| Photos | photos.* | NEEDS_CONFIG | S26–S28 placeholders |
| Video | video.* | NEEDS_CONFIG / rights | S29–S30 no illegal stream |
| Music | audio | UNAVAILABLE | S31–S33 play disabled |
| Calls | official calling SDK | UNAVAILABLE | S42 disabled |
| Stories | stories? | NEEDS_CONFIG / UNAVAIL | S41 shell |
| Bookmarks | fave.get? | NEEDS_CONFIG | S40 fixtures |

Transport: `VKAPIClient` present but not invoked from repositories until `CapabilityRegistry.verifiedLiveFeatures` is non-empty.
