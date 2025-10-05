// controllers/deviceController.js - FINAL CORRECTED VERSION

const { createClient } = require('@supabase/supabase-js');

// Helper to get a Supabase client authenticated as the logged-in user
const getUserClient = (req) => {
  // The user's JWT is passed in the authorization header by the 'userAuth' middleware
  const token = req.headers.authorization.split(' ')[1];
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
};

// Helper to get a Supabase client with admin privileges for sensitive operations
const getAdminClient = () => {
    return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
};

// ============================================
// FIRMWARE (ESP32) ENDPOINTS
// ============================================

/**
 * POST /api/devices/gps/submit
 * Handles GPS data submission from an authenticated ESP32 device.
 */
exports.submitGpsData = async (req, res, next) => {
    // The 'authenticateESP32' and 'requireESP32Permission' middlewares have already run.
    // We can trust req.esp32Device to contain the authenticated device's info.
    try {
        const supabase = getAdminClient();
        const { latitude, longitude, speed, heading, altitude, accuracy, battery_level, signal_strength } = req.body;
        const deviceInfo = req.esp32Device;

        // Your database likely has a function to handle this logic, e.g., 'submit_gps_data'
        // For now, we'll perform a direct insert, which is also secure because the middleware has validated the device.
        const { error } = await supabase.from('gps_log').insert({
            device_id: deviceInfo.device_id, // Use the primary key from the authenticated device
            latitude,
            longitude,
            speed,
            heading,
            altitude,
            accuracy,
            battery_level,
            signal_strength,
            shipment_id: deviceInfo.bound_to_id, // Assumes device is bound to a shipment or truck
        });

        if (error) throw error;

        res.status(200).json({ success: true, message: 'GPS data received successfully.' });
    } catch (error) {
        next(error);
    }
};

/**
 * POST /api/devices/rfid/scan
 * Handles RFID scan submission from an authenticated ESP32 device.
 */
exports.submitRfidScan = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { rfid_tag, scan_timestamp } = req.body;
        const deviceInfo = req.esp32Device;

        // It's best practice to have a dedicated SQL function for the complex logic of processing a scan.
        // We will assume a function 'process_rfid_scan' exists.
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

/**
 * GET /api/devices/status
 * Fetches the status of all devices for the user's company.
 */
exports.getDeviceStatuses = async (req, res, next) => {
    try {
        const supabase = getUserClient(req);
        // This uses the v_esp_devices_status view defined in your SQL schema.
        const { data, error } = await supabase.from('v_esp_devices_status').select('*');
        if (error) return next(error);
        res.status(200).json({ success: true, data });
    } catch (error) {
        next(error);
    }
};

/**
 * POST /api/devices/register
 * Registers a new device and returns its generated API key.
 */
exports.registerDevice = async (req, res, next) => {
    try {
        const supabase = getAdminClient(); // Registration is an admin-level action.
        const { company_id, device_id, device_name, device_type } = req.body;

        // Calls the 'register_esp_device' function from your esp32devicesecurity.sql file.
        const { data, error } = await supabase.rpc('register_esp_device', {
            p_company_id: company_id,
            p_device_id: device_id, // This is the esp_device_id (string) from the test script
            p_device_name: device_name,
            p_device_type: device_type,
        });

        if (error) throw error;
        res.status(201).json(data);
    } catch (error) {
        next(error);
    }
};

/**
 * POST /api/devices/:id/approve
 * Approves a device, making it active and able to submit data.
 */
exports.approveDevice = async (req, res, next) => {
  const { id } = req.params; // The primary key (UUID) of the device to approve.
  const supabase = getUserClient(req);
  
  // ✅ THE FINAL FIX: Get the user's ID from the JWT token provided by the userAuth middleware.
  const approvingUserId = req.user.sub; 

  // Call the correct 'approve_esp_device' function from your SQL schema.
  const { data, error } = await supabase.rpc('approve_esp_device', { 
    p_device_id: id,
    p_approved_by: approvingUserId,
    p_notes: 'Approved via E2E test script'
  });

  if (error) return next(error);
  if (!data.success) return res.status(404).json(data);
  
  res.status(200).json(data);
};

/**
 * POST /api/devices/:id/bind
 * Binds a device to an asset like a truck or a destination.
 */
exports.bindDevice = async (req, res, next) => {
    try {
        const supabase = getAdminClient();
        const { id } = req.params;
        const { bound_to_type, bound_to_id } = req.body;

        // Calls the 'bind_esp_device_to_asset' function from your SQL file.
        const { data, error } = await supabase.rpc('bind_esp_device_to_asset', {
            p_device_id: id,
            p_bound_to_type: bound_to_type,
            p_bound_to_id: bound_to_id,
        });

        if (error) throw error;
        // The RPC function should return a success message.
        res.status(200).json({ success: true, message: 'Device bound successfully' });
    } catch (error) {
        next(error);
    }
};

/**
 * POST /api/devices/:id/rotate-key
 * Rotates the API key for a specified device.
 */
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

/**
 * POST /api/devices/:id/blacklist
 * Blacklists a device, revoking its access.
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
        res.status(200).json(data);
    } catch (error) {
        next(error);
    }
};

/**
 * GET /api/devices/:id/logs
 * Retrieves authentication and data logs for a specific device.
 */
exports.getDeviceLogs = async (req, res, next) => {
    try {
        const supabase = getUserClient(req);
        const { id } = req.params;
        const { limit = 50 } = req.query;

        // First, get the device's unique string ID to query the logs.
        const { data: device, error: deviceError } = await supabase
            .from('esp_devices')
            .select('esp_device_id')
            .eq('id', id)
            .single();

        if (deviceError || !device) {
            return res.status(404).json({ success: false, error: 'Device not found' });
        }

        // Fetch logs using the esp_device_id.
        const { data: logs, error: logsError } = await supabase
            .from('esp_auth_log')
            .select('*')
            .eq('esp_device_id', device.esp_device_id)
            .order('timestamp', { ascending: false })
            .limit(limit);
        
        if (logsError) return next(logsError);

        res.status(200).json({ success: true, logs: logs });
    } catch (error) {
        next(error);
    }
};
