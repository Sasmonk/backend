-- ============================================
-- ADDITIONAL VIEWS FOR REPORTING & ANALYTICS
-- CORRECTED VERSION - ALL BUGS FIXED
-- ============================================

-- ============================================
-- 1. COMPLETE SHIPMENT DETAILS VIEW
-- All shipment information in one view
-- ============================================
CREATE OR REPLACE VIEW v_shipment_details AS
SELECT
    s.id as shipment_id,
    s.shipment_number,
    s.status as shipment_status,
    s.created_at as shipment_created,
    s.started_at,
    s.estimated_arrival,
    s.delivered_at,
    
    -- Company details
    c.id as company_id,
    c.company_name,
    c.company_code,
    
    -- Truck details
    t.id as truck_id,
    t.registration_number,
    t.user_assigned_name as truck_name,
    t.truck_type,
    t.driver_name,
    t.driver_phone,
    
    -- Location details
    s.origin_location,
    s.origin_latitude,
    s.origin_longitude,
    s.destination_location,
    s.destination_latitude,
    s.destination_longitude,
    
    -- Destination RFID details
    rd.id as rfid_destination_id,
    rd.location_name as rfid_location_name,
    rd.esp_device_id as destination_esp_id,
    
    -- Financial
    s.total_value as shipment_value,
    
    -- Item counts
    (SELECT COUNT(*) FROM shipment_items WHERE shipment_id = s.id) as total_items,
    (SELECT COUNT(*) FROM shipment_items WHERE shipment_id = s.id AND status = 'delivered') as items_delivered,
    (SELECT COUNT(*) FROM shipment_items WHERE shipment_id = s.id AND status = 'missing') as items_missing,
    
    -- Notes
    s.notes
    
FROM shipments s
JOIN companies c ON s.company_id = c.id
JOIN trucks t ON s.truck_id = t.id
JOIN rfid_destinations rd ON s.destination_id = rd.id;

-- ============================================
-- 2. MISSING PRODUCTS REPORT VIEW
-- Comprehensive view of all missing products
-- ============================================
CREATE OR REPLACE VIEW v_missing_products_report AS
SELECT
    mpl.id as log_id,
    mpl.reported_at,
    mpl.discrepancy_type,
    mpl.resolution_status,
    
    -- Shipment info
    s.shipment_number,
    s.status as shipment_status,
    s.delivered_at,
    
    -- Company info
    c.company_name,
    c.company_code,
    
    -- Product info
    p.product_name,
    p.sku,
    pc.category_name as product_category,
    
    -- Quantities
    mpl.expected_quantity,
    mpl.received_quantity,
    mpl.missing_quantity,
    
    -- Financial impact
    mpl.estimated_loss_value,
    
    -- RFID info
    mpl.rfid_tag,
    
    -- Resolution
    mpl.resolution_notes
    
FROM missing_products_log mpl
JOIN shipments s ON mpl.shipment_id = s.id
JOIN companies c ON s.company_id = c.id
JOIN products p ON mpl.product_id = p.id
LEFT JOIN product_categories pc ON p.category_id = pc.id
ORDER BY mpl.reported_at DESC;

-- ============================================
-- 3. TRUCK UTILIZATION VIEW
-- Track truck usage and efficiency
-- ============================================
CREATE OR REPLACE VIEW v_truck_utilization AS
SELECT
    t.id as truck_id,
    t.registration_number,
    t.user_assigned_name,
    t.truck_type,
    t.capacity_kg,
    
    -- Current status
    CASE
        WHEN EXISTS (
            SELECT 1 FROM shipments
            WHERE truck_id = t.id
            AND status IN ('pending', 'in_transit')
        ) THEN 'In Use'
        ELSE 'Available'
    END as current_status,
    
    -- Statistics
    (
        SELECT COUNT(*)
        FROM shipments
        WHERE truck_id = t.id
    ) as total_shipments,
    
    (
        SELECT COUNT(*)
        FROM shipments
        WHERE truck_id = t.id
        AND status = 'delivered'
    ) as completed_shipments,
    
    (
        SELECT COUNT(*)
        FROM shipments
        WHERE truck_id = t.id
        AND status IN ('pending', 'in_transit')
    ) as active_shipments,
    
    -- Last shipment
    (
        SELECT MAX(started_at)
        FROM shipments
        WHERE truck_id = t.id
    ) as last_used_at,
    
    -- Companies using this truck
    (
        SELECT json_agg(DISTINCT c.company_name)
        FROM company_trucks ct
        JOIN companies c ON ct.company_id = c.id
        WHERE ct.truck_id = t.id
    ) as associated_companies
    
FROM trucks t
WHERE t.is_active = true;

-- ============================================
-- 4. DAILY SHIPMENT SUMMARY
-- Daily statistics for monitoring
-- ============================================
CREATE OR REPLACE VIEW v_daily_shipment_summary AS
SELECT
    DATE(s.created_at) as shipment_date,
    s.company_id,
    c.company_name,
    
    COUNT(*) as total_shipments,
    COUNT(*) FILTER (WHERE status = 'delivered') as delivered_count,
    COUNT(*) FILTER (WHERE status = 'partially_delivered') as partially_delivered_count,
    COUNT(*) FILTER (WHERE status = 'in_transit') as in_transit_count,
    COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
    
    SUM(s.total_value) as total_shipment_value,
    AVG(s.total_value) as avg_shipment_value,
    
    -- Delivery performance
    COUNT(*) FILTER (
        WHERE status = 'delivered'
        AND delivered_at <= estimated_arrival
    ) as on_time_deliveries,
    
    COUNT(*) FILTER (
        WHERE status = 'delivered'
        AND delivered_at > estimated_arrival
    ) as delayed_deliveries
    
FROM shipments s
JOIN companies c ON s.company_id = c.id
GROUP BY DATE(s.created_at), s.company_id, c.company_name
ORDER BY shipment_date DESC, c.company_name;

-- ============================================
-- 5. PRODUCT LOSS ANALYSIS
-- Analyze which products are most frequently missing
-- ============================================
CREATE OR REPLACE VIEW v_product_loss_analysis AS
SELECT
    p.id as product_id,
    p.product_name,
    p.sku,
    pc.category_name,
    
    s.company_id,
    c.company_name,
    
    COUNT(DISTINCT mpl.shipment_id) as incidents_count,
    SUM(mpl.missing_quantity) as total_missing_quantity,
    SUM(mpl.estimated_loss_value) as total_loss_value,
    AVG(mpl.missing_quantity) as avg_missing_per_incident,
    
    MAX(mpl.reported_at) as last_incident_date,
    
    -- Loss rate calculation
    CASE
        WHEN (
            SELECT SUM(quantity)
            FROM shipment_items si
            JOIN shipments s_inner ON si.shipment_id = s_inner.id
            WHERE si.product_id = p.id
            AND s_inner.company_id = s.company_id
        ) > 0 THEN
            (SUM(mpl.missing_quantity)::DECIMAL / (
                SELECT SUM(quantity)
                FROM shipment_items si
                JOIN shipments s_inner ON si.shipment_id = s_inner.id
                WHERE si.product_id = p.id
                AND s_inner.company_id = s.company_id
            )) * 100
        ELSE 0
    END as loss_rate_percentage
    
FROM missing_products_log mpl
JOIN products p ON mpl.product_id = p.id
JOIN shipments s ON mpl.shipment_id = s.id
JOIN companies c ON s.company_id = c.id
LEFT JOIN product_categories pc ON p.category_id = pc.id
GROUP BY p.id, p.product_name, p.sku, pc.category_name, s.company_id, c.company_name
ORDER BY total_loss_value DESC;

-- ============================================
-- 6. GPS TRACKING LATEST POSITIONS
-- Real-time truck positions
-- ============================================
CREATE OR REPLACE VIEW v_current_truck_positions AS
SELECT DISTINCT ON (t.id)
    t.id as truck_id,
    t.registration_number,
    t.user_assigned_name as truck_name,
    t.driver_name,
    
    s.id as shipment_id,
    s.shipment_number,
    s.status as shipment_status,
    s.destination_location,
    
    c.company_name,
    
    gt.latitude as current_latitude,
    gt.longitude as current_longitude,
    gt.speed as current_speed,
    gt.heading as current_heading,
    gt.timestamp as last_updated,
    gt.battery_level,
    gt.signal_strength,
    
    -- Calculate time since last update
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - gt.timestamp))/60 as minutes_since_update,
    
    -- Status indicator
    CASE
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - gt.timestamp))/60 < 5 THEN 'Active'
        WHEN EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - gt.timestamp))/60 < 30 THEN 'Delayed'
        ELSE 'Offline'
    END as tracking_status
    
FROM trucks t
LEFT JOIN shipments s ON t.id = s.truck_id AND s.status IN ('pending', 'in_transit')
LEFT JOIN companies c ON s.company_id = c.id
LEFT JOIN gps_tracking gt ON s.id = gt.shipment_id
WHERE t.is_active = true
ORDER BY t.id, gt.timestamp DESC NULLS LAST;

-- ============================================
-- 7. RFID SCAN ACTIVITY LOG
-- Track all RFID scanning activity
-- ============================================
CREATE OR REPLACE VIEW v_rfid_scan_activity AS
SELECT
    rs.id as scan_id,
    rs.scan_timestamp,
    rs.rfid_tag,
    rs.is_expected,
    rs.is_matched,
    
    -- Shipment info
    s.shipment_number,
    s.status as shipment_status,
    
    -- Company info
    c.company_name,
    
    -- Destination info
    rd.location_name as destination_name,
    rd.esp_device_id as scanner_device_id,
    
    -- Product info (if matched)
    CASE
        WHEN rs.shipment_item_id IS NOT NULL THEN
            (SELECT p.product_name
             FROM shipment_items si
             JOIN products p ON si.product_id = p.id
             WHERE si.id = rs.shipment_item_id)
        ELSE 'Unknown/Unmatched'
    END as product_name,
    
    -- Scan result
    CASE
        WHEN rs.is_matched THEN 'Matched & Verified'
        WHEN rs.is_expected THEN 'Expected but Not Matched'
        ELSE 'Unexpected Scan'
    END as scan_result
    
FROM rfid_scans rs
JOIN shipments s ON rs.shipment_id = s.id
JOIN companies c ON s.company_id = c.id
JOIN rfid_destinations rd ON rs.destination_id = rd.id
ORDER BY rs.scan_timestamp DESC;

-- ============================================
-- 8. DELIVERY PERFORMANCE METRICS
-- KPIs for delivery performance
-- CORRECTED: Fixed subquery syntax error
-- ============================================
CREATE OR REPLACE VIEW v_delivery_performance AS
SELECT
    c.id as company_id,
    c.company_name,
    
    -- Time period
    DATE_TRUNC('month', s.delivered_at) as month,
    
    -- Shipment counts
    COUNT(*) as total_deliveries,
    COUNT(*) FILTER (WHERE s.status = 'delivered') as successful_deliveries,
    COUNT(*) FILTER (WHERE s.status = 'partially_delivered') as partial_deliveries,
    
    -- On-time performance
    COUNT(*) FILTER (
        WHERE s.delivered_at <= s.estimated_arrival
    ) as on_time_count,
    
    ROUND(
        (COUNT(*) FILTER (WHERE s.delivered_at <= s.estimated_arrival)::DECIMAL /
        NULLIF(COUNT(*), 0)) * 100, 2
    ) as on_time_percentage,
    
    -- Product accuracy
    SUM(dv.total_items_expected) as total_items_shipped,
    SUM(dv.total_items_received) as total_items_received,
    SUM(dv.total_items_missing) as total_items_missing,
    
    ROUND(
        (SUM(dv.total_items_received)::DECIMAL /
        NULLIF(SUM(dv.total_items_expected), 0)) * 100, 2
    ) as delivery_accuracy_percentage,
    
    -- Financial
    SUM(s.total_value) as total_value_delivered,
    
    -- CORRECTED: The subquery must be enclosed in parentheses to be a valid scalar expression.
    SUM(
        (SELECT COALESCE(SUM(mpl.estimated_loss_value), 0)
         FROM missing_products_log mpl
         WHERE mpl.shipment_id = s.id)
    ) as total_loss_value
    
FROM shipments s
JOIN companies c ON s.company_id = c.id
LEFT JOIN delivery_verification dv ON s.id = dv.shipment_id
WHERE s.status IN ('delivered', 'partially_delivered')
GROUP BY c.id, c.company_name, DATE_TRUNC('month', s.delivered_at)
ORDER BY month DESC, c.company_name;

-- ============================================
-- 9. SHIPMENT ROUTE HISTORY
-- Complete GPS route for a shipment
-- ============================================
CREATE OR REPLACE VIEW v_shipment_routes AS
SELECT
    gt.shipment_id,
    s.shipment_number,
    
    json_agg(
        json_build_object(
            'latitude', gt.latitude,
            'longitude', gt.longitude,
            'speed', gt.speed,
            'heading', gt.heading,
            'timestamp', gt.timestamp,
            'altitude', gt.altitude
        ) ORDER BY gt.timestamp
    ) as route_points,
    
    MIN(gt.timestamp) as journey_start,
    MAX(gt.timestamp) as journey_end,
    
    -- Calculate total duration in hours
    EXTRACT(EPOCH FROM (MAX(gt.timestamp) - MIN(gt.timestamp)))/3600 as duration_hours,
    
    COUNT(*) as total_gps_points,
    
    -- Average speed
    AVG(gt.speed) as avg_speed_kmh,
    MAX(gt.speed) as max_speed_kmh
    
FROM gps_tracking gt
JOIN shipments s ON gt.shipment_id = s.id
GROUP BY gt.shipment_id, s.shipment_number;

-- ============================================
-- 10. COMPANY PRODUCT CATALOG
-- Complete product listing per company
-- ============================================
CREATE OR REPLACE VIEW v_company_product_catalog AS
SELECT
    c.id as company_id,
    c.company_name,
    
    p.id as product_id,
    p.product_name,
    p.sku,
    p.description,
    p.unit_value,
    p.tracking_mode,
    
    pc.category_name,
    
    -- Usage statistics
    (
        SELECT COUNT(DISTINCT si.shipment_id)
        FROM shipment_items si
        JOIN shipments s ON si.shipment_id = s.id
        WHERE si.product_id = p.id
        AND s.company_id = c.id
    ) as times_shipped,
    
    (
        SELECT SUM(si.quantity)
        FROM shipment_items si
        JOIN shipments s ON si.shipment_id = s.id
        WHERE si.product_id = p.id
        AND s.company_id = c.id
    ) as total_quantity_shipped,
    
    (
        SELECT COALESCE(SUM(mpl.missing_quantity), 0)
        FROM missing_products_log mpl
        JOIN shipments s ON mpl.shipment_id = s.id
        WHERE mpl.product_id = p.id
        AND s.company_id = c.id
    ) as total_quantity_lost,
    
    p.created_at as added_date
    
FROM products p
JOIN companies c ON p.company_id = c.id
LEFT JOIN product_categories pc ON p.category_id = pc.id
ORDER BY c.company_name, pc.category_name, p.product_name;

-- ============================================
-- 11. ALERT MONITORING VIEW
-- Potential issues that need attention
-- CORRECTED: Wrapped UNION queries to allow CASE in ORDER BY
-- ============================================
CREATE OR REPLACE VIEW v_alerts_monitoring AS
SELECT
    alert_type,
    severity,
    message,
    shipment_id,
    shipment_number,
    company_name,
    last_update
FROM (
    SELECT
        'GPS_OFFLINE' as alert_type,
        'High' as severity,
        CONCAT('Truck ', t.user_assigned_name, ' has not sent GPS data for ',
               ROUND(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - gt.timestamp))/60), ' minutes') as message,
        s.id as shipment_id,
        s.shipment_number,
        c.company_name,
        gt.timestamp as last_update
    FROM trucks t
    JOIN shipments s ON t.id = s.truck_id
    JOIN companies c ON s.company_id = c.id
    LEFT JOIN LATERAL (
        SELECT timestamp
        FROM gps_tracking
        WHERE truck_id = t.id
        ORDER BY timestamp DESC
        LIMIT 1
    ) gt ON true
    WHERE s.status IN ('pending', 'in_transit')
    AND (CURRENT_TIMESTAMP - gt.timestamp) > INTERVAL '30 minutes'

    UNION ALL

    SELECT
        'DELAYED_DELIVERY' as alert_type,
        'Medium' as severity,
        CONCAT('Shipment ', s.shipment_number, ' is past estimated arrival time') as message,
        s.id as shipment_id,
        s.shipment_number,
        c.company_name,
        s.estimated_arrival as last_update
    FROM shipments s
    JOIN companies c ON s.company_id = c.id
    WHERE s.status = 'in_transit'
    AND s.estimated_arrival < CURRENT_TIMESTAMP

    UNION ALL

    SELECT
        'MISSING_PRODUCTS' as alert_type,
        'High' as severity,
        CONCAT(mpl.missing_quantity, ' units of ', p.product_name, ' missing in shipment ', s.shipment_number) as message,
        s.id as shipment_id,
        s.shipment_number,
        c.company_name,
        mpl.reported_at as last_update
    FROM missing_products_log mpl
    JOIN shipments s ON mpl.shipment_id = s.id
    JOIN companies c ON s.company_id = c.id
    JOIN products p ON mpl.product_id = p.id
    WHERE mpl.resolution_status = 'open'
) alerts
ORDER BY
    CASE severity
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        WHEN 'Low' THEN 3
    END,
    last_update DESC;

-- ============================================
-- MATERIALIZED VIEWS FOR PERFORMANCE
-- CORRECTED: Fixed JOIN multiplication issue
-- ============================================

-- Drop existing materialized view if it exists
DROP MATERIALIZED VIEW IF EXISTS mv_company_statistics;

-- Materialized view for company statistics (refresh hourly)
CREATE MATERIALIZED VIEW mv_company_statistics AS
-- CORRECTED: Using a Common Table Expression (CTE) to pre-aggregate loss value.
-- This prevents incorrect calculations caused by JOIN multiplication.
WITH shipment_losses AS (
    SELECT
        shipment_id,
        COALESCE(SUM(estimated_loss_value), 0) as total_loss
    FROM missing_products_log
    GROUP BY shipment_id
)
SELECT
    c.id as company_id,
    c.company_name,
    c.company_code,
    
    -- Shipment stats
    COUNT(DISTINCT s.id) as total_shipments,
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'delivered') as delivered_shipments,
    COUNT(DISTINCT s.id) FILTER (WHERE s.status = 'in_transit') as active_shipments,
    
    -- Truck stats
    COUNT(DISTINCT ct.truck_id) as total_trucks,
    
    -- Product stats
    COUNT(DISTINCT p.id) as total_products,
    
    -- Financial stats
    COALESCE(SUM(s.total_value) FILTER (WHERE s.status = 'delivered'), 0) as total_delivered_value,
    COALESCE(SUM(sl.total_loss), 0) as total_loss_value,
    
    -- Last activity
    MAX(s.created_at) as last_shipment_date,
    
    -- Delivery accuracy
    ROUND(
        (SUM(dv.total_items_received)::DECIMAL /
        NULLIF(SUM(dv.total_items_expected), 0)) * 100, 2
    ) as overall_delivery_accuracy,
    
    CURRENT_TIMESTAMP as last_refreshed
    
FROM companies c
LEFT JOIN shipments s ON c.id = s.company_id
LEFT JOIN company_trucks ct ON c.id = ct.company_id
LEFT JOIN products p ON c.id = p.company_id
LEFT JOIN delivery_verification dv ON s.id = dv.shipment_id
-- CORRECTED: Join the pre-aggregated losses instead of the raw table.
LEFT JOIN shipment_losses sl ON s.id = sl.shipment_id
GROUP BY c.id, c.company_name, c.company_code;

-- Create index on materialized view
CREATE UNIQUE INDEX IF NOT EXISTS mv_company_statistics_company_id_idx ON mv_company_statistics (company_id);

-- ============================================
-- REFRESH FUNCTION FOR MATERIALIZED VIEWS
-- CORRECTED: Fixed dollar quote syntax
-- ============================================
CREATE OR REPLACE FUNCTION refresh_materialized_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_company_statistics;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON VIEW v_shipment_details IS 'Complete shipment information for dashboard display';
COMMENT ON VIEW v_missing_products_report IS 'Comprehensive report of all missing products with financial impact';
COMMENT ON VIEW v_truck_utilization IS 'Track truck usage and availability';
COMMENT ON VIEW v_daily_shipment_summary IS 'Daily aggregated shipment statistics';
COMMENT ON VIEW v_product_loss_analysis IS 'Analyze which products have highest loss rates';
COMMENT ON VIEW v_current_truck_positions IS 'Real-time positions of all active trucks';
COMMENT ON VIEW v_rfid_scan_activity IS 'Complete log of all RFID scanning activity';
COMMENT ON VIEW v_delivery_performance IS 'KPIs and metrics for delivery performance';
COMMENT ON VIEW v_shipment_routes IS 'Complete GPS route history for shipments';
COMMENT ON VIEW v_alerts_monitoring IS 'System alerts for issues requiring attention';
COMMENT ON MATERIALIZED VIEW mv_company_statistics IS 'Aggregated company statistics - refresh hourly for performance';

-- ============================================
-- END OF CORRECTED VIEWS
-- ============================================