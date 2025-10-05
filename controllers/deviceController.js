const { createClient } = require('@supabase/supabase-js');

// Helper to get a Supabase client authenticated as the logged-in user
const getUserClient = (req) => {
  const token = req.headers.authorization.split(' ')[1];
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
};

// Helper to get a Supabase client with admin privileges
const getAdminClient = () => {
    return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
};


// ============================================
// FIRMWARE (ESP32) ENDPOINTS
// ============================================

exports.submitGpsData = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { latitude, longitude, speed, heading, altitude, accuracy, battery_level, signal_strength } = req.body;
        const deviceInfo = req.esp32Device; // Attached by the 'authenticateESP32' middleware

        // Call the 'submit_gps_data' SQL function
        const { data, error } = await supabase.rpc('submit_gps_data', {
            p_device_id: deviceInfo.device_id,
            p_latitude: latitude,
            p_longitude: longitude,
            p_speed: speed,
            p_heading: heading,
            p_altitude: altitude,
            p_accuracy: accuracy,
            p_battery_level: battery_level,
            p_signal_strength: signal_strength
        });

        if (error) throw error;
        res.status(200).json(data);
    } catch (error) {
        next(error);
    }
};

exports.submitRfidScan = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { rfid_tag, scan_timestamp } = req.body;
        const deviceInfo = req.esp32Device;

        // Call the 'process_rfid_scan' SQL function.
        const { data, error } = await supabase.rpc('process_rfid_scan', {
            p_device_id: deviceInfo.device_id,
            p_rfid_tag: rfid_tag,
            p_scan_timestamp: scan_timestamp || new Date().toISOString()
        });
        
        if (error) throw error;
        res.status(200).json({ ...data, timestamp: new Date().toISOString() });
    } catch (error) {
        next(error);
    }
};

// ============================================
// USER/ADMINISTRATION ENDPOINTS
// ============================================

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

exports.registerDevice = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { company_id, device_id, device_name, device_type } = req.body;

        const { data, error } = await supabase.rpc('register_esp_device', {
            p_company_id: company_id,
            p_device_id: device_id,
            p_device_name: device_name,
            p_device_type: device_type,
        });

        if (error) throw error;
        res.status(201).json(data);
    } catch (error) {
        next(error);
    }
};

exports.approveDevice = async (req, res, next) => {
  const { id } = req.params;
  const supabase = getUserClient(req);
  const approvingUserId = req.user.sub; 

  const { data, error } = await supabase.rpc('approve_esp_device', { 
    p_device_id: id,
    p_approved_by: approvingUserId,
    p_notes: 'Approved via E2E test script'
  });

  if (error) return next(error);
  if (!data.success) return res.status(404).json(data);
  
  res.status(200).json(data);
};

exports.bindDevice = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { id } = req.params;
        const { bound_to_type, bound_to_id } = req.body;

        // This assumes a function named 'bind_esp_device_to_asset' exists from your SQL files.
        const { data, error } = await supabase.rpc('bind_esp_device_to_asset', {
            p_device_id: id,
            p_bound_to_type: bound_to_type,
            p_bound_to_id: bound_to_id,
        });

        if (error) return next(error);
        res.status(200).json({ success: true, message: 'Device bound successfully' });
    } catch (error) {
        next(error);
    }
};

exports.rotateApiKey = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { id } = req.params;

        const { data, error } = await supabase.rpc('rotate_esp_api_key', {
            p_device_id: id
        });

        if (error) return next(error);
        res.status(200).json(data);
    } catch (error) {
        next(error);
    }
};

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
        res.status(200).json(data);
    } catch (error) {
        next(error);
    }
};

exports.getDeviceLogs = async (req, res, next) => {
    try {
        const supabase = getUserClient(req);
        const { id } = req.params;
        const { limit = 50, type = 'all' } = req.query;

        const { data: device } = await supabase
            .from('esp_devices')
            .select('esp_device_id')
            .eq('id', id)
            .single();

        if (!device) {
            return res.status(404).json({ success: false, error: 'Device not found' });
        }

        let logs = {};
        if (type === 'all' || type === 'auth') {
            const { data: authLogs } = await supabase.from('esp_auth_log').select('*').eq('esp_device_id', device.esp_device_id).order('timestamp', { ascending: false }).limit(limit);
            logs.auth_logs = authLogs;
        }
        if (type === 'all' || type === 'data') {
            const { data: dataLogs } = await supabase.from('esp_data_log').select('*').eq('esp_device_id', device.esp_device_id).order('timestamp', { ascending: false }).limit(limit);
            logs.data_logs = dataLogs;
        }

        res.status(200).json({ success: true, device_id: id, esp_device_id: device.esp_device_id, logs: logs });
    } catch (error) {
        next(error);
    }
};