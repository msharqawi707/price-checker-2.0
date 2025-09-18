const express = require('express');
const { exec } = require('child_process');

const app = express();
const PORT = 8000;

// Middleware
app.use(express.json());
app.use(express.static('.'));

// Log function
const log = (msg) => console.log(`[${new Date().toISOString()}] ${msg}`);

// Simple WiFi connect function
function connectToWiFi(ssid, password) {
    return new Promise((resolve) => {
        log(`Connecting to WiFi: ${ssid}`);
        
        const config = `ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=SA

network={
    ssid="${ssid}"
    psk="${password}"
    key_mgmt=WPA-PSK
    priority=1
}`;

        exec(`echo '${config}' | sudo tee /etc/wpa_supplicant/wpa_supplicant.conf`, (error) => {
            if (error) {
                log(`Error writing config: ${error.message}`);
                resolve(false);
                return;
            }
            
            exec('sudo wpa_cli -i wlan0 reconfigure && sudo systemctl restart dhcpcd', (restartError) => {
                if (restartError) {
                    log(`Restart error: ${restartError.message}`);
                }
                log(`WiFi connection initiated for ${ssid}`);
                resolve(true);
            });
        });
    });
}

// WiFi configuration endpoint
app.post('/wifi_set', async (req, res) => {
    try {
        const { ssid, password } = req.body;
        
        if (!ssid || !password) {
            return res.json({ success: false, error: 'SSID and password required' });
        }
        
        const result = await connectToWiFi(ssid, password);
        res.json({ success: result, message: result ? 'WiFi connected' : 'Connection failed' });
        
    } catch (error) {
        log(`Error: ${error.message}`);
        res.json({ success: false, error: 'Server error' });
    }
});

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Start server
app.listen(PORT, '127.0.0.1', () => {
    log(`Server running on http://127.0.0.1:${PORT}`);
});

log('Simple WiFi server started');