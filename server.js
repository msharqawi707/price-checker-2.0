const express = require('express');
const cors = require('cors');
const fs = require('fs').promises;
const { exec } = require('child_process');
const path = require('path');

const app = express();
const PORT = 8000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('public')); // Serve static files (HTML, CSS, images)

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
        
        if (!ssid || !password) {
            log('Error: Missing SSID or password');
            return res.status(400).json({ 
                success: false, 
                error: 'SSID and password are required' 
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
        
        if (password.length < 8 || password.length > 63) {
            log('Error: Invalid password length');
            return res.status(400).json({ 
                success: false, 
                error: 'Password must be between 8 and 63 characters' 
            });
        }
        
        // Log the WiFi configuration attempt
        await logWifiConfig(ssid, security);
        
        // Configure WiFi using DietPi's network configuration
        const success = await configureWifi(ssid, password, security);
        
        if (success) {
            log(`WiFi configured successfully for SSID: ${ssid}`);
            res.json({ 
                success: true, 
                message: 'WiFi configuration updated successfully. Device will restart to apply changes.' 
            });
            
            // Schedule a restart after sending response
            setTimeout(() => {
                log('Restarting system to apply WiFi changes...');
                exec('sudo reboot', (error) => {
                    if (error) {
                        log(`Restart error: ${error.message}`);
                    }
                });
            }, 2000);
            
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

// Function to configure WiFi on DietPi
async function configureWifi(ssid, password, security = 'WPA2') {
    try {
        // Create wpa_supplicant configuration
        const wpaConfig = `
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
country=SA

network={
    ssid="${ssid}"
    psk="${password}"
    key_mgmt=WPA-PSK
    priority=1
}
`;
        
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
                    exec('sudo systemctl restart networking', (restartError) => {
                        if (restartError) {
                            log(`Error restarting networking: ${restartError.message}`);
                        } else {
                            log('Networking service restarted');
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

