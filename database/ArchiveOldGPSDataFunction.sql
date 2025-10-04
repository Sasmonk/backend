-- CRITICAL: Missing function referenced in maintenance
CREATE OR REPLACE FUNCTION archive_old_gps_data(p_days_old INTEGER DEFAULT 2)
RETURNS JSON AS $$
DECLARE
    v_archived_count INTEGER;
BEGIN
    DELETE FROM gps_tracking
    WHERE timestamp < CURRENT_TIMESTAMP - (p_days_old || ' days')::INTERVAL;
    
    GET DIAGNOSTICS v_archived_count = ROW_COUNT;
    
    RETURN json_build_object(
        'success', true,
        'archived_count', v_archived_count
    );
END;
$$ LANGUAGE plpgsql;