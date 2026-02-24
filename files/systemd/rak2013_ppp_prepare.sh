#!/usr/bin/env bash
set -euo pipefail

CONF="/etc/rak2013/cellular.conf"
RAK_PPPD="/opt/RAKLTE/rak_pppd"
CREATOR="${RAK_PPPD}/ppp-creator.sh"

# Load config
if [ -f "$CONF" ]; then
  # shellcheck disable=SC1091
  . "$CONF"
fi

APN="${APN:-}"
TTY="${TTY:-ttyS0}"
SPEED="${SPEED:-115200}"
PPP_PEER="${PPP_PEER:-gprs}"

STAMP_DIR="/var/lib/rak2013"
STAMP_FILE="${STAMP_DIR}/ppp-creator.last"
mkdir -p "$STAMP_DIR"

# If APN is not set, do NOT fail; just skip generation.
if [ -z "$APN" ]; then
  echo "INFO: APN is empty in ${CONF}. PPP config generation skipped."
  exit 0
fi

# Ensure creator exists
if [ ! -f "$CREATOR" ]; then
  echo "ERROR: ${CREATOR} not found. Cannot generate PPP config."
  exit 1
fi

# Fix perms/CRLF
chmod 755 "${RAK_PPPD}"/*.sh 2>/dev/null || true
chmod 755 "${RAK_PPPD}/wait_pi_hat_and_ppp" 2>/dev/null || true
sed -i 's/\r$//' "${RAK_PPPD}"/*.sh 2>/dev/null || true

# Only regenerate when APN/TTY/SPEED changed (or peer file missing)
NEW_KEY="APN=${APN};TTY=${TTY};SPEED=${SPEED};PEER=${PPP_PEER}"
OLD_KEY=""
if [ -f "$STAMP_FILE" ]; then
  OLD_KEY="$(cat "$STAMP_FILE" || true)"
fi

PEER_FILE="/etc/ppp/peers/${PPP_PEER}"
if [ ! -f "$PEER_FILE" ] || [ "$NEW_KEY" != "$OLD_KEY" ]; then
  echo "Generating PPP config: ${NEW_KEY}"
  "${CREATOR}" "${APN}" "${TTY}" "${SPEED}"
  echo "$NEW_KEY" > "$STAMP_FILE"
else
  echo "PPP config already up-to-date."
fi
