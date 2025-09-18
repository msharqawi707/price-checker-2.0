#!/bin/bash

# Manual Chromium Installation for DietPi
# Use this if the main install script fails to install Chromium

set -e

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

log_info "Attempting to install Chromium manually..."

# Method 1: Try different package names
log_info "Method 1: Trying different Chromium package names..."
if apt install -y chromium 2>/dev/null; then
    log_success "Installed chromium"
    exit 0
elif apt install -y chromium-browser 2>/dev/null; then
    log_success "Installed chromium-browser"
    exit 0
elif apt install -y chromium-bsu 2>/dev/null; then
    log_success "Installed chromium-bsu"
    exit 0
fi

# Method 2: Try snap
log_info "Method 2: Trying snap installation..."
if command -v snap >/dev/null 2>&1; then
    if snap install chromium 2>/dev/null; then
        log_success "Installed chromium via snap"
        exit 0
    fi
else
    log_info "Installing snapd first..."
    apt install -y snapd
    systemctl enable snapd
    systemctl start snapd
    if snap install chromium 2>/dev/null; then
        log_success "Installed chromium via snap"
        exit 0
    fi
fi

# Method 3: Try adding repositories
log_info "Method 3: Trying to add additional repositories..."
apt update
apt install -y software-properties-common

# Try adding universe repository (for Ubuntu-based systems)
add-apt-repository universe 2>/dev/null || true
apt update

if apt install -y chromium-browser 2>/dev/null; then
    log_success "Installed chromium-browser from universe repository"
    exit 0
fi

# Method 4: Download and install manually
log_info "Method 4: Attempting manual download..."
log_warning "This method downloads a generic Chromium build"

# Create temporary directory
TEMP_DIR="/tmp/chromium-install"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Download Chromium (this is a fallback method)
log_info "Downloading Chromium..."
if wget -O chromium.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" 2>/dev/null; then
    log_info "Installing downloaded package..."
    if dpkg -i chromium.deb 2>/dev/null; then
        log_success "Installed Chromium manually"
        apt-get install -f -y  # Fix any dependency issues
        exit 0
    else
        log_warning "Manual installation failed, trying to fix dependencies..."
        apt-get install -f -y
        if dpkg -i chromium.deb 2>/dev/null; then
            log_success "Installed Chromium after fixing dependencies"
            exit 0
        fi
    fi
fi

# Method 5: Firefox as fallback
log_warning "All Chromium installation methods failed. Installing Firefox as fallback..."
if apt install -y firefox-esr 2>/dev/null; then
    log_success "Installed Firefox ESR as fallback browser"
    log_warning "You'll need to update the kiosk script to use Firefox instead of Chromium"
    log_info "Edit /opt/price-checker/start-kiosk.sh and replace chromium commands with:"
    log_info "firefox-esr --kiosk http://localhost:8000"
    exit 0
fi

# All methods failed
log_error "All installation methods failed!"
log_info "Please try installing Chromium manually using one of these commands:"
echo ""
echo "sudo apt install chromium"
echo "sudo apt install chromium-browser"
echo "sudo snap install chromium"
echo "sudo apt install firefox-esr"
echo ""
log_info "Then run the main installation script again."

exit 1
