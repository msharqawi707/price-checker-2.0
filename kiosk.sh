#!/bin/bash

# Stable Kiosk Browser Script
# Only restarts on actual crashes, not every few seconds

LOG_FILE="/var/log/kiosk.log"
URL="http://localhost:8000"
RESTART_DELAY=10  # Wait 10 seconds before restart after crash
MAX_RESTART_ATTEMPTS=5
RESTART_COUNT=0

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Create log file
sudo mkdir -p /var/log
sudo touch "$LOG_FILE"
sudo chmod 666 "$LOG_FILE"

log_message "Starting Price Checker Kiosk"

# Set environment
export DISPLAY=:0
export XAUTHORITY=/home/dietpi/.Xauthority

# Wait for X server
log_message "Waiting for X server..."
while ! xset q &>/dev/null; do
    sleep 2
done
log_message "X server ready"

# Wait for server
log_message "Waiting for price checker server..."
while ! curl -s "$URL/health" > /dev/null 2>&1; do
    sleep 2
done
log_message "Server ready"

# Configure display
xset s off
xset -dpms
xset s noblank

# Hide mouse cursor
if command -v unclutter &> /dev/null; then
    unclutter -idle 0.1 -root &
fi

# Detect Chromium command
CHROMIUM_CMD=""
if command -v chromium-browser >/dev/null 2>&1; then
    CHROMIUM_CMD="chromium-browser"
elif command -v chromium >/dev/null 2>&1; then
    CHROMIUM_CMD="chromium"
elif command -v /snap/bin/chromium >/dev/null 2>&1; then
    CHROMIUM_CMD="/snap/bin/chromium"
else
    log_message "Error: No Chromium browser found!"
    exit 1
fi

log_message "Using browser: $CHROMIUM_CMD"

# Function to start Chromium
start_chromium() {
    # Clean up any existing processes
    pkill -f chromium 2>/dev/null || true
    sleep 2
    
    # Remove crash files
    rm -rf /home/dietpi/.config/chromium/Crash* 2>/dev/null || true
    rm -rf /tmp/chromium-kiosk 2>/dev/null || true
    
    log_message "Starting Chromium in kiosk mode..."
    
    $CHROMIUM_CMD \
        --kiosk \
        --no-sandbox \
        --disable-dev-shm-usage \
        --disable-gpu \
        --disable-software-rasterizer \
        --start-fullscreen \
        --disable-infobars \
        --disable-session-crashed-bubble \
        --disable-restore-session-state \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        --disable-features=TranslateUI,VizDisplayCompositor \
        --disable-extensions \
        --disable-plugins \
        --disable-sync \
        --disable-background-networking \
        --autoplay-policy=no-user-gesture-required \
        --no-first-run \
        --disable-default-apps \
        --disable-popup-blocking \
        --disable-prompt-on-repost \
        --disable-hang-monitor \
        --disable-logging \
        --disable-web-security \
        --user-data-dir=/tmp/chromium-kiosk \
        --homepage="$URL" \
        --app="$URL" \
        "$URL" 2>/dev/null &
    
    CHROMIUM_PID=$!
    log_message "Chromium started with PID: $CHROMIUM_PID"
    return $CHROMIUM_PID
}

# Function to check if Chromium is actually running and responsive
is_chromium_healthy() {
    # Check if process exists
    if ! kill -0 $CHROMIUM_PID 2>/dev/null; then
        return 1
    fi
    
    # Check if it's actually displaying something (not just running)
    if pgrep -f "chromium.*kiosk" >/dev/null; then
        return 0
    else
        return 1
    fi
}

# Start Chromium initially
start_chromium

# Monitor loop - only restart on actual crashes
while true; do
    sleep 30  # Check every 30 seconds instead of constantly
    
    if ! is_chromium_healthy; then
        RESTART_COUNT=$((RESTART_COUNT + 1))
        log_message "Chromium appears to have crashed (attempt $RESTART_COUNT/$MAX_RESTART_ATTEMPTS)"
        
        if [ $RESTART_COUNT -ge $MAX_RESTART_ATTEMPTS ]; then
            log_message "Maximum restart attempts reached. Waiting longer before retry..."
            sleep 300  # Wait 5 minutes before trying again
            RESTART_COUNT=0
        fi
        
        log_message "Waiting ${RESTART_DELAY} seconds before restart..."
        sleep $RESTART_DELAY
        
        start_chromium
    else
        # Reset restart count if Chromium is running fine
        RESTART_COUNT=0
    fi
done
