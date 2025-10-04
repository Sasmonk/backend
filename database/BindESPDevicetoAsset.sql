-- CRITICAL: Bind ESP device to truck/destination
CREATE OR REPLACE FUNCTION bind_esp_device(
    p_device_id UUID,
    p_bound_to_type VARCHAR(50),
    p_bound_to_id UUID
)
RETURNS JSON AS $$
BEGIN
    UPDATE esp_devices
    SET bound_to_type = p_bound_to_type,
        bound_to_id = p_bound_to_id
    WHERE id = p_device_id;
    
    RETURN json_build_object('success', FOUND);
END;
$$ LANGUAGE plpgsql;

-- Add index for faster ESP32 lookups
CREATE INDEX idx_esp_devices_esp_id_api_key 
ON esp_devices(esp_device_id, api_key);