CREATE OR REPLACE FUNCTION get_shipment_realtime_status(p_shipment_id UUID)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_build_object(
        'shipment_details', s,
        'company', c,
        'truck', t,
        'destination', rd,
        'items', (SELECT json_agg(si.*) FROM shipment_items si WHERE si.shipment_id = s.id),
        'latest_location', (
            SELECT json_build_object('lat', gt.latitude, 'lng', gt.longitude, 'timestamp', gt.timestamp)
            FROM gps_tracking gt
            WHERE gt.shipment_id = s.id
            ORDER BY gt.timestamp DESC
            LIMIT 1
        )
    )
    INTO v_result
    FROM shipments s
    JOIN companies c ON s.company_id = c.id
    JOIN trucks t ON s.truck_id = t.id
    JOIN rfid_destinations rd ON s.destination_id = rd.id
    WHERE s.id = p_shipment_id;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;