# Blockers

- **Release gate:** simulator build, 17 unit tests and 3 UI tests PASS at main 774b58e (run 41496009543). Physical-device smoke, real API acceptance and the full accessibility/performance matrix remain required.
- **VK app configuration:** callback `vkhig://vkid`, bundle id and approved scopes must match VK ID cabinet. Default grant is identity only. No code can turn client secret into messaging/music rights.
- **API acceptance:** adapters follow public VK schemas, but no user OAuth token is available here; successful real calls are NOT claimed.
- **New source awaiting CI:** rich attachment rendering/sending, chat and community administration, expanded profile fields, recipient pagination, saved mutations, live Stories and grant-gated audio catalog are implemented. Full accessibility/performance and real-account acceptance remain open.
- **External capabilities:** VK music streams need approved API access. Local audio playback is implemented. Conference calls use documented calls.start/forceFinish and official join links; native incoming media needs VK SDK/access. Push client registration is implemented, but APNs provisioning/team and VK provider configuration are not supplied; delivery cannot be verified here.
- **Design:** no claim of pixel-perfect iOS 27 validation without simulator/device screenshots.
- **Secrets:** both user-requested Actions secrets were saved. Client secret is never consumed/exported by the iOS workflow. Public OAuth uses client ID and PKCE.
