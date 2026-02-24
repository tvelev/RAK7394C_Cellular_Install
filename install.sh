#!/usr/bin/env bash
set -euo pipefail

if [ "${UID}" -ne 0 ]; then
  echo "ERROR: run with sudo"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="/opt/RAKLTE"
RAK_PPPD_DST="${INSTALL_DIR}/rak_pppd"

TTY_DEV="${TTY_DEV:-ttyS0}"
TTY_SPEED="${TTY_SPEED:-115200}"
PPP_PEER="${PPP_PEER:-gprs}"

echo "== RAK2013 Cellular Installer =="
echo "Repo: ${SCRIPT_DIR}"
echo "TTY: /dev/${TTY_DEV} @ ${TTY_SPEED}"
echo

echo "[1/7] Installing dependencies..."
#apt-get update -y || true
apt-get install -y git libi2c-dev minicom dialog ppp modemmanager udev

#echo
#read -r -p "Cellular provider APN name (e.g. internet.vivacom.bg): " APN_NAME

echo "[2/7] Installing scripts..."
install -m 0755 "${SCRIPT_DIR}/files/bin/rak2013_enable.sh" /usr/local/bin/rak2013_enable.sh
install -m 0755 "${SCRIPT_DIR}/files/bin/rak2013_ppp_start.sh" /usr/local/bin/rak2013_ppp_start.sh

# Safety: strip CRLF if someone edited on Windows
sed -i 's/\r$//' /usr/local/bin/rak2013_enable.sh /usr/local/bin/rak2013_ppp_start.sh

echo "[3/7] Installing udev rule (ModemManager ignore ttyS0)..."
install -m 0644 "${SCRIPT_DIR}/files/udev/77-mm-ignore-ttyS0.rules" /etc/udev/rules.d/77-mm-ignore-ttyS0.rules
sed -i 's/\r$//' /etc/udev/rules.d/77-mm-ignore-ttyS0.rules

udevadm control --reload-rules
udevadm trigger || true
systemctl restart ModemManager || true

echo "[4/7] Installing systemd services..."
install -m 0644 "${SCRIPT_DIR}/files/systemd/rak2013-enable.service" /etc/systemd/system/rak2013-enable.service
install -m 0644 "${SCRIPT_DIR}/files/systemd/rak2013-ppp.service" /etc/systemd/system/rak2013-ppp.service
sed -i 's/\r$//' /etc/systemd/system/rak2013-enable.service /etc/systemd/system/rak2013-ppp.service

systemctl daemon-reload

echo "[5/7] Installing /opt/RAKLTE/rak_pppd (if present in repo)..."
mkdir -p "${INSTALL_DIR}"
if [ -d "${SCRIPT_DIR}/rak_pppd" ]; then
  rm -rf "${RAK_PPPD_DST}"
  cp -a "${SCRIPT_DIR}/rak_pppd" "${RAK_PPPD_DST}"
  echo "Copied rak_pppd -> ${RAK_PPPD_DST}"
else
  echo "WARN: ${SCRIPT_DIR}/rak_pppd not found; skipping copy."
fi

echo "[6/7] Generating PPP config via ppp-creator.sh (if available)..."
if [ -x "${RAK_PPPD_DST}/ppp-creator.sh" ]; then
  "${RAK_PPPD_DST}/ppp-creator.sh" "${APN_NAME}" "${TTY_DEV}" "${TTY_SPEED}"
  echo "Generated /etc/ppp/peers/${PPP_PEER} and chatscripts."
else
  echo "WARN: ${RAK_PPPD_DST}/ppp-creator.sh not executable/found. Ensure /etc/ppp/peers/${PPP_PEER} exists."
fi

chmod 755 "${RAK_PPPD_DST}"/*.sh 2>/dev/null || true
chmod 755 "${RAK_PPPD_DST}"/wait_pi_hat_and_ppp 2>/dev/null || true
sed -i 's/\r$//' "${RAK_PPPD_DST}"/*.sh 2>/dev/null || true

mkdir -p /etc/rak2013

if [ ! -f /etc/rak2013/cellular.conf ]; then

cat <<EOF >/etc/rak2013/cellular.conf
# RAK2013 Cellular configuration

APN=
PIN=
TTY=ttyS0
SPEED=115200
PPP_PEER=gprs

EOF

chmod 600 /etc/rak2013/cellular.conf

fi
echo "[7/7] Enabling + starting services..."
systemctl enable rak2013-enable.service
systemctl enable rak2013-ppp.service

systemctl restart rak2013-enable.service
systemctl restart rak2013-ppp.service

echo
echo "Done."
echo "Check:"
echo "  systemctl status rak2013-enable.service --no-pager"
echo "  systemctl status rak2013-ppp.service --no-pager"
echo "  journalctl -u rak2013-ppp.service -f"
echo "  ip a show ppp0"