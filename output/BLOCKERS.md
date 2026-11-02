# Remaining requirements

- **Validation:** feature source 6c02f89 passed iOS 18 and 27 CI. UI source a134aea passed 33 unit + 5 UI tests on iOS 27 after the large-text inbox fix; 17 screenshots were inspected. Final stale-response guards in 33846a3 also passed focused compilation and all 33 unit tests in run 41511022163. See TEST_RESULTS.md.
- **VK configuration:** callback vkhig://vkid, bundle ID com.decoderdev.vkhig and approved scopes must match the application cabinet. Default grant is identity only. Real OAuth/API acceptance has not been performed here.
- **Music:** the grant-gated audio.get catalog and native player are implemented. VK must approve music access and provide licensed streams.
- **Native incoming calls:** conference-link calls are implemented. An official VK calling SDK/package, documentation and application authorization have not been supplied; native incoming media is not implemented or claimed.
- **Device/UI:** physical-device camera/location/uploads, VoiceOver/Reduce Motion, audio interruptions/AirPlay, performance and the complete screen/state matrix remain unverified. Simulator screenshots are demo fixtures and do not prove live API behavior.
- **Voice recording:** OGG voice-file import/upload and received voice playback are implemented; recording/encoding a new native OGG voice message is not included.

Run signed-device and real-account acceptance using docs/DEVICE_AND_VK_ACCEPTANCE.md and scripts/device-smoke.sh. Secrets/certificates/profiles must not be committed.

## Current scope: no push notifications
On 02.11.2026 the user explicitly excluded notifications/APNs. Removed runtime permission requests, APNs/VK device registration, push routes, the settings toggle, signing entitlement and remote-notification background mode. Launch cleanup unregisters any previous local registration and removes this app's pending/delivered notifications. Removed the APNs diagnostic sender and its tests; device-smoke.sh now needs only normal app signing. Apple login/provider setup is no longer required for the selected scope. Music rights and native incoming-call SDK/access remain external VK dependencies; VK ID cabinet access is denied by this environment's browser site-safety policy.

The earlier APNs revision 12dcccd passed Xcode 27 and 36 unit tests in run 41517627368; it was subsequently removed by the scope change. Current no-push revision returns to 33 unit tests; compilation/regression run PENDING. Previous PASS results apply to their recorded commits.
