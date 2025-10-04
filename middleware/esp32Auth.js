// middleware/esp32Auth.js
const { createClient } = require('@supabase/supabase-js');

const getAdminClient = () => {
    return createClient(
        process.env.SUPABASE_URL,
        process.env.SUPABASE_SERVICE_ROLE_KEY
    );
};

const authenticateESP32 = async (req, res, next) => {
    const deviceId = req.headers['x-device-id'];
    const apiKey = req.headers['x-api-key'];
    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.headers['user-agent'];
    const endpoint = req.path;

    if (!deviceId || !apiKey) {
        return res.status(401).json({
            success: false,
            error: 'Missing credentials',
            message: 'Both x-device-id and x-api-key headers are required'
        });
    }

    try {
        const supabase = getAdminClient();

        const { data, error } = await supabase.rpc('authenticate_esp_device', {
            p_device_id: deviceId,
            p_api_key: apiKey,
            p_ip_address: ipAddress,
            p_user_agent: userAgent,
            p_endpoint: endpoint
        });

        if (error) {
            console.error('ESP32 auth error:', error);
            return res.status(500).json({
                success: false,
                error: 'Authentication service error'
            });
        }

        if (!data.authenticated) {
            return res.status(401).json({
                success: false,
                authenticated: false,
                reason: data.reason,
                message: data.message
            });
        }

        req.esp32Device = {
            device_id: data.device_id,
            company_id: data.company_id,
            device_type: data.device_type,
            device_name: data.device_name,
            bound_to_type: data.bound_to_type,
            bound_to_id: data.bound_to_id,
            permissions: data.permissions
        };

        next();
    } catch (error) {
        console.error('ESP32 authentication failed:', error);
        return res.status(500).json({
            success: false,
            error: 'Authentication failed',
            message: error.message
        });
    }
};

const requireESP32Permission = (permission) => {
    return (req, res, next) => {
        if (!req.esp32Device) {
            return res.status(401).json({
                success: false,
                error: 'Device not authenticated'
            });
        }

        const permissions = req.esp32Device.permissions || {};

        if (!permissions[permission]) {
            return res.status(403).json({
                success: false,
                error: 'Permission denied',
                message: `Device does not have permission: ${permission}`
            });
        }

        next();
    };
};

module.exports = { authenticateESP32, requireESP32Permission };