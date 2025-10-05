// controllers/deviceController.js - ENHANCED VERSION
// Replace your existing deviceController.js with this

const { createClient } = require('@supabase/supabase-js');

const getUserClient = (req) => {
  const token = req.headers.authorization.split(' ')[1];
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
};

const getAdminClient = () => {
    return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
};

// ============================================
// ESP32 FIRMWARE ENDPOINTS
// ============================================

/**
 * POST /api/devices/gps/submit
 * ESP32 device submits GPS data
 */
exports.submitGpsData = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { latitude, longitude, speed, heading, altitude, accuracy, battery_level, signal_strength } = req.body;
        const deviceInfo = req.esp32Device; // Set by authenticateESP32 middleware

        const { data, error } = await supabase.rpc('submit_gps_data', {
            p_esp_device_id: deviceInfo.device_name || req.headers['x-device-id'],
            p_api_key: req.headers['x-api-key'],
            p_latitude: latitude,
            p_longitude: longitude,
            p_speed: speed,
            p_heading: heading,
            p_altitude: altitude,
            p_accuracy: accuracy,
            p_battery_level: battery_level,
            p_signal_strength: signal_strength
        });

        if (error) {
            console.error('GPS submission error:', error);
            return res.status(500).json({ 
                success: false, 
                error: 'Failed to submit GPS data',
                details: error.message 
            });
        }

        res.status(200).json({
            success: data.success,
            message: data.message,
            shipment_id: data.shipment_id,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        next(error);
    }
};

/**
 * POST /api/devices/rfid/scan
 * ESP32 device submits RFID scan
 */
exports.submitRfidScan = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { rfid_tag, scan_timestamp } = req.body;
        const deviceInfo = req.esp32Device;

        const { data, error } = await supabase.rpc('submit_rfid_scan', {
            p_esp_device_id: deviceInfo.device_name || req.headers['x-device-id'],
            p_api_key: req.headers['x-api-key'],
            p_rfid_tag: rfid_tag,
            p_scan_timestamp: scan_timestamp || new Date().toISOString()
        });

        if (error) {
            console.error('RFID scan error:', error);
            return res.status(500).json({ 
                success: false, 
                error: 'Failed to process RFID scan',
                details: error.message 
            });
        }

        res.status(200).json({
            success: data.success,
            is_expected: data.is_expected,
            is_matched: data.is_matched,
            product_name: data.product_name,
            quantity: data.quantity,
            message: data.message,
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        next(error);
    }
};

// ============================================
// ADMIN/USER ENDPOINTS
// ============================================

/**
 * GET /api/devices/status
 * Get all ESP32 devices for user's companies
 */
exports.getDeviceStatuses = async (req, res, next) => {
    try {
        const supabase = getUserClient(req);
        const { data, error } = await supabase.from('v_esp_devices_status').select('*');
        
        if (error) return next(error);
        
        res.status(200).json({ success: true, data });
    } catch (error) {
        next(error);
    }
};

/**
 * POST /api/devices/register
 * Register a new ESP32 device
 */
exports.registerDevice = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { company_id, device_id, device_name, device_type, bound_to_type, bound_to_id } = req.body;

        const { data, error } = await supabase.rpc('register_esp_device', {
            p_company_id: company_id,
            p_device_id: device_id,
            p_device_name: device_name,
            p_device_type: device_type,
            p_bound_to_type: bound_to_type,
            p_bound_to_id: bound_to_id
        });

        if (error) {
            console.error('Device registration error:', error);
            return res.status(500).json({ 
                success: false, 
                error: 'Failed to register device',
                details: error.message 
            });
        }

        res.status(201).json({
            success: true,
            device_id: data.device_id,
            esp_device_id: data.esp_device_id,
            api_key: data.api_key,
            status: data.status,
            message: data.message
        });
    } catch (error) {
        next(error);
    }
};

/**
 * POST /api/devices/:id/approve
 * Approve a pending ESP32 device
 */

exports.approveDevice = async (req, res, next) => {
  const { id } = req.params;
  const supabase = getUserClient(req); // Assuming you have a helper for the user's client

  // Call the database function to handle the entire approval process
  const { data, error } = await supabase.rpc('approve_device', { 
    device_pk_id: id 
  });

  if (error) {
    // This will catch database-level errors
    return next(error);
  }

  if (!data.success) {
    // This catches the 'Device not found' case from our function
    return res.status(404).json(data);
  }

  // If the function succeeds, return the success message
  res.status(200).json(data);
};

/**
 * POST /api/devices/:id/bind
 * Bind device to truck or destination
 */

exports.bindDevice = async (req, res, next) => {
  const supabase = getAdminClient();
  const { id } = req.params;
  const { bound_to_type, bound_to_id } = req.body;

  // ✅ FINAL FIX #2: Correct the parameter names to match the SQL function
  const { data, error } = await supabase.rpc('bind_esp_device_to_asset', {
    p_device_id: id,
    p_bound_to_type: bound_to_type, // was p_asset_type
    p_bound_to_id: bound_to_id,   // was p_asset_id
  });

  if (error) return next(error);

  if (!data) {
    return res.status(404).json({ success: false, message: 'Device not found or could not be bound.' });
  }
  
  // Also correct the success status for a successful response
  res.status(200).json({ success: true, message: 'Device bound successfully' });
};

/**
 * POST /api/devices/:id/rotate-key
 * Rotate API key for a device
 */
exports.rotateApiKey = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { id } = req.params;

        const { data, error } = await supabase.rpc('rotate_esp_api_key', {
            p_device_id: id
        });

        if (error) return next(error);

        res.status(200).json({
            success: data.success,
            new_api_key: data.new_api_key,
            message: data.message
        });
    } catch (error) {
        next(error);
    }
};

/**
 * POST /api/devices/:id/blacklist
 * Blacklist a compromised device
 */
exports.blacklistDevice = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { id } = req.params;
        const { reason } = req.body;
        const blacklisted_by = req.user.sub;

        const { data, error } = await supabase.rpc('blacklist_esp_device', {
            p_device_id: id,
            p_reason: reason || 'Manual blacklist by admin',
            p_blacklisted_by: blacklisted_by
        });

        if (error) return next(error);

        res.status(200).json({
            success: data.success,
            message: data.message
        });
    } catch (error) {
        next(error);
    }
};

/**
 * GET /api/devices/:id/logs
 * Get authentication and data logs for a device
 */
exports.getDeviceLogs = async (req, res, next) => {
    try {
        const supabase = getUserClient(req);
        const { id } = req.params;
        const { limit = 50, type = 'all' } = req.query;

        // Get device info first
        const { data: device } = await supabase
            .from('esp_devices')
            .select('esp_device_id')
            .eq('id', id)
            .single();

        if (!device) {
            return res.status(404).json({
                success: false,
                error: 'Device not found'
            });
        }

        let logs = {};

        // Get auth logs
        if (type === 'all' || type === 'auth') {
            const { data: authLogs } = await supabase
                .from('esp_auth_log')
                .select('*')
                .eq('esp_device_id', device.esp_device_id)
                .order('timestamp', { ascending: false })
                .limit(limit);
            
            logs.auth_logs = authLogs;
        }

        // Get data submission logs
        if (type === 'all' || type === 'data') {
            const { data: dataLogs } = await supabase
                .from('esp_data_log')
                .select('*')
                .eq('esp_device_id', device.esp_device_id)
                .order('timestamp', { ascending: false })
                .limit(limit);
            
            logs.data_logs = dataLogs;
        }

        res.status(200).json({
            success: true,
            device_id: id,
            esp_device_id: device.esp_device_id,
            logs: logs
        });
    } catch (error) {
        next(error);
    }
};