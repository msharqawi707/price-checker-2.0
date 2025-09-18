# Price Checker 2.0 - DietPi Installation Guide

## Overview

This guide will help you set up the Price Checker 2.0 system on DietPi with full kiosk mode, WiFi management, and automatic network switching capabilities.

## Prerequisites

- DietPi installed on Raspberry Pi (or compatible device)
- SSH access to the DietPi system
- Basic familiarity with Linux command line

## Features

- ✅ Node.js server with WiFi configuration API
- ✅ HTML barcode scanner interface
- ✅ QR code WiFi configuration (base64 JSON format)
- ✅ Multiple WiFi network storage and management
- ✅ Automatic network switching based on signal strength
- ✅ Full-screen Chromium kiosk mode (no mouse cursor)
- ✅ Automatic startup on boot
- ✅ Signal strength monitoring every 30 minutes

## Installation Steps

### 1. Connect to Your DietPi System

```bash
ssh dietpi@YOUR_PI_IP_ADDRESS
```

### 2. Download the Project Files

Transfer all project files to your DietPi system. You can use SCP, SFTP, or clone from a repository:

```bash
# Option 1: Using SCP from your local machine
scp -r /path/to/price-checker-2.0 dietpi@YOUR_PI_IP:/home/dietpi/

# Option 2: If using Git (install git first if needed)
sudo apt update && sudo apt install -y git
git clone YOUR_REPOSITORY_URL price-checker-2.0
```

### 3. Run the Automated Setup Script

```bash
cd price-checker-2.0
sudo chmod +x setup-dietpi.sh
sudo ./setup-dietpi.sh
```

The setup script will:

- Update the system packages
- Install Node.js, Chromium, and other dependencies
- Copy project files to `/opt/price-checker/`
- Install Node.js dependencies
- Configure systemd services
- Set up automatic network monitoring
- Configure kiosk mode auto-start
- Set up logging

### 4. Reboot the System

```bash
sudo reboot
```

After reboot, the system will:

- Auto-login as the `dietpi` user
- Start X11 automatically
- Launch Chromium in full-screen kiosk mode
- Display the barcode scanner interface

## WiFi Configuration

### QR Code Format

The system accepts WiFi configuration via QR codes containing base64-encoded JSON:

```json
{
  "ssid": "YourNetworkName",
  "password": "YourNetworkPassword"
}
```

**Note:** The `security` field is optional and defaults to "WPA2".

### Example QR Code Generation

```bash
# Create JSON
echo '{"ssid":"MyWiFi","password":"MyPassword123"}' | base64
```

Scan this base64 string as a QR code to configure WiFi.

### Multiple Networks

- The system automatically saves all configured networks
- Networks are prioritized by signal strength
- Automatic switching occurs every 30 minutes to the best available network
- Only switches if the new network is significantly better (20%+ improvement)

## System Services

### Main Services

- `price-checker.service` - Node.js server
- `price-checker-kiosk.service` - Chromium kiosk mode
- `network-manager.service` - WiFi management
- `network-manager.timer` - Runs network checks every 30 minutes

### Service Management Commands

```bash
# Check service status
sudo systemctl status price-checker
sudo systemctl status price-checker-kiosk
sudo systemctl status network-manager

# View logs
sudo journalctl -u price-checker -f
sudo journalctl -u price-checker-kiosk -f

# Restart services
sudo systemctl restart price-checker
sudo systemctl restart price-checker-kiosk

# Manual network check
sudo /opt/price-checker/network-manager.sh status
sudo /opt/price-checker/network-manager.sh switch
```

## Log Files

- `/var/log/price-checker-setup.log` - Installation log
- `/var/log/kiosk-startup.log` - Kiosk mode startup log
- `/var/log/network-manager.log` - Network management log
- `/var/log/wifi-config.log` - WiFi configuration attempts

## API Endpoints

### Server Endpoints (Port 8000)

- `GET /health` - Server health check
- `GET /system-info` - System information
- `GET /network-status` - Current network status and signal strength
- `POST /wifi_set` - Configure WiFi network
- `POST /switch-network` - Switch to best available network

### Testing the API

```bash
# Health check
curl http://localhost:8000/health

# Network status
curl http://localhost:8000/network-status

# Manual network switch
curl -X POST http://localhost:8000/switch-network
```

## Troubleshooting

### Kiosk Mode Issues

```bash
# Check if X11 is running
ps aux | grep Xorg

# Check Chromium process
ps aux | grep chromium

# Restart kiosk mode
sudo systemctl restart price-checker-kiosk

# View kiosk logs
tail -f /var/log/kiosk-startup.log
```

### Network Issues

```bash
# Check WiFi interface
iwconfig wlan0

# Check saved networks
cat /etc/price-checker/networks.json

# Manual network scan
sudo iwlist wlan0 scan

# Check wpa_supplicant config
cat /etc/wpa_supplicant/wpa_supplicant.conf

# Test network manager
sudo /opt/price-checker/network-manager.sh test
```

### Server Issues

```bash
# Check server status
sudo systemctl status price-checker

# Check server logs
sudo journalctl -u price-checker -f

# Test server manually
cd /opt/price-checker
sudo -u dietpi node server.js
```

### Display Issues

```bash
# Check display resolution
xrandr

# Reset display settings
xrandr --auto

# Disable screen blanking
xset s off
xset -dpms
```

## Configuration Files

### Project Structure

```
/opt/price-checker/
├── server.js              # Node.js server
├── index.html             # Barcode scanner interface
├── package.json           # Node.js dependencies
├── start-kiosk.sh         # Kiosk startup script
├── network-manager.sh     # Network management script
├── wifi-config-script.sh  # WiFi configuration utilities
├── setup-dietpi.sh        # Installation script
└── *.service              # Systemd service files
```

### Important Directories

- `/etc/price-checker/` - Stored network configurations
- `/home/dietpi/.config/chromium/` - Chromium settings
- `/var/log/` - Log files

## Advanced Configuration

### Changing the Barcode API

Edit `/opt/price-checker/index.html` and modify the fetch URL:

```javascript
const response = await fetch(`YOUR_API_ENDPOINT?q=${barcode}`);
```

### Adjusting Network Switching Sensitivity

Edit `/opt/price-checker/server.js` and modify the quality threshold:

```javascript
// Only switch if significantly better (at least 20% improvement)
if (currentStatus.connected && bestQuality - currentStatus.link_quality_percent < 20) {
```

### Changing Network Check Interval

Edit `/etc/systemd/system/network-manager.timer`:

```ini
[Timer]
OnBootSec=5min
OnUnitActiveSec=15min  # Change from 30min to 15min
```

Then reload and restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart network-manager.timer
```

## Security Notes

- The system runs the Node.js server on port 8000
- WiFi passwords are stored in `/etc/price-checker/networks.json` (readable only by root)
- The kiosk mode disables most browser security features for functionality
- Consider network security when deploying in production environments

## Support

- Check log files for detailed error information
- Use `sudo systemctl status SERVICE_NAME` to check service health
- All scripts include detailed logging for troubleshooting
