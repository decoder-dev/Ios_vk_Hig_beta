#!/usr/bin/env bash
# Materialize gitignored Secrets.xcconfig from environment.
# Expected env (from GitHub Actions secrets or local export):
#   VK_ID_CLIENT_ID
#   VK_ID_CLIENT_SECRET
# Does not echo secret values.
set -euo pipefail

OUT="${1:-VKHIG/Config/Secrets.xcconfig}"

if [[ -z "${VK_ID_CLIENT_ID:-}" || -z "${VK_ID_CLIENT_SECRET:-}" ]]; then
  echo "VK_ID_CLIENT_ID and VK_ID_CLIENT_SECRET must be set in the environment" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
umask 077
cat > "$OUT" <<EOF
// Generated — do not commit. Client secret is for CI/backend only (not for Info.plist).
VK_CLIENT_ID = ${VK_ID_CLIENT_ID}
VK_ID_CLIENT_ID = ${VK_ID_CLIENT_ID}
VK_REDIRECT_SCHEME = vkhig
VK_API_VERSION = 5.199
VK_CLIENT_SECRET = ${VK_ID_CLIENT_SECRET}
VK_ID_CLIENT_SECRET = ${VK_ID_CLIENT_SECRET}
EOF

echo "Wrote $OUT (contents redacted)"
