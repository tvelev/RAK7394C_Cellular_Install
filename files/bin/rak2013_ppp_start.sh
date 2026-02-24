#!/bin/sh

CONFIG=/etc/rak2013/cellular.conf

if [ -f "$CONFIG" ]; then
    . "$CONFIG"
fi

set -e

TTY="${1:-/dev/ttyS0}"
SPEED="${2:-115200}"
PEER="${3:-gprs}"

# Prepare UART for EG95 so chat doesn't time out
stty -F "$TTY" "$SPEED" raw -echo -ixon -ixoff -crtscts || true

sleep 1

# Stop any stale session (ignore errors)
pkill pppd 2>/dev/null || true
sleep 1

if [ -n "$PIN" ]; then
    echo "Unlocking SIM..."

    echo -e "AT+CPIN=\"$PIN\"\r" > "$TTY"

    sleep 3
fi

# Run pppd in foreground so systemd can supervise it
exec /usr/sbin/pppd call "$PEER" nodetach