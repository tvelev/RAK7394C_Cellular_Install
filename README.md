# RAK2013 Cellular PPP Installer (EG95 / Raspberry Pi / CM4)

Installation script for **RAK2013 Cellular Pi HAT** over UART on Raspberry Pi and CM4(RAK314/RAK7394C) platforms.

---

## Features

- GPIO modem power control
- Automatic PPP cellular connection
- SIM PIN unlock support
- APN configuration after installation
- Automatic reconnect on connection loss

---

## Installation

Clone repository:
```bash
git clone https://github.com/tvelev/RAK7394C_Cellular_Install.git
```
Navigate to the folder
```bash
cd RAK7394C_Cellular_Install
```
Start the installation:
```bash
sudo ./install.sh 
```

Configuration File:
```bas
/etc/rak2013/cellular.conf 
```

Example of the configuration:
```bash
APN=internet.provider.com 
PIN=1234
TTY=ttyS0 
SPEED=115200 
PPP_PEER=gprs 
```
Usually only the APN and PIN need to be provided/changed. 

Change APN and PIN in configuration: 
```bash
sudo nano /etc/rak2013/cellular.conf 
```
Restart the PPP service after every change in the config file:
```bash
sudo systemctl restart rak2013-ppp 
```

Services: 
Enable modem: 
```bash
sudo systemctl start rak2013-enable 
```
PPP Service:
```bash
sudo systemctl start rak2013-ppp 
```
Logs: 
```bash
journalctl -u rak2013-ppp -f 
```
Verify: 
```bash
ip a show ppp0 
ip route 
ping -I ppp0 google.com 
```
Troubleshooting: 
```bash
journalctl -u rak2013-ppp -n 100 
microcom /dev/ttyS0 
```
