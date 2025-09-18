# Price Checker 2.0 - Quick Setup

## Installation (on DietPi)

1. **Copy files to DietPi:**

   ```bash
   # Files should be in /var/www/price-checker-2.0/
   ```

2. **Run installation:**

   ```bash
   cd /var/www/price-checker-2.0
   sudo chmod +x install.sh
   sudo ./install.sh
   ```

3. **Reboot:**
   ```bash
   sudo reboot
   ```

## QR Code Formats

**Branch Selection:**

```json
{ "branch": "mun" }
```

**WiFi Configuration:**

```json
{ "ssid": "NetworkName", "password": "Password" }
```

Both should be base64 encoded before creating QR codes.

## Features

- ✅ Barcode scanning interface
- ✅ Branch selection via QR code
- ✅ WiFi configuration via QR code
- ✅ Multiple network storage
- ✅ Auto network switching (every 30 minutes)
- ✅ Full-screen kiosk mode
- ✅ Auto-start on boot

## API Endpoints

- `http://localhost:8000/health` - Server health
- `http://localhost:8000/network-status` - Network status
- `http://localhost:8000/system-info` - System information

## Troubleshooting

```bash
# Check services
sudo systemctl status price-checker
sudo journalctl -u price-checker -f

# Test server
curl http://localhost:8000/health

# Network management
sudo /opt/price-checker/network-manager.sh status
```
