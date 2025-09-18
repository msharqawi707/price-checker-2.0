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
app.use(express.static('.')); // Serve static files from root directory

// Logging function
const log = (message) => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ${message}`);
};

// WiFi configuration endpoint (replaces wifi_set.php)
app.post('/wifi_set', async (req, res) => {
    try {
        log('WiFi configuration request received');
        log(`Request body: ${JSON.stringify(req.body, null, 2)}`);
        
        const { ssid, password, security = 'WPA2' } = req.body;
        
        if (!ssid) {
            log('Error: Missing SSID');
            return res.status(400).json({ 
                success: false, 
                error: 'SSID is required' 
            });
        }
        
        if (!password) {
            log('Error: Missing password');
            return res.status(400).json({ 
                success: false, 
                error: 'Password is required' 
            });
        }
        
        // Validate inputs
        if (ssid.length > 32) {
            log('Error: SSID too long');
            return res.status(400).json({ 
                success: false, 
                error: 'SSID must be 32 characters or less' 
            });
        }
        
        if (password && (password.length < 8 || password.length > 63)) {
            log('Error: Invalid password length');
            return res.status(400).json({ 
                success: false, 
                error: 'Password must be between 8 and 63 characters' 
            });
        }
        
        // Save network to stored networks
        await saveNetwork(ssid, password, security);
        
        // Log the WiFi configuration attempt
        await logWifiConfig(ssid, security);
        
        // Configure WiFi using DietPi's network configuration
        const success = await configureWifi(ssid, password, security);
        
        if (success) {
            log(`WiFi configured successfully for SSID: ${ssid}`);
            res.json({ 
                success: true, 
                message: 'WiFi configuration updated successfully. Network saved for future use.' 
            });
        } else {
            log('WiFi configuration failed');
            res.status(500).json({ 
                success: false, 
                error: 'Failed to configure WiFi' 
            });
        }
        
    } catch (error) {
        log(`WiFi configuration error: ${error.message}`);
        res.status(500).json({ 
            success: false, 
            error: 'Internal server error' 
        });
    }
});

// Function to save network configuration
async function saveNetwork(ssid, password, security = 'WPA2') {
    try {
        // Ensure directory exists
        await exec('sudo mkdir -p /etc/price-checker').catch(() => {});
        
        let networks = [];
        try {
            const data = await fs.readFile(NETWORKS_FILE, 'utf8');
            networks = JSON.parse(data);
        } catch (error) {
            // File doesn't exist or is invalid, start with empty array
            networks = [];
        }
        
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

// Function to load saved networks
async function loadNetworks() {
    try {
        const data = await fs.readFile(NETWORKS_FILE, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        return [];
    }
}

// Function to configure WiFi on DietPi with multiple networks
async function configureWifi(ssid, password, security = 'WPA2') {
    try {
        // Load all saved networks
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
                    // Restart networking
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

// Function to log WiFi configuration attempts
async function logWifiConfig(ssid, security) {
    try {
        const logEntry = {
            timestamp: new Date().toISOString(),
            ssid: ssid,
            security: security,
            action: 'wifi_config_attempt'
        };
        
        const logFile = '/var/log/wifi_config.log';
        const logLine = JSON.stringify(logEntry) + '\n';
        
        // Append to log file
        await fs.appendFile(logFile, logLine).catch(() => {
            // If we can't write to system log, write to local log
            return fs.appendFile('./wifi_config.log', logLine);
        });
        
    } catch (error) {
        log(`Error logging WiFi config: ${error.message}`);
    }
}

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Get system info endpoint
app.get('/system-info', async (req, res) => {
    try {
        const systemInfo = await getSystemInfo();
        res.json(systemInfo);
    } catch (error) {
        log(`Error getting system info: ${error.message}`);
        res.status(500).json({ error: 'Failed to get system information' });
    }
});

// Network monitoring endpoint
app.get('/network-status', async (req, res) => {
    try {
        const networkStatus = await getNetworkStatus();
        res.json(networkStatus);
    } catch (error) {
        log(`Error getting network status: ${error.message}`);
        res.status(500).json({ error: 'Failed to get network status' });
    }
});

// Switch to best network endpoint
app.post('/switch-network', async (req, res) => {
    try {
        const result = await switchToBestNetwork();
        res.json(result);
    } catch (error) {
        log(`Error switching network: ${error.message}`);
        res.status(500).json({ error: 'Failed to switch network' });
    }
});

// Function to get network status and signal strength
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
            
            // Parse iwconfig output
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

// Function to scan for available networks with signal strength
async function scanNetworks() {
    return new Promise((resolve) => {
        exec('sudo iwlist wlan0 scan 2>/dev/null', (error, stdout) => {
            if (error) {
                resolve([]);
                return;
            }
            
            const networks = [];
            const cells = stdout.split('Cell ').slice(1);
            
            cells.forEach(cell => {
                const essidMatch = cell.match(/ESSID:"([^"]+)"/);
                const qualityMatch = cell.match(/Quality=(\d+)\/(\d+)/);
                const signalMatch = cell.match(/Signal level=(-?\d+)/);
                
                if (essidMatch && essidMatch[1]) {
                    const network = {
                        ssid: essidMatch[1],
                        quality: qualityMatch ? `${qualityMatch[1]}/${qualityMatch[2]}` : null,
                        quality_percent: qualityMatch ? Math.round((parseInt(qualityMatch[1]) / parseInt(qualityMatch[2])) * 100) : 0,
                        signal_level: signalMatch ? parseInt(signalMatch[1]) : null,
                        encrypted: cell.includes('Encryption key:on')
                    };
                    networks.push(network);
                }
            });
            
            // Sort by signal quality
            networks.sort((a, b) => b.quality_percent - a.quality_percent);
            resolve(networks);
        });
    });
}

// Function to switch to the best available network
async function switchToBestNetwork() {
    try {
        log('Scanning for best network...');
        
        // Get saved networks
        const savedNetworks = await loadNetworks();
        if (savedNetworks.length === 0) {
            return { success: false, message: 'No saved networks available' };
        }
        
        // Get current network status
        const currentStatus = await getNetworkStatus();
        
        // Scan available networks
        const availableNetworks = await scanNetworks();
        
        // Find the best available saved network
        let bestNetwork = null;
        let bestQuality = currentStatus.connected ? currentStatus.link_quality_percent : -1;
        
        for (const available of availableNetworks) {
            const saved = savedNetworks.find(s => s.ssid === available.ssid);
            if (saved && available.quality_percent > bestQuality) {
                bestNetwork = { ...saved, ...available };
                bestQuality = available.quality_percent;
            }
        }
        
        if (!bestNetwork) {
            return { 
                success: false, 
                message: 'No better network found',
                current: currentStatus,
                available: availableNetworks.length
            };
        }
        
        // Only switch if significantly better (at least 20% improvement)
        if (currentStatus.connected && bestQuality - currentStatus.link_quality_percent < 20) {
            return { 
                success: false, 
                message: 'Current network is good enough',
                current: currentStatus,
                best_available: bestNetwork
            };
        }
        
        log(`Switching to better network: ${bestNetwork.ssid} (${bestQuality}%)`);
        
        // Configure the better network
        const success = await configureWifi(bestNetwork.ssid, bestNetwork.password, bestNetwork.security);
        
        return {
            success,
            message: success ? `Switched to ${bestNetwork.ssid}` : 'Failed to switch network',
            previous: currentStatus,
            new_network: bestNetwork
        };
        
    } catch (error) {
        log(`Error in switchToBestNetwork: ${error.message}`);
        return { success: false, error: error.message };
    }
}

// Function to get system information
async function getSystemInfo() {
    return new Promise((resolve) => {
        const info = {
            hostname: require('os').hostname(),
            platform: require('os').platform(),
            arch: require('os').arch(),
            uptime: require('os').uptime(),
            loadavg: require('os').loadavg(),
            freemem: require('os').freemem(),
            totalmem: require('os').totalmem()
        };
        
        // Get IP addresses
        exec('hostname -I', (error, stdout) => {
            if (!error) {
                info.ip_addresses = stdout.trim().split(' ');
            }
            
            // Get WiFi status
            exec('iwconfig 2>/dev/null | grep ESSID', (wifiError, wifiStdout) => {
                if (!wifiError && wifiStdout) {
                    const match = wifiStdout.match(/ESSID:"([^"]+)"/);
                    if (match) {
                        info.current_wifi = match[1];
                    }
                }
                resolve(info);
            });
        });
    });
}

// Error handling middleware
app.use((error, req, res, next) => {
    log(`Unhandled error: ${error.message}`);
    res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use((req, res) => {
    log(`404 - Not found: ${req.method} ${req.url}`);
    res.status(404).json({ error: 'Endpoint not found' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    log(`Price Checker Server running on http://0.0.0.0:${PORT}`);
    log('WiFi configuration endpoint available at /wifi_set');
    log('Health check available at /health');
    log('System info available at /system-info');
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

