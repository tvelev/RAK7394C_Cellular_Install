#!/bin/sh
set -e

CONFIG=/etc/rak2013/cellular.conf

# Load config (APN/PIN/TTY/SPEED/PPP_PEER)
if [ -f "$CONFIG" ]; then
    . "$CONFIG"
fi

# Prefer CLI args if provided, otherwise take from config, otherwise fallback defaults
TTY="${1:-${TTY:-ttyS0}}"
SPEED="${2:-${SPEED:-115200}}"
PEER="${3:-${PPP_PEER:-gprs}}"

# Ensure TTY is a /dev path
case "$TTY" in
  /dev/*) : ;;
  *) TTY="/dev/$TTY" ;;
esac

# Wait for UART device to appear (helps after modem power toggle)
i=0
while [ ! -e "$TTY" ] && [ $i -lt 30 ]; do
  i=$((i+1))
  sleep 1
done

if [ ! -e "$TTY" ]; then
  echo "ERROR: UART device not found: $TTY"
  exit 1
fi

# Prepare UART for EG95 so chat doesn't time out
stty -F "$TTY" "$SPEED" raw -echo -ixon -ixoff -crtscts || true
sleep 1

# Stop any stale PPP session for this peer (best-effort)
pkill -f "pppd call $PEER" 2>/dev/null || true
sleep 1

# Optional SIM PIN unlock
if [ -n "${PIN:-}" ]; then
    echo "Unlocking SIM..."
    printf 'AT+CPIN="%s"\r' "$PIN" > "$TTY"
    sleep 3
fi

# Run pppd in foreground so systemd can supervise it
exec /usr/sbin/pppd call "$PEER" nodetach
