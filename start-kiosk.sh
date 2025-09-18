#!/bin/bash

# Price Checker Kiosk Startup Script
# This script configures the display and starts Chromium in kiosk mode

LOG_FILE="/var/log/kiosk-startup.log"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "Starting Price Checker Kiosk..."

# Wait for X server to be ready
log_message "Waiting for X server..."
while ! xset q &>/dev/null; do
    sleep 1
done
log_message "X server is ready"

# Wait for network connectivity
log_message "Checking network connectivity..."
timeout=30
counter=0
while ! curl -s http://localhost:8000/health &>/dev/null && [ $counter -lt $timeout ]; do
    sleep 1
    ((counter++))
done

if [ $counter -ge $timeout ]; then
    log_message "Warning: Price checker server not responding after ${timeout}s"
else
    log_message "Price checker server is ready"
fi

# Hide mouse cursor
log_message "Hiding mouse cursor..."
unclutter -idle 0.5 -root &

# Disable screen blanking and power management
log_message "Disabling screen blanking..."
xset s off
xset -dpms
xset s noblank

# Disable screen saver
xset s 0 0

# Set display brightness to maximum (if supported)
if command -v xrandr &> /dev/null; then
    xrandr --output HDMI-1 --brightness 1.0 2>/dev/null || true
    xrandr --output HDMI-2 --brightness 1.0 2>/dev/null || true
fi

# Kill any existing Chromium processes
log_message "Cleaning up existing browser processes..."
pkill -f chromium 2>/dev/null || true
sleep 2

# Remove Chromium crash files and cache
rm -rf /home/dietpi/.config/chromium/Crash* 2>/dev/null || true
rm -rf /home/dietpi/.config/chromium/Default/Web* 2>/dev/null || true

# Configure Chromium preferences
CHROME_CONFIG_DIR="/home/dietpi/.config/chromium/Default"
mkdir -p "$CHROME_CONFIG_DIR"

# Create Preferences file to disable various popups and features
cat > "$CHROME_CONFIG_DIR/Preferences" << 'EOF'
{
   "profile": {
      "exit_type": "Normal",
      "exited_cleanly": true,
      "default_content_setting_values": {
         "notifications": 2
      }
   },
   "browser": {
      "check_default_browser": false,
      "show_home_button": false
   },
   "distribution": {
      "skip_first_run_ui": true,
      "import_bookmarks": false,
      "import_history": false,
      "import_search_engine": false,
      "make_chrome_default_for_user": false,
      "do_not_create_any_shortcuts": true,
      "do_not_create_desktop_shortcut": true,
      "do_not_create_quick_launch_shortcut": true,
      "do_not_create_taskbar_shortcut": true,
      "do_not_launch_chrome": true,
      "do_not_register_for_update_launch": true,
      "make_chrome_default": false,
      "require_eula": false,
      "suppress_first_run_default_browser_prompt": true
   },
   "first_run_tabs": []
}
EOF

# Set ownership
chown -R dietpi:dietpi /home/dietpi/.config/chromium/

log_message "Starting Chromium in kiosk mode..."

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

log_message "Using Chromium command: $CHROMIUM_CMD"

# Start Chromium in kiosk mode with comprehensive flags
$CHROMIUM_CMD \
  --kiosk \
  --no-first-run \
  --disable-infobars \
  --disable-restore-session-state \
  --disable-session-crashed-bubble \
  --disable-translate \
  --disable-features=TranslateUI,VizDisplayCompositor \
  --disable-ipc-flooding-protection \
  --disable-background-timer-throttling \
  --disable-backgrounding-occluded-windows \
  --disable-renderer-backgrounding \
  --disable-field-trial-config \
  --disable-back-forward-cache \
  --disable-extensions \
  --disable-plugins \
  --disable-default-apps \
  --disable-popup-blocking \
  --disable-prompt-on-repost \
  --no-default-browser-check \
  --no-first-run \
  --fast \
  --fast-start \
  --disable-dev-shm-usage \
  --disable-software-rasterizer \
  --enable-features=VaapiVideoDecoder \
  --use-gl=egl \
  --enable-hardware-overlays \
  --ignore-certificate-errors \
  --ignore-ssl-errors \
  --ignore-certificate-errors-spki-list \
  --disable-web-security \
  --allow-running-insecure-content \
  --autoplay-policy=no-user-gesture-required \
  --start-maximized \
  --window-position=0,0 \
  --user-data-dir=/home/dietpi/.config/chromium \
  --app=http://localhost:8000/ \
  >> "$LOG_FILE" 2>&1 &

CHROMIUM_PID=$!
log_message "Chromium started with PID: $CHROMIUM_PID"

# Monitor Chromium process and restart if it crashes
while true; do
    if ! kill -0 $CHROMIUM_PID 2>/dev/null; then
        log_message "Chromium process died, restarting in 5 seconds..."
        sleep 5
        
        # Clean up
        pkill -f chromium 2>/dev/null || true
        sleep 2
        
        # Restart Chromium
        $CHROMIUM_CMD \
          --kiosk \
          --no-first-run \
          --disable-infobars \
          --disable-restore-session-state \
          --disable-session-crashed-bubble \
          --disable-translate \
          --disable-features=TranslateUI,VizDisplayCompositor \
          --disable-ipc-flooding-protection \
          --disable-background-timer-throttling \
          --disable-backgrounding-occluded-windows \
          --disable-renderer-backgrounding \
          --disable-field-trial-config \
          --disable-back-forward-cache \
          --disable-extensions \
          --disable-plugins \
          --disable-default-apps \
          --disable-popup-blocking \
          --disable-prompt-on-repost \
          --no-default-browser-check \
          --no-first-run \
          --fast \
          --fast-start \
          --disable-dev-shm-usage \
          --disable-software-rasterizer \
          --enable-features=VaapiVideoDecoder \
          --use-gl=egl \
          --enable-hardware-overlays \
          --ignore-certificate-errors \
          --ignore-ssl-errors \
          --ignore-certificate-errors-spki-list \
          --disable-web-security \
          --allow-running-insecure-content \
          --autoplay-policy=no-user-gesture-required \
          --start-maximized \
          --window-position=0,0 \
          --user-data-dir=/home/dietpi/.config/chromium \
          --app=http://localhost:8000/ \
          >> "$LOG_FILE" 2>&1 &
        
        CHROMIUM_PID=$!
        log_message "Chromium restarted with PID: $CHROMIUM_PID"
    fi
    
    sleep 10
done

