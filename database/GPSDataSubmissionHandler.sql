-- ============================================
-- FUNCTION: SUBMIT GPS DATA
-- Securely handles GPS data submission from an ESP32 device
-- ============================================
CREATE OR REPLACE FUNCTION submit_gps_data(
    p_esp_device_id VARCHAR,
    p_api_key VARCHAR,
    p_latitude DECIMAL,
    p_longitude DECIMAL,
    p_speed DECIMAL DEFAULT NULL,
    p_heading DECIMAL DEFAULT NULL,
    p_altitude DECIMAL DEFAULT NULL,
    p_accuracy DECIMAL DEFAULT NULL,
    p_battery_level INTEGER DEFAULT NULL,
    p_signal_strength INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_auth_result JSON;
    v_device_id UUID;
    v_bound_to_id UUID;
    v_shipment RECORD;
    v_result JSON;
BEGIN
    -- 1. Authenticate the device first
    v_auth_result := authenticate_esp_device(p_esp_device_id, p_api_key, p_endpoint := 'gps_submit');
    
    IF NOT (v_auth_result->>'authenticated')::BOOLEAN THEN
        RETURN v_auth_result; -- Return the authentication failure message
    END IF;

    -- Extract details from successful authentication
    v_device_id := (v_auth_result->>'device_id')::UUID;
    v_bound_to_id := (v_auth_result->>'bound_to_id')::UUID;

    -- 2. Find the active shipment for this truck
    SELECT s.id as shipment_id, s.status
    INTO v_shipment
    FROM shipments s
    WHERE s.truck_id = v_bound_to_id
      AND s.status IN ('pending', 'in_transit')
    ORDER BY s.created_at DESC
    LIMIT 1;

    IF v_shipment IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'no_active_shipment',
            'message', 'No active shipment found for this device/truck.'
        );
    END IF;

    -- 3. If shipment is 'pending', update its status to 'in_transit'
    IF v_shipment.status = 'pending' THEN
        UPDATE shipments
        SET status = 'in_transit',
            started_at = CURRENT_TIMESTAMP
        WHERE id = v_shipment.shipment_id;
    END IF;

    -- 4. Insert the GPS data into the tracking table
    INSERT INTO gps_tracking (
        shipment_id,
        truck_id,
        latitude,
        longitude,
        speed,
        heading,
        altitude,
        accuracy,
        esp_device_id,
        battery_level,
        signal_strength
    ) VALUES (
        v_shipment.shipment_id,
        v_bound_to_id,
        p_latitude,
        p_longitude,
        p_speed,
        p_heading,
        p_altitude,
        p_accuracy,
        p_esp_device_id,
        p_battery_level,
        p_signal_strength
    );

    -- 5. Return success message
    v_result := json_build_object(
        'success', true,
        'message', 'GPS data recorded successfully',
        'shipment_id', v_shipment.shipment_id
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;