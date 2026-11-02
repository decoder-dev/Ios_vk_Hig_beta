# Unsigned IPA handoff

The `Build unsigned iOS IPA` workflow builds a Release device `.app` with Xcode 27, packages it as `Payload/VK HIG.app`, and attaches the unsigned `.ipa` to the selected GitHub prerelease. The package is useful as an input to a local re-signing workflow; it is **not installable as-is** on a stock iPhone.

## Build it

Run the GitHub Actions workflow manually on `main` with:

- `source_ref`: `v0.1.0-beta.1`
- `release_tag`: `v0.1.0-beta.1`

The workflow builds from the release tag, validates the ZIP container, publishes a 30-day Actions artifact, and uploads the IPA to the GitHub prerelease. It does not run tests or handle a private signing key.

## Re-sign for a stock iPhone

Use an Apple-issued iOS signing certificate and a matching provisioning profile. For ad hoc installation, register the target iPhone UDID in the Apple Developer account and include it in the Ad Hoc profile; Apple requires an App ID, distribution certificate, and registered devices for this distribution path. The signing certificate must match the profile and the app bundle identifier `com.decoderdev.vkhig`.

A literal self-signed certificate without an Apple-issued iOS profile is not a substitute for this chain on ordinary, non-jailbroken iOS. If your certificate is an Apple Developer certificate, a local re-sign tool/Xcode can use it with its matching profile. Never upload the `.p12` private key or its password into this repository unless you explicitly choose to move signing into GitHub Actions; the current workflow needs no signing secrets.

References: [Apple Ad Hoc provisioning profile requirements](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile), [Apple registered-device distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices).
