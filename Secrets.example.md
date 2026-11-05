# Credentials (never commit real values)

## GitHub Actions secrets (preferred)

- `VK_ID_CLIENT_ID`
- `VK_ID_CLIENT_SECRET`

See `docs/VK_ID_SETUP.md`.

## Local file

Copy `VKHIG/Config/Secrets.example.xcconfig` → `VKHIG/Config/Secrets.xcconfig` (gitignored).

Redirect URI: `vk<client id>://vk.com/blank.html` (derived from `VK_ID_CLIENT_ID`)
