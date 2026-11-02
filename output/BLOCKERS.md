# Blockers

- **Release gate:** actual iOS build, XCTest/UI results and device smoke must be verified in CI/macOS. Linux cannot run Xcode.
- **VK app configuration:** callback `vkhig://vkid`, bundle id and approved scopes must match VK ID cabinet. Default grant is identity only. No code can turn client secret into messaging/music rights.
- **API acceptance:** adapters follow public VK schemas, but no user OAuth token is available here; successful real calls are NOT claimed.
- **Still incomplete:** rich comment/chat attachment formats, comment editing, advanced community admin, full accessibility/performance matrix. Comment threads, post search, notification targets and catalog pagination now have source implementations.
- **External capabilities:** VK music streams need approved API access. Local audio playback is implemented. Conference calls use documented calls.start/forceFinish and official join links; native incoming media needs VK SDK/access. Push client registration is implemented, but APNs provisioning/team and VK provider configuration are not supplied; delivery cannot be verified here.
- **Design:** no claim of pixel-perfect iOS 27 validation without simulator/device screenshots.
- **Secrets:** both user-requested Actions secrets were saved. Client secret is never consumed/exported by the iOS workflow. Public OAuth uses client ID and PKCE.
