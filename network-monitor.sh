#!/bin/bash

# Network Monitor - Checks every 30 minutes for better networks
# Runs silently in background, no HTML interference

LOG_FILE="/var/log/network-monitor.log"
LOCK_FILE="/tmp/network-monitor.lock"
NETWORKS_FILE="/etc/price-checker/networks.json"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if another instance is running
check_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            log_message "Another instance already running (PID: $pid)"
            exit 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Cleanup on exit
cleanup() {
    rm -f "$LOCK_FILE"
    exit 0
}

trap cleanup SIGTERM SIGINT EXIT

# Get current network status
get_current_network() {
    local iwconfig_output
    iwconfig_output=$(iwconfig wlan0 2>/dev/null)
    
    if echo "$iwconfig_output" | grep -q "ESSID:\""; then
        local ssid=$(echo "$iwconfig_output" | grep -o 'ESSID:"[^"]*"' | cut -d'"' -f2)
        local quality=$(echo "$iwconfig_output" | grep -o 'Link Quality=[0-9]*/[0-9]*' | cut -d'=' -f2)
        
        if [ -n "$quality" ]; then
            local current=$(echo "$quality" | cut -d'/' -f1)
            local max=$(echo "$quality" | cut -d'/' -f2)
            local percent=$((current * 100 / max))
            echo "$ssid:$percent"
        else
            echo "$ssid:0"
        fi
    else
        echo "none:0"
    fi
}

# Scan for available networks
scan_networks() {
    local scan_result
    scan_result=$(iwlist wlan0 scan 2>/dev/null)
    
    if [ -n "$scan_result" ]; then
        echo "$scan_result" | awk '
        /Cell/ { cell++ }
        /ESSID:"[^"]*"/ { 
            essid = $0; gsub(/.*ESSID:"/, "", essid); gsub(/".*/, "", essid)
            if (essid != "") networks[cell]["ssid"] = essid
        }
        /Quality=/ {
            quality = $0; gsub(/.*Quality=/, "", quality); gsub(/\/.*/, "", quality)
            max = $0; gsub(/.*\//, "", max); gsub(/ .*/, "", max)
            if (quality != "" && max != "") {
                percent = int((quality / max) * 100)
                networks[cell]["quality"] = percent
            }
        }
        END {
            for (i in networks) {
                if (networks[i]["ssid"] && networks[i]["quality"]) {
                    print networks[i]["ssid"] ":" networks[i]["quality"]
                }
            }
        }'
    fi
}

# Get saved networks
get_saved_networks() {
    if [ -f "$NETWORKS_FILE" ]; then
        cat "$NETWORKS_FILE" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for network in data:
        print(network['ssid'])
except:
    pass
" 2>/dev/null
    fi
}

# Switch to better network
switch_to_network(ssid) {
    log_message "Switching to network: $1"
    
    # Use the server API to switch networks
    if curl -s -X POST "http://localhost:8000/wifi_set" \
        -H "Content-Type: application/json" \
        -d "{\"ssid\":\"$1\",\"password\":\"\"}" >/dev/null 2>&1; then
        log_message "Network switch initiated via API"
        return 0
    else
        # Fallback: trigger wpa_supplicant reconfiguration
        wpa_cli -i wlan0 reconfigure >/dev/null 2>&1
        log_message "Network reconfiguration triggered"
        return 0
    fi
}

# Main monitoring function
monitor_networks() {
    check_lock
    
    log_message "Starting network monitoring cycle"
    
    # Get current network and quality
    local current_info=$(get_current_network)
    local current_ssid=$(echo "$current_info" | cut -d':' -f1)
    local current_quality=$(echo "$current_info" | cut -d':' -f2)
    
    log_message "Current network: $current_ssid (Quality: ${current_quality}%)"
    
    # Only check for better networks if current quality is poor or we're not connected
    if [ "$current_ssid" = "none" ] || [ "$current_quality" -lt 50 ]; then
        log_message "Poor or no connection, scanning for better networks..."
        
        # Get available networks
        local available_networks=$(scan_networks)
        local saved_networks=$(get_saved_networks)
        
        local best_ssid=""
        local best_quality=0
        
        # Find best available saved network
        while IFS= read -r saved_ssid; do
            [ -z "$saved_ssid" ] && continue
            
            while IFS=':' read -r avail_ssid avail_quality; do
                if [ "$saved_ssid" = "$avail_ssid" ] && [ "$avail_quality" -gt "$best_quality" ]; then
                    best_ssid="$avail_ssid"
                    best_quality="$avail_quality"
                fi
            done <<< "$available_networks"
        done <<< "$saved_networks"
        
        # Switch if we found a significantly better network
        if [ -n "$best_ssid" ] && [ "$best_quality" -gt $((current_quality + 20)) ]; then
            log_message "Found better network: $best_ssid (${best_quality}% vs ${current_quality}%)"
            switch_to_network "$best_ssid"
        else
            log_message "No significantly better network found"
        fi
    else
        log_message "Current connection quality is acceptable (${current_quality}%)"
    fi
    
    log_message "Network monitoring cycle completed"
}

# Run monitoring
monitor_networks
