#!/bin/bash

# Price Checker 2.0 - Simple DietPi Installation Script
# Run this script from /var/www/price-checker-2.0/ directory

set -e

PROJECT_DIR="/opt/price-checker"
SOURCE_DIR="/var/www/price-checker-2.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script as root (use sudo)"
    exit 1
fi

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory $SOURCE_DIR not found!"
    log_info "Make sure you're running this from /var/www/price-checker-2.0/"
    exit 1
fi

log_info "Starting Price Checker 2.0 installation..."

# Step 1: Update system and install packages
log_info "Installing required packages..."
apt update

# Install basic packages
apt install -y nodejs npm unclutter xorg xinit x11-xserver-utils curl

# Install Chromium (try different package names)
log_info "Installing Chromium browser..."
if apt install -y chromium-browser 2>/dev/null; then
    log_success "Installed chromium-browser"
elif apt install -y chromium 2>/dev/null; then
    log_success "Installed chromium"
elif apt install -y chromium-bsu 2>/dev/null; then
    log_success "Installed chromium-bsu"
else
    log_warning "Could not install Chromium via apt, trying snap..."
    if command -v snap >/dev/null 2>&1; then
        snap install chromium
        log_success "Installed chromium via snap"
    else
        log_error "Could not install Chromium. Please install manually:"
        log_info "Try: sudo apt install chromium"
        log_info "Or: sudo snap install chromium"
        exit 1
    fi
fi

# Step 2: Create project directory and copy files
log_info "Setting up project files..."
mkdir -p "$PROJECT_DIR"
cp -r "$SOURCE_DIR"/* "$PROJECT_DIR"/
chown -R dietpi:dietpi "$PROJECT_DIR"
chmod +x "$PROJECT_DIR"/*.sh

# Step 3: Install Node.js dependencies
log_info "Installing Node.js dependencies..."
cd "$PROJECT_DIR"
sudo -u dietpi npm install

# Step 4: Setup systemd services
log_info "Configuring services..."
cp "$PROJECT_DIR"/*.service /etc/systemd/system/
cp "$PROJECT_DIR"/*.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable price-checker.service
systemctl enable price-checker-kiosk.service
systemctl enable network-manager.timer

# Step 5: Configure auto-login
log_info "Configuring auto-login..."
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin dietpi --noclear %I \$TERM
EOF

# Step 6: Configure X11 auto-start
log_info "Configuring X11 auto-start..."
cat > /home/dietpi/.xinitrc << EOF
#!/bin/bash
exec /opt/price-checker/start-kiosk.sh
EOF

cat > /home/dietpi/.bash_profile << EOF
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF

chown dietpi:dietpi /home/dietpi/.xinitrc /home/dietpi/.bash_profile
chmod +x /home/dietpi/.xinitrc

# Step 7: Setup directories and permissions
log_info "Setting up directories and permissions..."
mkdir -p /var/log /etc/price-checker
touch /var/log/kiosk-startup.log /var/log/network-manager.log /var/log/wifi-config.log
chmod 666 /var/log/kiosk-startup.log /var/log/network-manager.log /var/log/wifi-config.log
chmod 755 /etc/price-checker

# Add dietpi user to required groups
usermod -a -G video,input,tty dietpi

# Step 8: Start services
log_info "Starting services..."
systemctl daemon-reload
systemctl start price-checker.service
systemctl start network-manager.timer

# Check service status
if systemctl is-active --quiet price-checker.service; then
    log_success "Price checker server started successfully"
else
    log_warning "Price checker server failed to start - check logs with: sudo journalctl -u price-checker"
fi

log_success "Installation completed!"
echo ""
echo "=============================================="
echo "Price Checker 2.0 Installation Complete"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Reboot the system: sudo reboot"
echo "2. System will auto-login and start kiosk mode"
echo "3. You should see 'يرجى اختيار الفرع اولا' message"
echo ""
echo "QR Code formats:"
echo "Branch: {\"branch\": \"mun\"} (base64 encoded)"
echo "WiFi: {\"ssid\": \"NetworkName\", \"password\": \"Password\"} (base64 encoded)"
echo ""
echo "Useful commands:"
echo "- Check server: curl http://localhost:8000/health"
echo "- View logs: sudo journalctl -u price-checker -f"
echo "- Network status: sudo /opt/price-checker/network-manager.sh status"
echo ""
echo "Web interface: http://$(hostname -I | awk '{print $1}'):8000"
echo ""
