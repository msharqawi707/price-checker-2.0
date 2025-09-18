#!/bin/bash

# WiFi Configuration Script for DietPi
# This script handles WiFi configuration updates from the Node.js server

LOG_FILE="/var/log/wifi-config.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to validate WiFi credentials
validate_credentials() {
    local ssid="$1"
    local password="$2"
    
    if [ -z "$ssid" ] || [ -z "$password" ]; then
        log_message "Error: SSID and password are required"
        return 1
    fi
    
    if [ ${#ssid} -gt 32 ]; then
        log_message "Error: SSID too long (max 32 characters)"
        return 1
    fi
    
    if [ ${#password} -lt 8 ] || [ ${#password} -gt 63 ]; then
        log_message "Error: Password must be 8-63 characters"
        return 1
    fi
    
    return 0
}

# Function to backup current WiFi configuration
backup_wifi_config() {
    if [ -f /etc/wpa_supplicant/wpa_supplicant.conf ]; then
        cp /etc/wpa_supplicant/wpa_supplicant.conf "/etc/wpa_supplicant/wpa_supplicant.conf.backup.$(date +%Y%m%d_%H%M%S)"
        log_message "WiFi configuration backed up"
    fi
}

# Function to configure WiFi
configure_wifi() {
    local ssid="$1"
    local password="$2"
    local security="${3:-WPA2}"
    local country="${4:-SA}"
    
    log_message "Configuring WiFi - SSID: $ssid, Security: $security"
    
    # Validate input
    if ! validate_credentials "$ssid" "$password"; then
        return 1
    fi
    
    # Backup existing configuration
    backup_wifi_config
    
    # Create new wpa_supplicant configuration
    cat > /tmp/wpa_supplicant_new.conf << EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=$country

network={
    ssid="$ssid"
    psk="$password"
    key_mgmt=WPA-PSK
    priority=1
    scan_ssid=1
}
EOF
    
    # Validate the configuration file
    if ! wpa_supplicant -i wlan0 -c /tmp/wpa_supplicant_new.conf -D nl80211,wext -d -t 2>&1 | grep -q "Successfully initialized"; then
        log_message "Error: Invalid WiFi configuration"
        rm -f /tmp/wpa_supplicant_new.conf
        return 1
    fi
    
    # Install the new configuration
    if cp /tmp/wpa_supplicant_new.conf /etc/wpa_supplicant/wpa_supplicant.conf; then
        log_message "WiFi configuration updated successfully"
        rm -f /tmp/wpa_supplicant_new.conf
        
        # Restart networking services
        log_message "Restarting networking services..."
        systemctl restart dhcpcd
        systemctl restart wpa_supplicant
        
        # Wait for connection
        sleep 5
        
        # Check if connected
        if iwconfig wlan0 2>/dev/null | grep -q "ESSID:\"$ssid\""; then
            log_message "Successfully connected to $ssid"
            return 0
        else
            log_message "Warning: Configuration updated but connection not verified"
            return 0
        fi
    else
        log_message "Error: Failed to update WiFi configuration"
        rm -f /tmp/wpa_supplicant_new.conf
        return 1
    fi
}

# Function to get current WiFi status
get_wifi_status() {
    local interface="wlan0"
    
    if ! ip link show "$interface" &>/dev/null; then
        echo "WiFi interface not found"
        return 1
    fi
    
    local status=$(iwconfig "$interface" 2>/dev/null)
    
    if echo "$status" | grep -q "ESSID:off"; then
        echo "Not connected"
    else
        local ssid=$(echo "$status" | grep -o 'ESSID:"[^"]*"' | cut -d'"' -f2)
        local quality=$(echo "$status" | grep -o 'Link Quality=[0-9]*/[0-9]*' | cut -d'=' -f2)
        echo "Connected to: $ssid (Quality: $quality)"
    fi
}

# Function to scan for available networks
scan_networks() {
    log_message "Scanning for available WiFi networks..."
    
    # Bring up the interface if it's down
    ip link set wlan0 up 2>/dev/null || true
    
    # Scan for networks
    iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Quality|Encryption" | \
    awk 'BEGIN{ORS=""} /ESSID/{gsub(/.*ESSID:"/,""); gsub(/".*/,""); if(length($0)>0) print $0} /Quality/{gsub(/.*Quality=/,""); gsub(/ .*/,""); print " (Quality: " $0 ")"} /Encryption key:on/{print " [Encrypted]"} /Encryption key:off/{print " [Open]"} /ESSID/{print "\n"}' | \
    grep -v "^$" | head -20
}

# Function to test internet connectivity
test_connectivity() {
    log_message "Testing internet connectivity..."
    
    if ping -c 3 8.8.8.8 &>/dev/null; then
        log_message "Internet connectivity: OK"
        return 0
    else
        log_message "Internet connectivity: FAILED"
        return 1
    fi
}

# Main script logic
case "$1" in
    "configure")
        if [ $# -lt 3 ]; then
            echo "Usage: $0 configure <SSID> <PASSWORD> [SECURITY] [COUNTRY]"
            exit 1
        fi
        configure_wifi "$2" "$3" "$4" "$5"
        ;;
    "status")
        get_wifi_status
        ;;
    "scan")
        scan_networks
        ;;
    "test")
        test_connectivity
        ;;
    "backup")
        backup_wifi_config
        ;;
    *)
        echo "WiFi Configuration Script for DietPi"
        echo "Usage: $0 {configure|status|scan|test|backup}"
        echo ""
        echo "Commands:"
        echo "  configure <SSID> <PASSWORD> [SECURITY] [COUNTRY] - Configure WiFi"
        echo "  status                                            - Show current WiFi status"
        echo "  scan                                              - Scan for available networks"
        echo "  test                                              - Test internet connectivity"
        echo "  backup                                            - Backup current configuration"
        echo ""
        echo "Examples:"
        echo "  $0 configure \"MyNetwork\" \"MyPassword\""
        echo "  $0 configure \"MyNetwork\" \"MyPassword\" \"WPA2\" \"US\""
        echo "  $0 status"
        echo "  $0 scan"
        exit 1
        ;;
esac

