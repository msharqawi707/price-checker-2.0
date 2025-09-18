#!/bin/bash

# Network Manager Script for Price Checker
# Automatically switches to the best available WiFi network every 30 minutes

LOG_FILE="/var/log/network-manager.log"
LOCK_FILE="/tmp/network-manager.lock"
SERVER_URL="http://localhost:8000"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to check if another instance is running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log_message "Another instance is already running (PID: $pid)"
            exit 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Function to cleanup on exit
cleanup() {
    rm -f "$LOCK_FILE"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT EXIT

# Function to get current network status
get_network_status() {
    local status_json
    if command -v curl &> /dev/null; then
        status_json=$(curl -s "$SERVER_URL/network-status" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$status_json" ]; then
            echo "$status_json"
            return 0
        fi
    fi
    
    # Fallback to direct iwconfig parsing
    local iwconfig_output
    iwconfig_output=$(iwconfig wlan0 2>/dev/null)
    
    if echo "$iwconfig_output" | grep -q "ESSID:\""; then
        local ssid=$(echo "$iwconfig_output" | grep -o 'ESSID:"[^"]*"' | cut -d'"' -f2)
        local quality=$(echo "$iwconfig_output" | grep -o 'Link Quality=[0-9]*/[0-9]*' | cut -d'=' -f2)
        local signal=$(echo "$iwconfig_output" | grep -o 'Signal level=-[0-9]*' | cut -d'=' -f2)
        
        if [ -n "$quality" ]; then
            local current=$(echo "$quality" | cut -d'/' -f1)
            local max=$(echo "$quality" | cut -d'/' -f2)
            local percent=$((current * 100 / max))
            echo "{\"connected\":true,\"ssid\":\"$ssid\",\"quality\":\"$quality\",\"signal_level\":$signal,\"link_quality_percent\":$percent}"
        else
            echo "{\"connected\":true,\"ssid\":\"$ssid\"}"
        fi
    else
        echo "{\"connected\":false}"
    fi
}

# Function to switch to best network
switch_to_best_network() {
    log_message "Checking for better networks..."
    
    local response
    if command -v curl &> /dev/null; then
        response=$(curl -s -X POST "$SERVER_URL/switch-network" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$response" ]; then
            local success=$(echo "$response" | grep -o '"success":[^,}]*' | cut -d':' -f2 | tr -d ' "')
            local message=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
            
            if [ "$success" = "true" ]; then
                log_message "Network switch successful: $message"
                return 0
            else
                log_message "Network switch not needed: $message"
                return 1
            fi
        fi
    fi
    
    # Fallback to direct network management
    log_message "Using fallback network switching method"
    fallback_network_switch
}

# Fallback function for network switching when server is not available
fallback_network_switch() {
    local current_status=$(get_network_status)
    local current_quality=0
    
    if echo "$current_status" | grep -q '"connected":true'; then
        current_quality=$(echo "$current_status" | grep -o '"link_quality_percent":[0-9]*' | cut -d':' -f2)
        current_quality=${current_quality:-0}
    fi
    
    log_message "Current network quality: ${current_quality}%"
    
    # Only switch if quality is poor (less than 30%)
    if [ "$current_quality" -lt 30 ]; then
        log_message "Poor signal quality detected, attempting to find better network"
        
        # Scan for networks
        local scan_result
        scan_result=$(iwlist wlan0 scan 2>/dev/null)
        
        if [ -n "$scan_result" ]; then
            log_message "Network scan completed, analyzing results..."
            # This is a simplified fallback - the server-based approach is preferred
            wpa_cli -i wlan0 reassociate 2>/dev/null
            log_message "Requested network reassociation"
        fi
    else
        log_message "Current network quality is acceptable (${current_quality}%)"
    fi
}

# Function to test internet connectivity
test_internet() {
    local test_hosts=("8.8.8.8" "1.1.1.1" "208.67.222.222")
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 5 "$host" &>/dev/null; then
            return 0
        fi
    done
    return 1
}

# Function to restart networking if needed
restart_networking_if_needed() {
    if ! test_internet; then
        log_message "No internet connectivity detected, restarting networking..."
        
        # Try to restart networking services
        systemctl restart dhcpcd &>/dev/null || true
        systemctl restart wpa_supplicant &>/dev/null || true
        
        # Wait a bit and test again
        sleep 10
        
        if test_internet; then
            log_message "Internet connectivity restored after restart"
        else
            log_message "Internet connectivity still unavailable after restart"
        fi
    fi
}

# Function to monitor and log network statistics
log_network_stats() {
    local status=$(get_network_status)
    local connected=$(echo "$status" | grep -o '"connected":[^,}]*' | cut -d':' -f2 | tr -d ' "')
    
    if [ "$connected" = "true" ]; then
        local ssid=$(echo "$status" | grep -o '"ssid":"[^"]*"' | cut -d'"' -f4)
        local quality=$(echo "$status" | grep -o '"link_quality_percent":[0-9]*' | cut -d':' -f2)
        local signal=$(echo "$status" | grep -o '"signal_level":-[0-9]*' | cut -d':' -f2)
        
        log_message "Network Stats - SSID: $ssid, Quality: ${quality}%, Signal: ${signal}dBm"
    else
        log_message "Network Stats - Not connected"
    fi
}

# Main execution
main() {
    check_lock
    
    log_message "Network Manager starting..."
    
    # Log current network status
    log_network_stats
    
    # Test internet connectivity and restart networking if needed
    restart_networking_if_needed
    
    # Try to switch to a better network
    switch_to_best_network
    
    # Log final network status
    sleep 5
    log_network_stats
    
    log_message "Network Manager cycle completed"
}

# Run based on command line argument
case "${1:-auto}" in
    "auto")
        main
        ;;
    "status")
        get_network_status | python3 -m json.tool 2>/dev/null || get_network_status
        ;;
    "switch")
        switch_to_best_network
        ;;
    "test")
        if test_internet; then
            echo "Internet connectivity: OK"
            exit 0
        else
            echo "Internet connectivity: FAILED"
            exit 1
        fi
        ;;
    "stats")
        log_network_stats
        ;;
    *)
        echo "Usage: $0 {auto|status|switch|test|stats}"
        echo ""
        echo "Commands:"
        echo "  auto   - Run full network management cycle (default)"
        echo "  status - Show current network status"
        echo "  switch - Try to switch to better network"
        echo "  test   - Test internet connectivity"
        echo "  stats  - Log current network statistics"
        exit 1
        ;;
esac
