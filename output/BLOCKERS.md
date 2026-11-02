# Blockers

- **Release gate:** actual iOS build, XCTest/UI results and device smoke must be verified in CI/macOS. Linux cannot run Xcode.
- **VK app configuration:** callback `vkhig://vkid`, bundle id and approved scopes must match VK ID cabinet. Default grant is identity only. No code can turn client secret into messaging/music rights.
- **API acceptance:** adapters follow public VK schemas, but no user OAuth token is available here; successful real calls are NOT claimed.
- **Still incomplete:** full comment threads, additional chat attachment formats, advanced community admin, post search, notification routing, large catalog pagination, full accessibility/performance matrix.
- **External capabilities:** music streams, VK calling and push service need official rights/SDK/backend. They remain unavailable rather than simulated.
- **Design:** no claim of pixel-perfect iOS 27 validation without simulator/device screenshots.
- **Secrets:** both user-requested Actions secrets were saved. Client secret is never consumed/exported by the iOS workflow. Public OAuth uses client ID and PKCE.
