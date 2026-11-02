#!/usr/bin/env bash
set -euo pipefail
OUT="${1:-VKHIG/Config/Secrets.xcconfig}"
CLIENT_ID="${VK_ID_CLIENT_ID:-54707652}"
[[ "$CLIENT_ID" =~ ^[0-9]+$ ]] || { echo 'Invalid public client ID' >&2; exit 1; }
mkdir -p "$(dirname "$OUT")"
umask 077
cat > "$OUT" <<EOF
// Public application configuration. No client secret is used by this iOS public client.
VK_CLIENT_ID = $CLIENT_ID
VK_ID_CLIENT_ID = $CLIENT_ID
VK_REDIRECT_SCHEME = vkhig
VK_API_VERSION = 5.199
EOF
echo 'Public configuration written'
