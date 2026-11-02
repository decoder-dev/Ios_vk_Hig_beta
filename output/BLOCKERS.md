# Remaining requirements — version without push

- **Selected scope:** push notifications/APNs are explicitly excluded by the user. There is no push-entitlement/provider delivery gate for this version.
- **Validation:** current source 8545072, run 41521893697, Xcode 27/iOS 27 compilation and 33 unit tests: PASS. Earlier UI source a134aea passed 5 UI tests with 17 inspected screenshots. The latest removal of push/settings has not had a new full UI/device pass.
- **VK application rights:** callback vkhig://vkid, bundle ID com.decoderdev.vkhig and approved scopes must match the VK cabinet. Default scope is identity only. The cabinet is blocked by this environment's browser site-safety policy; its configuration has not been changed.
- **Music:** grant-gated audio.get and the native player are implemented. Approval of audio access and licensed streams for this application remains unverified.
- **Native incoming calls:** conference-link calling is implemented through documented adapters. The official VK iOS calling SDK/package, auth/signaling contract and application permission have not been supplied. Native incoming media is not implemented or claimed.
- **Account/device/UI:** real OAuth/API acceptance, physical-device camera/location/uploads, VoiceOver/Reduce Motion, AirPlay/audio interruptions, performance and full screen/state coverage remain unverified.
- **Voice recording:** OGG file import/upload and received voice playback are implemented; native recording/OGG encoding is not included.

See docs/DEVICE_AND_VK_ACCEPTANCE.md. Normal app signing is needed to install on a physical device; APNs keys/provisioning/provider setup are no longer requested.
