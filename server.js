const express = require('express');
const cors = require('cors');
const fs = require('fs').promises;
const { exec } = require('child_process');
const path = require('path');

const app = express();
const PORT = 8000;
const NETWORKS_FILE = '/etc/price-checker/networks.json';

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('.'));

// Logging function
const log = (message) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${message}`);
};

// Load saved networks
async function loadNetworks() {
    try {
        const data = await fs.readFile(NETWORKS_FILE, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        return [];
    }
}

// Save network to stored networks
async function saveNetwork(ssid, password, security = 'WPA2') {
    try {
        // Ensure directory exists
        await exec('sudo mkdir -p /etc/price-checker').catch(() => {});
        
        let networks = await loadNetworks();
        
        // Remove existing network with same SSID
        networks = networks.filter(network => network.ssid !== ssid);
        
        // Add new network
        networks.push({
            ssid,
            password,
            security,
            added: new Date().toISOString(),
            priority: networks.length + 1
        });
        
        // Write back to file
        const tempFile = '/tmp/networks.json';
        await fs.writeFile(tempFile, JSON.stringify(networks, null, 2));
        
        return new Promise((resolve) => {
            exec(`sudo cp ${tempFile} ${NETWORKS_FILE} && sudo chmod 600 ${NETWORKS_FILE}`, (error) => {
                if (error) {
                    log(`Error saving networks: ${error.message}`);
                    resolve(false);
                } else {
                    log(`Network ${ssid} saved successfully`);
                    resolve(true);
                }
            });
        });
        
    } catch (error) {
        log(`Error in saveNetwork: ${error.message}`);
        return false;
    }
}

// Configure WiFi with all saved networks
async function configureWifi(ssid, password, security = 'WPA2') {
    try {
        const networks = await loadNetworks();
        
        // Create wpa_supplicant configuration with all networks
        let wpaConfig = `ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=SA

`;
        
        // Add all saved networks
        networks.forEach((network, index) => {
            const priority = network.ssid === ssid ? 10 : (networks.length - index);
            wpaConfig += `network={
    ssid="${network.ssid}"
    psk="${network.password}"
    key_mgmt=WPA-PSK
    priority=${priority}
    scan_ssid=1
}

`;
        });
        
        // Write to temporary file first
        const tempConfigPath = '/tmp/wpa_supplicant_new.conf';
        await fs.writeFile(tempConfigPath, wpaConfig);
        
        // Copy to system location with sudo
        return new Promise((resolve) => {
            exec(`sudo cp ${tempConfigPath} /etc/wpa_supplicant/wpa_supplicant.conf`, (error) => {
                if (error) {
                    log(`Error updating wpa_supplicant.conf: ${error.message}`);
                    resolve(false);
                } else {
                    log('wpa_supplicant.conf updated successfully');
                    // Reconfigure WiFi
                    exec('sudo wpa_cli -i wlan0 reconfigure', (restartError) => {
                        if (restartError) {
                            log(`Error reconfiguring wpa_supplicant: ${restartError.message}`);
                        } else {
                            log('WiFi reconfigured successfully');
                        }
                        resolve(true);
                    });
                }
            });
        });
        
    } catch (error) {
        log(`Error in configureWifi: ${error.message}`);
        return false;
    }
}

// WiFi configuration endpoint
app.post('/wifi_set', async (req, res) => {
    try {
        log('WiFi configuration request received');
        const { ssid, password, security = 'WPA2' } = req.body;
        
        if (!ssid || !password) {
            return res.status(400).json({ 
                success: false, 
                error: 'SSID and password are required' 
            });
        }
        
        // Save network to stored networks
        await saveNetwork(ssid, password, security);
        
        // Configure WiFi
        const success = await configureWifi(ssid, password, security);
        
        res.json({ 
            success,
            message: success ? 'WiFi configured successfully' : 'Failed to configure WiFi'
        });
        
    } catch (error) {
        log(`WiFi configuration error: ${error.message}`);
        res.status(500).json({ 
            success: false, 
            error: 'Internal server error' 
        });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Get network status
app.get('/network-status', async (req, res) => {
    try {
        const status = await getNetworkStatus();
        res.json(status);
    } catch (error) {
        res.status(500).json({ error: 'Failed to get network status' });
    }
});

// Function to get current network status
async function getNetworkStatus() {
    return new Promise((resolve) => {
        exec('iwconfig wlan0 2>/dev/null', (error, stdout) => {
            if (error) {
                resolve({ connected: false, error: error.message });
                return;
            }
            
            const status = {
                connected: false,
                ssid: null,
                quality: null,
                signal_level: null,
                link_quality_percent: 0
            };
            
            const essidMatch = stdout.match(/ESSID:"([^"]+)"/);
            const qualityMatch = stdout.match(/Link Quality=(\d+)\/(\d+)/);
            const signalMatch = stdout.match(/Signal level=(-?\d+)/);
            
            if (essidMatch && essidMatch[1] !== 'off') {
                status.connected = true;
                status.ssid = essidMatch[1];
            }
            
            if (qualityMatch) {
                const current = parseInt(qualityMatch[1]);
                const max = parseInt(qualityMatch[2]);
                status.quality = `${current}/${max}`;
                status.link_quality_percent = Math.round((current / max) * 100);
            }
            
            if (signalMatch) {
                status.signal_level = parseInt(signalMatch[1]);
            }
            
            resolve(status);
        });
    });
}

// Start server
app.listen(PORT, '0.0.0.0', () => {
    log(`Price Checker Server running on http://0.0.0.0:${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    log('Received SIGTERM, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    log('Received SIGINT, shutting down gracefully');
    process.exit(0);
});