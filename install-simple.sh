#!/bin/bash

# Simple Price Checker Installation Script
# Clean, focused installation

set -e

PROJECT_DIR="/opt/price-checker"
SOURCE_DIR="/var/www/price-checker-2.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check root
if [ "$EUID" -ne 0 ]; then
    log_error "Run as root: sudo ./install-simple.sh"
    exit 1
fi

# Check source directory
if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory $SOURCE_DIR not found!"
    exit 1
fi

log_info "Installing Price Checker 2.0..."

# Install packages
log_info "Installing packages..."
apt update
apt install -y nodejs npm unclutter xorg xinit x11-xserver-utils curl

# Install Chromium
log_info "Installing Chromium..."
if ! apt install -y chromium 2>/dev/null; then
    if ! apt install -y chromium-browser 2>/dev/null; then
        log_error "Failed to install Chromium. Install manually: apt install chromium"
        exit 1
    fi
fi

# Setup project
log_info "Setting up project files..."
mkdir -p "$PROJECT_DIR"
cp -r "$SOURCE_DIR"/* "$PROJECT_DIR"/
chown -R dietpi:dietpi "$PROJECT_DIR"
chmod +x "$PROJECT_DIR"/*.sh

# Install Node dependencies
log_info "Installing Node.js dependencies..."
cd "$PROJECT_DIR"
sudo -u dietpi npm install

# Setup services
log_info "Creating systemd services..."

# Price checker service
cat > /etc/systemd/system/price-checker.service << EOF
[Unit]
Description=Price Checker Server
After=network.target

[Service]
Type=simple
User=dietpi
WorkingDirectory=$PROJECT_DIR
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Kiosk service
cat > /etc/systemd/system/price-checker-kiosk.service << EOF
[Unit]
Description=Price Checker Kiosk
After=graphical.target
Wants=graphical.target

[Service]
Type=simple
User=dietpi
Environment=DISPLAY=:0
ExecStart=$PROJECT_DIR/kiosk.sh
Restart=always
RestartSec=10

[Install]
WantedBy=graphical.target
EOF

# Network monitor timer
cat > /etc/systemd/system/network-monitor.timer << EOF
[Unit]
Description=Network Monitor Timer
Requires=network-monitor.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

cat > /etc/systemd/system/network-monitor.service << EOF
[Unit]
Description=Network Monitor
After=network.target

[Service]
Type=oneshot
ExecStart=$PROJECT_DIR/network-monitor.sh

[Install]
WantedBy=multi-user.target
EOF

# Enable services
systemctl daemon-reload
systemctl enable price-checker.service
systemctl enable price-checker-kiosk.service
systemctl enable network-monitor.timer

# Setup auto-login
log_info "Configuring auto-login..."
mkdir -p /etc/systemd/system/getty@tty1.service.d/
cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin dietpi --noclear %I \$TERM
EOF

# Setup X11 auto-start
log_info "Configuring X11 auto-start..."
cat > /home/dietpi/.bash_profile << EOF
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF

cat > /home/dietpi/.xinitrc << EOF
#!/bin/bash
exec $PROJECT_DIR/kiosk.sh
EOF

chown dietpi:dietpi /home/dietpi/.bash_profile /home/dietpi/.xinitrc
chmod +x /home/dietpi/.xinitrc

# Setup directories
log_info "Setting up directories..."
mkdir -p /var/log /etc/price-checker
touch /var/log/kiosk.log /var/log/network-monitor.log
chmod 666 /var/log/kiosk.log /var/log/network-monitor.log
chmod 755 /etc/price-checker

# Add user to groups
usermod -a -G video,input,tty dietpi

# Start services
log_info "Starting services..."
systemctl start price-checker.service
systemctl start network-monitor.timer

log_success "Installation complete!"
echo ""
echo "Next steps:"
echo "1. Reboot: sudo reboot"
echo "2. System will auto-start kiosk mode"
echo "3. Use WiFi QR codes to add networks"
echo ""
echo "Test server: curl http://localhost:8000/health"
