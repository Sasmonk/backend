-- ============================================
-- ESP32 DEVICE SECURITY SYSTEM
-- Complete security implementation for IoT devices
-- ============================================

-- ============================================
-- 1. ESP DEVICES TABLE
-- Central registry for all ESP32 devices with security
-- ============================================
CREATE TABLE esp_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    
    -- Device identifiers
    esp_device_id VARCHAR(100) UNIQUE NOT NULL,
    device_name VARCHAR(255), -- User-friendly name
    device_type VARCHAR(50) NOT NULL CHECK (device_type IN ('gps_tracker', 'rfid_reader')),
    
    -- Security credentials (store hash, not plain text in production)
    api_key VARCHAR(255) UNIQUE NOT NULL, -- Unique secret key per device
    api_secret_hash TEXT, -- For additional security layer (optional)
    
    -- Device binding to specific resources
    bound_to_type VARCHAR(50) CHECK (bound_to_type IN ('truck', 'destination')),
    bound_to_id UUID, -- ID of truck or destination
    
    -- Status and approval
    is_active BOOLEAN DEFAULT true,
    is_approved BOOLEAN DEFAULT false, -- Must be approved before use
    approval_notes TEXT,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    
    -- Security monitoring
    last_authenticated_at TIMESTAMP WITH TIME ZONE,
    last_seen_at TIMESTAMP WITH TIME ZONE,
    failed_auth_attempts INTEGER DEFAULT 0,
    last_failed_auth_at TIMESTAMP WITH TIME ZONE,
    
    -- Blacklist/Revocation
    is_blacklisted BOOLEAN DEFAULT false,
    blacklisted_at TIMESTAMP WITH TIME ZONE,
    blacklist_reason TEXT,
    blacklisted_by UUID REFERENCES users(id),
    
    -- Rate limiting
    requests_last_hour INTEGER DEFAULT 0,
    last_rate_limit_reset TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Device metadata
    firmware_version VARCHAR(50),
    hardware_version VARCHAR(50),
    mac_address VARCHAR(17),
    
    -- Timestamps
    registered_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_esp_devices_company ON esp_devices(company_id);
CREATE INDEX idx_esp_devices_device_id ON esp_devices(esp_device_id);
CREATE INDEX idx_esp_devices_api_key ON esp_devices(api_key);
CREATE INDEX idx_esp_devices_active ON esp_devices(is_active, is_approved);
CREATE INDEX idx_esp_devices_type ON esp_devices(device_type);

-- ============================================
-- 2. ESP AUTHENTICATION LOG
-- Track all authentication attempts
-- ============================================
CREATE TABLE esp_auth_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    esp_device_id VARCHAR(100) NOT NULL,
    company_id UUID REFERENCES companies(id),
    
    -- Authentication details
    api_key_provided VARCHAR(255),
    auth_result VARCHAR(20) NOT NULL CHECK (auth_result IN ('success', 'invalid_key', 'device_not_found', 'device_disabled', 'blacklisted', 'not_approved', 'rate_limited')),
    
    -- Request metadata
    ip_address VARCHAR(45),
    user_agent TEXT,
    endpoint VARCHAR(255), -- Which API endpoint was accessed
    
    -- Timestamp
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_esp_auth_log_device ON esp_auth_log(esp_device_id, timestamp DESC);
CREATE INDEX idx_esp_auth_log_result ON esp_auth_log(auth_result, timestamp DESC);
CREATE INDEX idx_esp_auth_log_company ON esp_auth_log(company_id, timestamp DESC);

-- ============================================
-- 3. ESP DATA SUBMISSION LOG
-- Track all data submissions from devices
-- ============================================
CREATE TABLE esp_data_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    esp_device_id VARCHAR(100) NOT NULL,
    company_id UUID NOT NULL REFERENCES companies(id),
    device_type VARCHAR(50) NOT NULL,
    
    -- Data submission details
    data_type VARCHAR(50) NOT NULL CHECK (data_type IN ('gps_location', 'rfid_scan', 'heartbeat', 'diagnostic')),
    payload_size INTEGER, -- Size in bytes
    
    -- Processing status
    processing_status VARCHAR(50) DEFAULT 'pending' CHECK (processing_status IN ('pending', 'processed', 'failed', 'rejected')),
    error_message TEXT,
    
    -- Metadata
    ip_address VARCHAR(45),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_esp_data_log_device ON esp_data_log(esp_device_id, timestamp DESC);
CREATE INDEX idx_esp_data_log_company ON esp_data_log(company_id, timestamp DESC);
CREATE INDEX idx_esp_data_log_status ON esp_data_log(processing_status, timestamp DESC);

-- ============================================
-- 4. DEVICE PERMISSIONS TABLE
-- Fine-grained permissions for what each device can do
-- ============================================
CREATE TABLE esp_device_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES esp_devices(id) ON DELETE CASCADE,
    
    -- Permissions
    can_send_gps BOOLEAN DEFAULT false,
    can_send_rfid BOOLEAN DEFAULT false,
    can_read_shipments BOOLEAN DEFAULT false,
    can_update_status BOOLEAN DEFAULT false,
    
    -- Rate limits
    max_requests_per_hour INTEGER DEFAULT 1000,
    max_payload_size_kb INTEGER DEFAULT 100,
    
    -- Geo-fencing (optional)
    allowed_latitude_min DECIMAL(10, 8),
    allowed_latitude_max DECIMAL(10, 8),
    allowed_longitude_min DECIMAL(11, 8),
    allowed_longitude_max DECIMAL(11, 8),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_esp_device_permissions_device ON esp_device_permissions(device_id);

-- ============================================
-- 5. DEVICE ANOMALY DETECTION LOG
-- Track suspicious activities
-- ============================================
CREATE TABLE esp_anomaly_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    esp_device_id VARCHAR(100) NOT NULL,
    company_id UUID REFERENCES companies(id),
    
    -- Anomaly details
    anomaly_type VARCHAR(50) NOT NULL CHECK (anomaly_type IN ('impossible_speed', 'geo_fence_violation', 'duplicate_submission', 'unusual_pattern', 'suspicious_location', 'rate_limit_exceeded')),
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    description TEXT,
    
    -- Data involved
    related_data JSONB,
    
    -- Resolution
    is_resolved BOOLEAN DEFAULT false,
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolution_notes TEXT,
    
    -- Auto-action taken
    auto_action VARCHAR(50) CHECK (auto_action IN ('none', 'alert_sent', 'device_suspended', 'data_rejected')),
    
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_esp_anomaly_log_device ON esp_anomaly_log(esp_device_id, timestamp DESC);
CREATE INDEX idx_esp_anomaly_log_severity ON esp_anomaly_log(severity, is_resolved);
CREATE INDEX idx_esp_anomaly_log_company ON esp_anomaly_log(company_id, timestamp DESC);

-- ============================================
-- 6. AUTHENTICATION FUNCTION
-- Verifies device credentials before data submission
-- ============================================
CREATE OR REPLACE FUNCTION authenticate_esp_device(
    p_device_id VARCHAR(100),
    p_api_key VARCHAR(255),
    p_ip_address VARCHAR(45) DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_endpoint VARCHAR(255) DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_device RECORD;
    v_result JSON;
    v_auth_success BOOLEAN := false;
    v_company_id UUID;
BEGIN
    -- Get device details
    SELECT * INTO v_device
    FROM esp_devices
    WHERE esp_device_id = p_device_id;
    
    -- Device not found
    IF v_device IS NULL THEN
        INSERT INTO esp_auth_log (esp_device_id, api_key_provided, auth_result, ip_address, user_agent, endpoint)
        VALUES (p_device_id, LEFT(p_api_key, 10) || '...', 'device_not_found', p_ip_address, p_user_agent, p_endpoint);
        
        RETURN json_build_object(
            'authenticated', false,
            'reason', 'device_not_found',
            'message', 'ESP device ID not registered in system'
        );
    END IF;
    
    v_company_id := v_device.company_id;
    
    -- Check rate limiting
    IF v_device.requests_last_hour > 1000 THEN
        INSERT INTO esp_auth_log (esp_device_id, company_id, api_key_provided, auth_result, ip_address, user_agent, endpoint)
        VALUES (p_device_id, v_company_id, LEFT(p_api_key, 10) || '...', 'rate_limited', p_ip_address, p_user_agent, p_endpoint);
        
        RETURN json_build_object(
            'authenticated', false,
            'reason', 'rate_limited',
            'message', 'Device has exceeded hourly rate limit'
        );
    END IF;
    
    -- Device blacklisted
    IF v_device.is_blacklisted THEN
        INSERT INTO esp_auth_log (esp_device_id, company_id, api_key_provided, auth_result, ip_address, user_agent, endpoint)
        VALUES (p_device_id, v_company_id, LEFT(p_api_key, 10) || '...', 'blacklisted', p_ip_address, p_user_agent, p_endpoint);
        
        RETURN json_build_object(
            'authenticated', false,
            'reason', 'device_blacklisted',
            'message', 'Device has been blacklisted: ' || COALESCE(v_device.blacklist_reason, 'No reason provided')
        );
    END IF;
    
    -- Device not approved
    IF NOT v_device.is_approved THEN
        INSERT INTO esp_auth_log (esp_device_id, company_id, api_key_provided, auth_result, ip_address, user_agent, endpoint)
        VALUES (p_device_id, v_company_id, LEFT(p_api_key, 10) || '...', 'not_approved', p_ip_address, p_user_agent, p_endpoint);
        
        RETURN json_build_object(
            'authenticated', false,
            'reason', 'device_not_approved',
            'message', 'Device registration pending approval'
        );
    END IF;
    
    -- Device inactive
    IF NOT v_device.is_active THEN
        INSERT INTO esp_auth_log (esp_device_id, company_id, api_key_provided, auth_result, ip_address, user_agent, endpoint)
        VALUES (p_device_id, v_company_id, LEFT(p_api_key, 10) || '...', 'device_disabled', p_ip_address, p_user_agent, p_endpoint);
        
        RETURN json_build_object(
            'authenticated', false,
            'reason', 'device_inactive',
            'message', 'Device has been deactivated'
        );
    END IF;
    
    -- Verify API key
    IF v_device.api_key = p_api_key THEN
        v_auth_success := true;
        
        -- Update device stats
        UPDATE esp_devices
        SET last_authenticated_at = CURRENT_TIMESTAMP,
            last_seen_at = CURRENT_TIMESTAMP,
            failed_auth_attempts = 0,
            requests_last_hour = CASE 
                WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - last_rate_limit_reset)) > 3600 
                THEN 1 
                ELSE requests_last_hour + 1 
            END,
            last_rate_limit_reset = CASE 
                WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - last_rate_limit_reset)) > 3600 
                THEN CURRENT_TIMESTAMP 
                ELSE last_rate_limit_reset 
            END
        WHERE id = v_device.id;
        
        -- Log success
        INSERT INTO esp_auth_log (esp_device_id, company_id, api_key_provided, auth_result, ip_address, user_agent, endpoint)
        VALUES (p_device_id, v_company_id, LEFT(p_api_key, 10) || '...', 'success', p_ip_address, p_user_agent, p_endpoint);
        
        RETURN json_build_object(
            'authenticated', true,
            'device_id', v_device.id,
            'company_id', v_device.company_id,
            'device_type', v_device.device_type,
            'device_name', v_device.device_name,
            'bound_to_type', v_device.bound_to_type,
            'bound_to_id', v_device.bound_to_id,
            'permissions', (
                SELECT json_build_object(
                    'can_send_gps', can_send_gps,
                    'can_send_rfid', can_send_rfid,
                    'can_read_shipments', can_read_shipments,
                    'can_update_status', can_update_status
                )
                FROM esp_device_permissions
                WHERE device_id = v_device.id
            )
        );
    ELSE
        -- Invalid API key
        UPDATE esp_devices
        SET failed_auth_attempts = failed_auth_attempts + 1,
            last_failed_auth_at = CURRENT_TIMESTAMP
        WHERE id = v_device.id;
        
        -- Auto-blacklist after 10 failed attempts
        IF v_device.failed_auth_attempts + 1 >= 10 THEN
            UPDATE esp_devices
            SET is_blacklisted = true,
                blacklisted_at = CURRENT_TIMESTAMP,
                blacklist_reason = 'Automatic blacklist: 10 consecutive failed authentication attempts'
            WHERE id = v_device.id;
        END IF;
        
        INSERT INTO esp_auth_log (esp_device_id, company_id, api_key_provided, auth_result, ip_address, user_agent, endpoint)
        VALUES (p_device_id, v_company_id, LEFT(p_api_key, 10) || '...', 'invalid_key', p_ip_address, p_user_agent, p_endpoint);
        
        RETURN json_build_object(
            'authenticated', false,
            'reason', 'invalid_api_key',
            'message', 'API key is incorrect',
            'failed_attempts', v_device.failed_auth_attempts + 1
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. GENERATE API KEY FUNCTION
-- Creates secure API keys for new devices
-- ============================================
CREATE OR REPLACE FUNCTION generate_esp_api_key()
RETURNS VARCHAR(255) AS $$
DECLARE
    v_key VARCHAR(255);
BEGIN
    -- Generate random API key: prefix + timestamp + random
    v_key := 'esp_' || 
             TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS') || '_' ||
             encode(gen_random_bytes(32), 'hex');
    
    RETURN v_key;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 8. REGISTER NEW DEVICE FUNCTION
-- Simplified device registration
-- ============================================
CREATE OR REPLACE FUNCTION register_esp_device(
    p_company_id UUID,
    p_device_id VARCHAR(100),
    p_device_name VARCHAR(255),
    p_device_type VARCHAR(50),
    p_bound_to_type VARCHAR(50) DEFAULT NULL,
    p_bound_to_id UUID DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_api_key VARCHAR(255);
    v_device_uuid UUID;
    v_result JSON;
BEGIN
    -- Generate API key
    v_api_key := generate_esp_api_key();
    
    -- Insert device
    INSERT INTO esp_devices (
        company_id,
        esp_device_id,
        device_name,
        device_type,
        api_key,
        bound_to_type,
        bound_to_id,
        is_active,
        is_approved
    ) VALUES (
        p_company_id,
        p_device_id,
        p_device_name,
        p_device_type,
        v_api_key,
        p_bound_to_type,
        p_bound_to_id,
        true,
        false -- Requires approval
    ) RETURNING id INTO v_device_uuid;
    
    -- Create default permissions
    INSERT INTO esp_device_permissions (
        device_id,
        can_send_gps,
        can_send_rfid,
        can_read_shipments,
        can_update_status
    ) VALUES (
        v_device_uuid,
        CASE WHEN p_device_type = 'gps_tracker' THEN true ELSE false END,
        CASE WHEN p_device_type = 'rfid_reader' THEN true ELSE false END,
        true,
        false
    );
    
    v_result := json_build_object(
        'success', true,
        'device_id', v_device_uuid,
        'esp_device_id', p_device_id,
        'api_key', v_api_key,
        'status', 'pending_approval',
        'message', 'Device registered successfully. Awaiting admin approval.'
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 9. APPROVE DEVICE FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION approve_esp_device(
    p_device_id UUID,
    p_approved_by UUID,
    p_notes TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    UPDATE esp_devices
    SET is_approved = true,
        approved_by = p_approved_by,
        approved_at = CURRENT_TIMESTAMP,
        approval_notes = p_notes
    WHERE id = p_device_id;
    
    IF FOUND THEN
        v_result := json_build_object(
            'success', true,
            'message', 'Device approved successfully'
        );
    ELSE
        v_result := json_build_object(
            'success', false,
            'message', 'Device not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 10. BLACKLIST DEVICE FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION blacklist_esp_device(
    p_device_id UUID,
    p_reason TEXT,
    p_blacklisted_by UUID
)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    UPDATE esp_devices
    SET is_blacklisted = true,
        blacklisted_at = CURRENT_TIMESTAMP,
        blacklist_reason = p_reason,
        blacklisted_by = p_blacklisted_by,
        is_active = false
    WHERE id = p_device_id;
    
    IF FOUND THEN
        v_result := json_build_object(
            'success', true,
            'message', 'Device blacklisted successfully'
        );
    ELSE
        v_result := json_build_object(
            'success', false,
            'message', 'Device not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 11. REVOKE/ROTATE API KEY
-- ============================================
CREATE OR REPLACE FUNCTION rotate_esp_api_key(
    p_device_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_new_key VARCHAR(255);
    v_result JSON;
BEGIN
    -- Generate new key
    v_new_key := generate_esp_api_key();
    
    -- Update device
    UPDATE esp_devices
    SET api_key = v_new_key,
        failed_auth_attempts = 0,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_device_id;
    
    IF FOUND THEN
        v_result := json_build_object(
            'success', true,
            'new_api_key', v_new_key,
            'message', 'API key rotated successfully'
        );
    ELSE
        v_result := json_build_object(
            'success', false,
            'message', 'Device not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 12. CHECK GEO-FENCE VIOLATION
-- ============================================
CREATE OR REPLACE FUNCTION check_geofence_violation(
    p_device_id UUID,
    p_latitude DECIMAL(10, 8),
    p_longitude DECIMAL(11, 8)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_permissions RECORD;
    v_violation BOOLEAN := false;
BEGIN
    SELECT * INTO v_permissions
    FROM esp_device_permissions
    WHERE device_id = p_device_id;
    
    IF v_permissions IS NULL THEN
        RETURN false; -- No geo-fence configured
    END IF;
    
    -- Check if coordinates are within allowed bounds
    IF v_permissions.allowed_latitude_min IS NOT NULL AND
       v_permissions.allowed_latitude_max IS NOT NULL AND
       v_permissions.allowed_longitude_min IS NOT NULL AND
       v_permissions.allowed_longitude_max IS NOT NULL THEN
       
        IF p_latitude < v_permissions.allowed_latitude_min OR
           p_latitude > v_permissions.allowed_latitude_max OR
           p_longitude < v_permissions.allowed_longitude_min OR
           p_longitude > v_permissions.allowed_longitude_max THEN
            v_violation := true;
        END IF;
    END IF;
    
    RETURN v_violation;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 13. VIEWS FOR MONITORING
-- ============================================

-- Active devices overview
CREATE OR REPLACE VIEW v_esp_devices_status AS
SELECT
    d.id,
    d.esp_device_id,
    d.device_name,
    d.device_type,
    d.company_id,
    c.company_name,
    d.is_active,
    d.is_approved,
    d.is_blacklisted,
    d.last_authenticated_at,
    d.last_seen_at,
    d.failed_auth_attempts,
    d.requests_last_hour,
    CASE
        WHEN d.is_blacklisted THEN 'Blacklisted'
        WHEN NOT d.is_approved THEN 'Pending Approval'
        WHEN NOT d.is_active THEN 'Inactive'
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - d.last_seen_at)) < 300 THEN 'Online'
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - d.last_seen_at)) < 3600 THEN 'Recently Active'
        ELSE 'Offline'
    END as connection_status
FROM esp_devices d
JOIN companies c ON d.company_id = c.id;

-- Failed authentication attempts
CREATE OR REPLACE VIEW v_esp_failed_auth AS
SELECT
    esp_device_id,
    COUNT(*) as failed_attempts,
    MAX(timestamp) as last_failed_attempt,
    array_agg(DISTINCT ip_address) as ip_addresses
FROM esp_auth_log
WHERE auth_result != 'success'
AND timestamp > CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY esp_device_id
HAVING COUNT(*) > 5
ORDER BY failed_attempts DESC;

-- Device activity summary
CREATE OR REPLACE VIEW v_esp_activity_summary AS
SELECT
    d.esp_device_id,
    d.device_name,
    d.device_type,
    c.company_name,
    COUNT(DISTINCT DATE(al.timestamp)) as active_days_last_month,
    COUNT(*) FILTER (WHERE al.auth_result = 'success') as successful_auths,
    COUNT(*) FILTER (WHERE al.auth_result != 'success') as failed_auths,
    COUNT(dl.id) as data_submissions,
    d.last_seen_at
FROM esp_devices d
JOIN companies c ON d.company_id = c.id
LEFT JOIN esp_auth_log al ON d.esp_device_id = al.esp_device_id
    AND al.timestamp > CURRENT_TIMESTAMP - INTERVAL '30 days'
LEFT JOIN esp_data_log dl ON d.esp_device_id = dl.esp_device_id
    AND dl.timestamp > CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY d.esp_device_id, d.device_name, d.device_type, c.company_name, d.last_seen_at;

-- ============================================
-- 14. CLEANUP OLD LOGS (Maintenance)
-- ============================================
CREATE OR REPLACE FUNCTION cleanup_esp_logs(p_days_old INTEGER DEFAULT 90)
RETURNS JSON AS $$
DECLARE
    v_auth_deleted INTEGER;
    v_data_deleted INTEGER;
    v_anomaly_deleted INTEGER;
BEGIN
    -- Delete old auth logs
    DELETE FROM esp_auth_log
    WHERE timestamp < CURRENT_TIMESTAMP - (p_days_old || ' days')::INTERVAL;
    GET DIAGNOSTICS v_auth_deleted = ROW_COUNT;
    
    -- Delete old data logs
    DELETE FROM esp_data_log
    WHERE timestamp < CURRENT_TIMESTAMP - (p_days_old || ' days')::INTERVAL;
    GET DIAGNOSTICS v_data_deleted = ROW_COUNT;
    
    -- Delete resolved anomalies
    DELETE FROM esp_anomaly_log
    WHERE is_resolved = true
    AND timestamp < CURRENT_TIMESTAMP - (p_days_old || ' days')::INTERVAL;
    GET DIAGNOSTICS v_anomaly_deleted = ROW_COUNT;
    
    RETURN json_build_object(
        'success', true,
        'auth_logs_deleted', v_auth_deleted,
        'data_logs_deleted', v_data_deleted,
        'anomaly_logs_deleted', v_anomaly_deleted
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE esp_devices IS 'Central registry of all ESP32 IoT devices with security credentials';
COMMENT ON TABLE esp_auth_log IS 'Authentication attempt log for security monitoring';
COMMENT ON TABLE esp_data_log IS 'Track all data submissions from ESP devices';
COMMENT ON TABLE esp_device_permissions IS 'Fine-grained permissions for each device';
COMMENT ON TABLE esp_anomaly_log IS 'Suspicious activity detection and tracking';

COMMENT ON FUNCTION authenticate_esp_device IS 'Validates ESP device credentials before allowing data submission';
COMMENT ON FUNCTION register_esp_device IS 'Register new ESP32 device with auto-generated API key';
COMMENT ON FUNCTION approve_esp_device IS 'Admin approval required before device can submit data';
COMMENT ON FUNCTION blacklist_esp_device IS 'Permanently disable a compromised or malicious device';
COMMENT ON FUNCTION rotate_esp_api_key IS 'Generate new API key for security (invalidates old key)';

-- ============================================
-- END OF ESP32 SECURITY SYSTEM
-- ============================================