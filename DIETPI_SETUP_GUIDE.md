# DietPi Setup Guide for Price Checker Kiosk

## Raspberry Pi 4 Model B Configuration

This guide will help you set up DietPi on a Raspberry Pi 4 Model B to run as a price checker kiosk with barcode scanning capabilities and WiFi configuration features.

## Prerequisites

- Raspberry Pi 4 Model B
- MicroSD card (16GB or larger, Class 10 recommended)
- USB barcode scanner
- HDMI display/monitor
- Keyboard (for initial setup)
- Ethernet connection (for initial setup)

## Step 1: Download and Flash DietPi

1. **Download DietPi**

   - Go to https://dietpi.com/#download
   - Download the latest DietPi image for Raspberry Pi 4

2. **Flash to SD Card**

   - Use Raspberry Pi Imager or Balena Etcher
   - Flash the DietPi image to your SD card

3. **Pre-configure (Optional)**
   - Mount the SD card on your computer
   - Edit `dietpi.txt` in the root directory:

     ```bash
     # Enable SSH
     AUTO_SETUP_SSH_SERVER_INDEX=1

     # Set timezone (adjust as needed)
     AUTO_SETUP_TIMEZONE=Asia/Riyadh

     # Set locale
     AUTO_SETUP_LOCALE=en_US.UTF-8
     ```

## Step 2: Initial DietPi Setup

1. **Boot the Raspberry Pi**

   - Insert SD card and boot
   - Connect via Ethernet for initial setup
   - Default login: `root` / `dietpi`

2. **Run DietPi-Config**

   ```bash
   dietpi-config
   ```

   - Navigate to `Display Options` → `Resolution` → Set appropriate resolution
   - Navigate to `Advanced Options` → `GPU Memory Split` → Set to 128MB
   - Navigate to `Network Options` → Configure WiFi if needed

3. **Update System**
   ```bash
   dietpi-update
   ```

## Step 3: Install Required Software

1. **Install Node.js and Chromium**

   ```bash
   dietpi-software
   ```

   - Select the following software IDs:
     - **ID 9**: Node.js
     - **ID 113**: Chromium
     - **ID 130**: Python 3 (if needed for additional scripts)

2. **Install additional packages**
   ```bash
   apt update
   apt install -y git unclutter xdotool
   ```

## Step 4: Setup the Price Checker Application

1. **Create application directory**

   ```bash
   mkdir -p /opt/price-checker
   cd /opt/price-checker
   ```

2. **Copy your application files**

   - Transfer `server.js`, `package.json`, and `index.html` to `/opt/price-checker/`
   - Create assets directory and copy fonts, images:

   ```bash
   mkdir -p /opt/price-checker/assets/Fonts
   # Copy your corner-logo.png, sar.png, font.otf, semibold.otf files
   ```

3. **Install Node.js dependencies**

   ```bash
   cd /opt/price-checker
   npm install
   ```

4. **Test the server**
   ```bash
   node server.js
   ```

## Step 5: Create Systemd Service for Auto-start

1. **Create service file**

   ```bash
   nano /etc/systemd/system/price-checker.service
   ```

2. **Add service configuration**

   ```ini
   [Unit]
   Description=Price Checker Kiosk Server
   After=network.target

   [Service]
   Type=simple
   User=dietpi
   WorkingDirectory=/opt/price-checker
   ExecStart=/usr/bin/node server.js
   Restart=always
   RestartSec=10
   Environment=NODE_ENV=production

   [Install]
   WantedBy=multi-user.target
   ```

3. **Enable and start service**
   ```bash
   systemctl daemon-reload
   systemctl enable price-checker
   systemctl start price-checker
   ```

## Step 6: Configure Kiosk Mode

1. **Create kiosk script**

   ```bash
   nano /opt/price-checker/start-kiosk.sh
   ```

2. **Add kiosk startup script**

   ```bash
   #!/bin/bash

   # Wait for X server to start
   sleep 5

   # Hide cursor
   unclutter -idle 0.5 -root &

   # Disable screen blanking
   xset s off
   xset -dpms
   xset s noblank

   # Start Chromium in kiosk mode
   chromium-browser \
     --noerrdialogs \
     --disable-infobars \
     --kiosk \
     --disable-session-crashed-bubble \
     --disable-restore-session-state \
     --disable-background-timer-throttling \
     --disable-backgrounding-occluded-windows \
     --disable-renderer-backgrounding \
     --disable-features=TranslateUI \
     --disable-extensions \
     --no-first-run \
     --fast \
     --fast-start \
     --disable-default-apps \
     --no-default-browser-check \
     http://localhost:8000/
   ```

3. **Make script executable**
   ```bash
   chmod +x /opt/price-checker/start-kiosk.sh
   ```

## Step 7: Auto-start Kiosk on Boot

1. **Create desktop session directory**

   ```bash
   mkdir -p /home/dietpi/.config/lxsession/LXDE
   ```

2. **Create autostart file**

   ```bash
   nano /home/dietpi/.config/lxsession/LXDE/autostart
   ```

3. **Add autostart configuration**

   ```bash
   @lxpanel --profile LXDE
   @pcmanfm --desktop --profile LXDE
   @xscreensaver -no-splash
   @/opt/price-checker/start-kiosk.sh
   ```

4. **Set ownership**
   ```bash
   chown -R dietpi:dietpi /home/dietpi/.config
   ```

## Step 8: Configure Auto-login and Desktop

1. **Enable auto-login**

   ```bash
   dietpi-autostart
   ```

   - Select option `2`: Desktop (LXDE)

2. **Configure display manager**
   ```bash
   nano /etc/lightdm/lightdm.conf
   ```
   - Find `[Seat:*]` section and add:
   ```ini
   autologin-user=dietpi
   autologin-user-timeout=0
   ```

## Step 9: Network Configuration

1. **Configure static IP (optional)**

   ```bash
   nano /etc/dhcpcd.conf
   ```

   Add at the end:

   ```bash
   interface eth0
   static ip_address=192.168.1.100/24
   static routers=192.168.1.1
   static domain_name_servers=8.8.8.8 8.8.4.4
   ```

2. **WiFi configuration will be handled by the Node.js server**

## Step 10: Security and Maintenance

1. **Change default passwords**

   ```bash
   passwd root
   passwd dietpi
   ```

2. **Configure firewall (optional)**

   ```bash
   ufw enable
   ufw allow 8000/tcp
   ufw allow ssh
   ```

3. **Setup log rotation**
   ```bash
   nano /etc/logrotate.d/price-checker
   ```
   ```bash
   /var/log/wifi_config.log {
       daily
       missingok
       rotate 7
       compress
       delaycompress
       notifempty
   }
   ```

## Step 11: Final Configuration

1. **Reboot to test**

   ```bash
   reboot
   ```

2. **Verify services are running**
   ```bash
   systemctl status price-checker
   ps aux | grep chromium
   ```

## Troubleshooting

### Service Issues

```bash
# Check service status
systemctl status price-checker

# View logs
journalctl -u price-checker -f

# Restart service
systemctl restart price-checker
```

### Display Issues

```bash
# Check X server
ps aux | grep X

# Restart display manager
systemctl restart lightdm
```

### Network Issues

```bash
# Check WiFi status
iwconfig

# Check network connections
ip addr show

# Restart networking
systemctl restart networking
```

### Barcode Scanner Issues

```bash
# Check USB devices
lsusb

# Check input devices
ls /dev/input/

# Test scanner input
cat /dev/input/event0  # Replace with correct event number
```

## WiFi Configuration via QR Code

The system supports WiFi configuration through QR codes containing Base64-encoded JSON:

1. **QR Code Format**

   ```json
   {
     "ssid": "YourWiFiNetwork",
     "password": "YourPassword",
     "security": "WPA2"
   }
   ```

2. **Generate QR Code**

   - Encode the JSON as Base64
   - Create QR code with the Base64 string
   - Scan with the barcode scanner

3. **Process**
   - System decodes Base64
   - Validates JSON format
   - Updates WiFi configuration
   - Restarts to apply changes

## Maintenance Commands

```bash
# Update DietPi
dietpi-update

# Update Node.js packages
cd /opt/price-checker && npm update

# Check disk space
df -h

# Check memory usage
free -h

# View system logs
journalctl -n 50

# Restart kiosk
systemctl restart lightdm
```

## Performance Optimization

1. **GPU Memory Split**: Set to 128MB in `dietpi-config`
2. **Disable unnecessary services**: Use `dietpi-services`
3. **Enable hardware acceleration** in Chromium
4. **Regular cleanup**: Use `dietpi-cleaner`

This setup provides a robust, auto-starting kiosk system with WiFi configuration capabilities perfect for retail environments.

