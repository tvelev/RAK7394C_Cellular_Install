[Unit]
Description=RAK2013 Cellular PPP Connection
Requires=rak2013-enable.service
After=rak2013-enable.service network.target
Wants=network.target

[Service]
Type=simple
ExecStartPre=/usr/local/bin/rak2013_ppp_prepare.sh
ExecStart=/usr/local/bin/rak2013_ppp_start.sh /dev/ttyS0 115200 gprs
ExecStop=/usr/bin/pkill pppd
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
