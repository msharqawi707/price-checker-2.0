#!/bin/bash

# DietPi Setup Script for Price Checker Kiosk
# This script sets up everything needed for the price checker on DietPi

set -e

LOG_FILE="/var/log/price-checker-setup.log"
PROJECT_DIR="/opt/price-checker"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log messages
log_message() {
    echo -e "${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC} - $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Please run this script as root (use sudo)"
        exit 1
    fi
}

# Function to update system
update_system() {
    log_message "Updating system packages..."
    apt update && apt upgrade -y
    log_success "System updated successfully"
}

# Function to install required packages
install_packages() {
    log_message "Installing required packages..."
    
    # Essential packages
    local packages=(
        "nodejs"
        "npm"
        "chromium-browser"
        "unclutter"
        "xorg"
        "xinit"
        "x11-xserver-utils"
        "curl"
        "wget"
        "git"
        "wireless-tools"
        "wpasupplicant"
        "network-manager"
        "cron"
    )
    
    for package in "${packages[@]}"; do
        if apt install -y "$package"; then
            log_success "Installed $package"
        else
            log_warning "Failed to install $package, continuing..."
        fi
    done
}

# Function to create project directory and copy files
setup_project() {
    log_message "Setting up project directory..."
    
    # Create project directory
    mkdir -p "$PROJECT_DIR"
    
    # Copy all project files to the target directory
    cp -r "$(dirname "$0")"/* "$PROJECT_DIR"/ 2>/dev/null || {
        log_warning "Could not copy files automatically. Please manually copy project files to $PROJECT_DIR"
        return 1
    }
    
    # Set ownership
    chown -R dietpi:dietpi "$PROJECT_DIR"
    
    # Make scripts executable
    chmod +x "$PROJECT_DIR"/*.sh
    
    log_success "Project files set up in $PROJECT_DIR"
}

# Function to install Node.js dependencies
install_node_deps() {
    log_message "Installing Node.js dependencies..."
    
    cd "$PROJECT_DIR"
    
    # Install dependencies as dietpi user
    sudo -u dietpi npm install
    
    if [ $? -eq 0 ]; then
        log_success "Node.js dependencies installed successfully"
    else
        log_error "Failed to install Node.js dependencies"
        exit 1
    fi
}

# Function to set up systemd services
setup_services() {
    log_message "Setting up systemd services..."
    
    # Copy service files
    cp "$PROJECT_DIR/price-checker.service" /etc/systemd/system/
    cp "$PROJECT_DIR/price-checker-kiosk.service" /etc/systemd/system/
    cp "$PROJECT_DIR/network-manager.service" /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    systemctl enable price-checker.service
    systemctl enable price-checker-kiosk.service
    systemctl enable network-manager.service
    
    log_success "Systemd services configured"
}

# Function to set up network manager cron job
setup_cron() {
    log_message "Setting up network manager cron job..."
    
    # Add cron job for network monitoring every 30 minutes
    echo "*/30 * * * * root $PROJECT_DIR/network-manager.sh auto" > /etc/cron.d/network-manager
    chmod 644 /etc/cron.d/network-manager
    
    # Restart cron service
    systemctl restart cron
    
    log_success "Network manager cron job configured (runs every 30 minutes)"
}

# Function to configure auto-login for kiosk mode
setup_autologin() {
    log_message "Configuring auto-login for kiosk mode..."
    
    # Enable auto-login for dietpi user
    if [ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]; then
        log_warning "Auto-login already configured"
    else
        mkdir -p /etc/systemd/system/getty@tty1.service.d/
        cat > /etc/systemd/system/getty@tty1.service.d/override.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin dietpi --noclear %I \$TERM
EOF
        systemctl daemon-reload
        log_success "Auto-login configured for dietpi user"
    fi
}

# Function to configure X11 auto-start
setup_x11_autostart() {
    log_message "Configuring X11 auto-start..."
    
    # Create .xinitrc for dietpi user
    cat > /home/dietpi/.xinitrc << EOF
#!/bin/bash
# Start the price checker kiosk
exec /opt/price-checker/start-kiosk.sh
EOF
    
    # Create .bash_profile to start X11 automatically
    cat > /home/dietpi/.bash_profile << EOF
# Auto-start X11 if on tty1 and not already running
if [ -z "\$DISPLAY" ] && [ "\$(tty)" = "/dev/tty1" ]; then
    exec startx
fi
EOF
    
    # Set ownership
    chown dietpi:dietpi /home/dietpi/.xinitrc /home/dietpi/.bash_profile
    chmod +x /home/dietpi/.xinitrc
    
    log_success "X11 auto-start configured"
}

# Function to create log directories
setup_logging() {
    log_message "Setting up logging directories..."
    
    # Create log directories
    mkdir -p /var/log
    touch /var/log/kiosk-startup.log
    touch /var/log/network-manager.log
    touch /var/log/wifi-config.log
    
    # Set permissions
    chmod 666 /var/log/kiosk-startup.log
    chmod 666 /var/log/network-manager.log
    chmod 666 /var/log/wifi-config.log
    
    log_success "Logging directories configured"
}

# Function to configure WiFi
configure_wifi() {
    log_message "Configuring WiFi settings..."
    
    # Enable WiFi interface
    ip link set wlan0 up 2>/dev/null || log_warning "Could not bring up wlan0 interface"
    
    # Create basic wpa_supplicant.conf if it doesn't exist
    if [ ! -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
        cat > /etc/wpa_supplicant/wpa_supplicant.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=SA
EOF
        log_success "Basic wpa_supplicant.conf created"
    else
        log_warning "wpa_supplicant.conf already exists"
    fi
    
    # Create networks storage directory
    mkdir -p /etc/price-checker
    chmod 755 /etc/price-checker
    
    log_success "WiFi configuration completed"
}

# Function to start services
start_services() {
    log_message "Starting services..."
    
    # Start the price checker server
    systemctl start price-checker.service
    
    if systemctl is-active --quiet price-checker.service; then
        log_success "Price checker server started"
    else
        log_warning "Price checker server failed to start"
    fi
    
    # Note: Kiosk service will start automatically on next boot
    log_message "Kiosk mode will start automatically on next boot"
}

# Function to display completion message
show_completion() {
    echo ""
    echo "=============================================="
    log_success "Price Checker setup completed successfully!"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo "1. Reboot the system: sudo reboot"
    echo "2. The system will auto-login and start kiosk mode"
    echo "3. Use QR codes with WiFi credentials to configure networks"
    echo "4. QR code format: base64 encoded JSON with 'ssid' and 'password' fields"
    echo ""
    echo "Services installed:"
    echo "- price-checker.service (Node.js server)"
    echo "- price-checker-kiosk.service (Chromium kiosk mode)"
    echo "- network-manager.service (WiFi management)"
    echo ""
    echo "Log files:"
    echo "- /var/log/price-checker-setup.log (this setup)"
    echo "- /var/log/kiosk-startup.log (kiosk mode)"
    echo "- /var/log/network-manager.log (network management)"
    echo "- /var/log/wifi-config.log (WiFi configuration)"
    echo ""
    echo "Useful commands:"
    echo "- sudo systemctl status price-checker"
    echo "- sudo systemctl status price-checker-kiosk"
    echo "- sudo journalctl -u price-checker -f"
    echo "- $PROJECT_DIR/network-manager.sh status"
    echo ""
}

# Main execution
main() {
    echo "=============================================="
    echo "Price Checker DietPi Setup Script"
    echo "=============================================="
    echo ""
    
    check_root
    
    log_message "Starting Price Checker setup on DietPi..."
    
    # Run setup steps
    update_system
    install_packages
    setup_project
    install_node_deps
    setup_services
    setup_timer
    setup_autologin
    setup_x11_autostart
    setup_logging
    configure_wifi
    start_services
    
    show_completion
}

# Run the main function
main "$@"
