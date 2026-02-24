#!/usr/bin/env bash
set -euo pipefail

if [ "${UID}" -ne 0 ]; then
  echo "ERROR: run with sudo"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/opt/RAKLTE"
RAK_PPPD_DST="${INSTALL_DIR}/rak_pppd"

# Defaults (can be overridden via environment)
# On Raspberry Pi, serial0 is the stable alias for the primary UART.
TTY_DEV="${TTY_DEV:-serial0}"
TTY_SPEED="${TTY_SPEED:-115200}"
PPP_PEER="${PPP_PEER:-gprs}"

echo "== RAK2013 Cellular Installer =="
echo "Installation dir: ${SCRIPT_DIR}"
echo "TTY default: /dev/${TTY_DEV} @ ${TTY_SPEED}"
echo

echo "[1/8] Installing dependencies..."
# apt-get update -y || true
apt-get install -y git libi2c-dev minicom dialog ppp modemmanager udev

echo "[2/8] Installing scripts..."
install -m 0755 "${SCRIPT_DIR}/files/bin/rak2013_enable.sh" /usr/local/bin/rak2013_enable.sh
install -m 0755 "${SCRIPT_DIR}/files/bin/rak2013_ppp_start.sh" /usr/local/bin/rak2013_ppp_start.sh
install -m 0755 "${SCRIPT_DIR}/files/bin/rak2013_ppp_prepare.sh" /usr/local/bin/rak2013_ppp_prepare.sh

# Safety: strip CRLF if someone edited on Windows
sed -i 's/\r$//' \
  /usr/local/bin/rak2013_enable.sh \
  /usr/local/bin/rak2013_ppp_start.sh \
  /usr/local/bin/rak2013_ppp_prepare.sh

echo "[3/8] Installing udev rule (ModemManager ignore ttyS0)..."
install -m 0644 "${SCRIPT_DIR}/files/udev/77-mm-ignore-ttyS0.rules" /etc/udev/rules.d/77-mm-ignore-ttyS0.rules
sed -i 's/\r$//' /etc/udev/rules.d/77-mm-ignore-ttyS0.rules

udevadm control --reload-rules
udevadm trigger || true
systemctl restart ModemManager || true

echo "[4/8] Installing systemd services..."
install -m 0644 "${SCRIPT_DIR}/files/systemd/rak2013-enable.service" /etc/systemd/system/rak2013-enable.service
install -m 0644 "${SCRIPT_DIR}/files/systemd/rak2013-ppp.service" /etc/systemd/system/rak2013-ppp.service
sed -i 's/\r$//' /etc/systemd/system/rak2013-enable.service /etc/systemd/system/rak2013-ppp.service

systemctl daemon-reload

echo "[5/8] Configuring UART + disabling Bluetooth..."
BOOT_CONFIG="/boot/firmware/config.txt"
if [ ! -f "$BOOT_CONFIG" ]; then
  echo "WARN: $BOOT_CONFIG not found, trying legacy /boot/config.txt"
  BOOT_CONFIG="/boot/config.txt"
fi

REBOOT_NEEDED=0
if [ -f "$BOOT_CONFIG" ]; then
  if ! grep -q "^enable_uart=1" "$BOOT_CONFIG"; then
    echo "enable_uart=1" >> "$BOOT_CONFIG"
    echo "Added enable_uart=1"
    REBOOT_NEEDED=1
  else
    echo "UART already enabled"
  fi

  if ! grep -q "^dtoverlay=disable-bt" "$BOOT_CONFIG"; then
    echo "dtoverlay=disable-bt" >> "$BOOT_CONFIG"
    echo "Added dtoverlay=disable-bt"
    REBOOT_NEEDED=1
  else
    echo "Bluetooth already disabled"
  fi
else
  echo "ERROR: Cannot locate Raspberry Pi config.txt (checked /boot/firmware/config.txt and /boot/config.txt)"
fi

# Prevent getty from grabbing UART used by EG95 (serial0 -> ttyAMA0)
systemctl disable --now serial-getty@ttyAMA0.service 2>/dev/null || true
systemctl mask serial-getty@ttyAMA0.service 2>/dev/null || true
systemctl disable --now serial-getty@serial0.service 2>/dev/null || true
systemctl disable --now serial-getty@ttyS0.service 2>/dev/null || true

echo "[6/8] Creating configuration file (/etc/rak2013/cellular.conf)..."
mkdir -p /etc/rak2013
if [ ! -f /etc/rak2013/cellular.conf ]; then
  cat <<'EOF' >/etc/rak2013/cellular.conf
# RAK2013 Cellular configuration
#
# After installation:
# 1) Set APN (and optional PIN) below
# 2) Restart PPP: sudo systemctl restart rak2013-ppp

APN=
PIN=

# UART parameters
TTY=serial0
SPEED=115200

# PPP profile name (generated at /etc/ppp/peers/<PPP_PEER>)
PPP_PEER=gprs
EOF
  chmod 600 /etc/rak2013/cellular.conf
  echo "Created /etc/rak2013/cellular.conf (set APN/PIN after install)."
else
  echo "Config already exists: /etc/rak2013/cellular.conf (keeping current values)."
fi

echo "[7/8] Installing /opt/RAKLTE/rak_pppd..."
mkdir -p "${INSTALL_DIR}"
if [ -d "${SCRIPT_DIR}/rak_pppd" ]; then
  rm -rf "${RAK_PPPD_DST}"
  cp -a "${SCRIPT_DIR}/rak_pppd" "${RAK_PPPD_DST}"
  echo "Copied rak_pppd -> ${RAK_PPPD_DST}"
else
  echo "WARN: ${SCRIPT_DIR}/rak_pppd not found; skipping copy."
fi

# Make sure rak_pppd scripts are usable (needed by ExecStartPre)
chmod 755 "${RAK_PPPD_DST}"/*.sh 2>/dev/null || true
chmod 755 "${RAK_PPPD_DST}/wait_pi_hat_and_ppp" 2>/dev/null || true
sed -i 's/\r$//' "${RAK_PPPD_DST}"/*.sh 2>/dev/null || true

echo "[8/8] Enabling + starting services..."
systemctl enable rak2013-enable.service
systemctl enable rak2013-ppp.service

systemctl restart rak2013-enable.service
systemctl restart rak2013-ppp.service

echo
echo "Done."
echo
echo "Next steps:"
echo "  1) Edit APN/PIN: sudo nano /etc/rak2013/cellular.conf"
echo "  2) Restart PPP:  sudo systemctl restart rak2013-ppp"
echo
echo "Check:"
echo "  systemctl status rak2013-enable.service --no-pager"
echo "  systemctl status rak2013-ppp.service --no-pager"
echo "  journalctl -u rak2013-ppp.service -f"
echo "  ip a show ppp0"

if [ "${REBOOT_NEEDED}" -eq 1 ]; then
  echo
  echo "NOTE: UART/Bluetooth config was updated in ${BOOT_CONFIG}."
  echo "A reboot is recommended:"
  echo "  sudo reboot"
fi
