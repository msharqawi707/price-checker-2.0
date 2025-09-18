#!/bin/bash

# Price Checker 2.0 - Uninstall Script

set -e

PROJECT_DIR="/opt/price-checker"

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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)"
    exit 1
fi

log_info "Uninstalling Price Checker 2.0..."

# Stop and disable services
log_info "Stopping services..."
systemctl stop price-checker.service 2>/dev/null || true
systemctl stop price-checker-kiosk.service 2>/dev/null || true
systemctl stop network-manager.timer 2>/dev/null || true
systemctl disable price-checker.service 2>/dev/null || true
systemctl disable price-checker-kiosk.service 2>/dev/null || true
systemctl disable network-manager.timer 2>/dev/null || true

# Remove service files
log_info "Removing service files..."
rm -f /etc/systemd/system/price-checker.service
rm -f /etc/systemd/system/price-checker-kiosk.service
rm -f /etc/systemd/system/network-manager.service
rm -f /etc/systemd/system/network-manager.timer
systemctl daemon-reload

# Remove project directory
log_info "Removing project files..."
rm -rf "$PROJECT_DIR"

# Remove auto-login configuration
log_info "Removing auto-login configuration..."
rm -rf /etc/systemd/system/getty@tty1.service.d/

# Remove X11 configuration
log_info "Removing X11 configuration..."
rm -f /home/dietpi/.xinitrc
rm -f /home/dietpi/.bash_profile

# Remove stored networks
log_info "Removing stored networks..."
rm -rf /etc/price-checker

# Remove log files
log_info "Removing log files..."
rm -f /var/log/kiosk-startup.log
rm -f /var/log/network-manager.log
rm -f /var/log/wifi-config.log

log_success "Price Checker 2.0 uninstalled successfully!"
log_info "You may want to reboot to complete the removal: sudo reboot"
