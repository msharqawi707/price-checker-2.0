# Price Checker Kiosk System

A complete barcode scanning kiosk system for Raspberry Pi 4 running DietPi, with WiFi configuration capabilities via QR codes.

## Features

- **Barcode Scanning**: Real-time product information display
- **Kiosk Mode**: Full-screen browser interface
- **WiFi Configuration**: QR code-based network setup
- **Auto-restart**: Resilient system with automatic recovery
- **Multi-language**: Arabic and English support
- **Price Display**: Regular and promotional pricing
- **Special Offers**: Bundle deal notifications

## System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Barcode Scanner │────│  Chromium Kiosk  │────│   Node.js API   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                         │
                                │                         │
                       ┌──────────────────┐    ┌─────────────────┐
                       │   HTML Frontend  │    │ WiFi Config API │
                       └──────────────────┘    └─────────────────┘
                                │                         │
                                │                         │
                       ┌──────────────────┐    ┌─────────────────┐
                       │ Product Database │    │  System Network │
                       │   (External API) │    │  Configuration  │
                       └──────────────────┘    └─────────────────┘
```

## Quick Start

### Prerequisites

- Raspberry Pi 4 Model B
- 16GB+ MicroSD Card (Class 10)
- USB Barcode Scanner
- HDMI Display
- Internet Connection

### Installation

1. **Flash DietPi to SD Card**

   ```bash
   # Download DietPi image and flash to SD card
   # Insert SD card and boot Raspberry Pi
   ```

2. **Clone Repository**

   ```bash
   git clone <repository-url>
   cd price-checker-kiosk
   ```

3. **Run Setup Script**

   ```bash
   sudo ./setup.sh
   ```

4. **Install Dependencies**

   ```bash
   npm install
   ```

5. **Start Services**
   ```bash
   sudo systemctl enable price-checker
   sudo systemctl start price-checker
   ```

## File Structure

```
price-checker-kiosk/
├── server.js                 # Main Node.js server
├── package.json              # Node.js dependencies
├── index.html                # Frontend kiosk interface
├── price-checker.service     # Systemd service file
├── start-kiosk.sh           # Kiosk startup script
├── wifi-config-script.sh    # WiFi configuration utility
├── DIETPI_SETUP_GUIDE.md    # Complete setup instructions
├── README.md                # This file
└── assets/                  # Static assets
    ├── Fonts/
    │   ├── font.otf
    │   └── semibold.otf
    ├── corner-logo.png
    └── sar.png
```

## Configuration

### Server Configuration

The Node.js server runs on port 8000 and provides:

- **Product API**: Fetches product data from external service
- **WiFi Config API**: Handles network configuration
- **Health Check**: System monitoring endpoint
- **Static Files**: Serves frontend assets

### WiFi Configuration via QR Code

1. **Create JSON Configuration**

   ```json
   {
     "ssid": "YourWiFiNetwork",
     "password": "YourPassword",
     "security": "WPA2"
   }
   ```

2. **Encode as Base64**

   ```bash
   echo '{"ssid":"YourWiFiNetwork","password":"YourPassword","security":"WPA2"}' | base64
   ```

3. **Generate QR Code**
   - Use the Base64 string to create a QR code
   - Scan with the barcode scanner
   - System will automatically configure WiFi and restart

### Environment Variables

```bash
# Server Configuration
PORT=8000
NODE_ENV=production

# API Configuration
PRODUCT_API_URL=https://flow.gazal.com.sa/webhook/data
```

## API Endpoints

### POST /wifi_set

Configure WiFi network settings.

**Request Body:**

```json
{
  "ssid": "NetworkName",
  "password": "NetworkPassword",
  "security": "WPA2"
}
```

**Response:**

```json
{
  "success": true,
  "message": "WiFi configuration updated successfully"
}
```

### GET /health

Health check endpoint.

**Response:**

```json
{
  "status": "ok",
  "timestamp": "2023-12-07T10:30:00.000Z",
  "uptime": 3600
}
```

### GET /system-info

Get system information.

**Response:**

```json
{
  "hostname": "DietPi",
  "platform": "linux",
  "arch": "arm64",
  "uptime": 3600,
  "current_wifi": "MyNetwork",
  "ip_addresses": ["192.168.1.100"]
}
```

## Kiosk Features

### Barcode Scanning

- **Auto-focus**: Input field automatically focused
- **Real-time**: Immediate product lookup
- **Error Handling**: Graceful failure messages
- **Timeout**: Auto-clear after 15 seconds

### Display Features

- **Responsive Design**: Adapts to screen size
- **Multi-language**: Arabic (RTL) and English
- **Price Display**: Regular and promotional pricing
- **Product Images**: Cached and optimized
- **Special Offers**: Highlighted bundle deals

### Kiosk Mode

- **Full Screen**: No browser UI visible
- **Auto-start**: Launches on boot
- **Crash Recovery**: Automatic restart on failure
- **Screen Management**: Prevents blanking/sleep

## Troubleshooting

### Service Issues

```bash
# Check service status
sudo systemctl status price-checker

# View service logs
sudo journalctl -u price-checker -f

# Restart service
sudo systemctl restart price-checker
```

### Network Issues

```bash
# Check WiFi status
./wifi-config-script.sh status

# Scan for networks
./wifi-config-script.sh scan

# Test connectivity
./wifi-config-script.sh test
```

### Display Issues

```bash
# Restart display manager
sudo systemctl restart lightdm

# Check X server
ps aux | grep X

# View kiosk logs
tail -f /var/log/kiosk-startup.log
```

### Barcode Scanner Issues

```bash
# List USB devices
lsusb

# Check input devices
ls -la /dev/input/

# Test scanner (replace event0 with correct device)
sudo cat /dev/input/event0
```

## Performance Optimization

### System Optimization

- **GPU Memory**: 128MB allocated for graphics
- **Swap**: Disabled for SD card longevity
- **Services**: Minimal service load
- **CPU Governor**: Performance mode

### Browser Optimization

- **Hardware Acceleration**: GPU rendering enabled
- **Cache Management**: Automatic cleanup
- **Memory Limits**: Configured for Pi 4
- **Extensions**: Disabled for performance

## Security Features

- **Input Validation**: All WiFi credentials validated
- **Log Rotation**: Prevents disk space issues
- **Service Isolation**: Systemd security features
- **Network Security**: Firewall configuration
- **File Permissions**: Restricted access

## Maintenance

### Regular Tasks

```bash
# Update system
sudo dietpi-update

# Update Node.js packages
cd /opt/price-checker && npm update

# Clean browser cache
rm -rf /home/dietpi/.config/chromium/Default/Cache/*

# Check disk space
df -h

# View system logs
sudo journalctl --since "1 hour ago"
```

### Log Files

- **Application**: `/var/log/price-checker.log`
- **WiFi Config**: `/var/log/wifi-config.log`
- **Kiosk**: `/var/log/kiosk-startup.log`
- **System**: `journalctl -u price-checker`

## Support

For issues and questions:

1. Check the logs first
2. Verify network connectivity
3. Test barcode scanner functionality
4. Review system resources
5. Check service status

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

**Note**: This system is designed for retail environments and requires proper hardware setup and network configuration. Follow the complete setup guide in `DIETPI_SETUP_GUIDE.md` for production deployment.

