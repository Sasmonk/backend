-- ============================================
-- DATABASE MAINTENANCE & OPTIMIZATION
-- CORRECTED VERSION - All dollar quote syntax fixed
-- ============================================

-- ============================================
-- 1. SCHEDULED MAINTENANCE PROCEDURES
-- ============================================

-- Procedure to run daily maintenance tasks
CREATE OR REPLACE FUNCTION daily_maintenance()
RETURNS JSON AS $$
DECLARE
    v_gps_archived INTEGER;
    v_stats_refreshed BOOLEAN := false;
    v_result JSON;
BEGIN
    -- Archive old GPS data (older than 2 days)
    SELECT (archive_old_gps_data(2)->>'archived_count')::INTEGER INTO v_gps_archived;
    
    -- Refresh materialized views
    PERFORM refresh_materialized_views();
    v_stats_refreshed := true;
    
    -- Vacuum analyze for performance
    VACUUM ANALYZE gps_tracking;
    VACUUM ANALYZE shipment_items;
    VACUUM ANALYZE rfid_scans;
    
    v_result := json_build_object(
        'success', true,
        'gps_records_archived', v_gps_archived,
        'materialized_views_refreshed', v_stats_refreshed,
        'tables_vacuumed', ARRAY['gps_tracking', 'shipment_items', 'rfid_scans'],
        'executed_at', CURRENT_TIMESTAMP
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 2. DATA CLEANUP PROCEDURES
-- ============================================

-- Delete old audit logs (older than 1 year)
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs(
    p_months_old INTEGER DEFAULT 12
)
RETURNS JSON AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM audit_logs
    WHERE timestamp < CURRENT_TIMESTAMP - (p_months_old || ' months')::INTERVAL;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN json_build_object(
        'success', true,
        'deleted_count', v_deleted_count,
        'cutoff_date', CURRENT_TIMESTAMP - (p_months_old || ' months')::INTERVAL
    );
END;
$$ LANGUAGE plpgsql;

-- Archive completed shipments older than 6 months
CREATE TABLE IF NOT EXISTS shipments_archive (
    LIKE shipments INCLUDING ALL
);

CREATE TABLE IF NOT EXISTS shipment_items_archive (
    LIKE shipment_items INCLUDING ALL
);

CREATE OR REPLACE FUNCTION archive_old_shipments(
    p_months_old INTEGER DEFAULT 6
)
RETURNS JSON AS $$
DECLARE
    v_shipments_archived INTEGER;
    v_items_archived INTEGER;
    v_cutoff_date TIMESTAMP WITH TIME ZONE;
BEGIN
    v_cutoff_date := CURRENT_TIMESTAMP - (p_months_old || ' months')::INTERVAL;
    
    -- Archive shipment items first
    WITH archived_items AS (
        INSERT INTO shipment_items_archive
        SELECT si.* FROM shipment_items si
        JOIN shipments s ON si.shipment_id = s.id
        WHERE s.status IN ('delivered', 'cancelled')
        AND s.delivered_at < v_cutoff_date
        RETURNING id
    )
    DELETE FROM shipment_items
    WHERE id IN (SELECT id FROM archived_items);
    
    GET DIAGNOSTICS v_items_archived = ROW_COUNT;
    
    -- Archive shipments
    WITH archived_shipments AS (
        INSERT INTO shipments_archive
        SELECT * FROM shipments
        WHERE status IN ('delivered', 'cancelled')
        AND delivered_at < v_cutoff_date
        RETURNING id
    )
    DELETE FROM shipments
    WHERE id IN (SELECT id FROM archived_shipments);
    
    GET DIAGNOSTICS v_shipments_archived = ROW_COUNT;
    
    RETURN json_build_object(
        'success', true,
        'shipments_archived', v_shipments_archived,
        'items_archived', v_items_archived,
        'cutoff_date', v_cutoff_date
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 3. PERFORMANCE MONITORING QUERIES
-- ============================================

-- Check table sizes
CREATE OR REPLACE VIEW v_table_sizes AS
SELECT 
    t.schemaname,
    t.tablename,
    pg_size_pretty(pg_total_relation_size((t.schemaname||'.'||t.tablename)::regclass)) AS total_size,
    pg_size_pretty(pg_relation_size((t.schemaname||'.'||t.tablename)::regclass)) AS table_size,
    pg_size_pretty(pg_total_relation_size((t.schemaname||'.'||t.tablename)::regclass) - 
                   pg_relation_size((t.schemaname||'.'||t.tablename)::regclass)) AS indexes_size,
    pg_total_relation_size((t.schemaname||'.'||t.tablename)::regclass) AS size_bytes
FROM pg_tables t
WHERE t.schemaname = 'public'
ORDER BY size_bytes DESC;

-- Check index usage
CREATE OR REPLACE VIEW v_index_usage AS
SELECT
    s.schemaname,
    s.relname as tablename,
    s.indexrelname as indexname,
    s.idx_scan as index_scans,
    s.idx_tup_read as tuples_read,
    s.idx_tup_fetch as tuples_fetched,
    pg_size_pretty(pg_relation_size(s.indexrelid)) as index_size
FROM pg_stat_user_indexes s
WHERE s.schemaname = 'public'
ORDER BY s.idx_scan ASC, pg_relation_size(s.indexrelid) DESC;

-- Slow query detection (for queries taking > 100ms)
-- Note: Requires pg_stat_statements extension
-- Comment out if extension is not installed
/*
CREATE OR REPLACE VIEW v_slow_queries AS
SELECT
    (total_exec_time / calls) as avg_time_ms,
    calls,
    total_exec_time,
    query
FROM pg_stat_statements
WHERE calls > 10
AND (total_exec_time / calls) > 100
ORDER BY avg_time_ms DESC
LIMIT 20;
*/

-- ============================================
-- 4. DATA INTEGRITY CHECKS
-- CORRECTED: Fixed dollar quote syntax
-- ============================================

-- Check for orphaned records
CREATE OR REPLACE FUNCTION check_data_integrity()
RETURNS TABLE(
    check_name TEXT,
    issue_count INTEGER,
    severity TEXT,
    description TEXT
) AS $$
BEGIN
    -- Check for shipment items without shipments
    RETURN QUERY
    SELECT 
        'Orphaned Shipment Items'::TEXT,
        COUNT(*)::INTEGER,
        'High'::TEXT,
        'Shipment items exist without corresponding shipment'::TEXT
    FROM shipment_items si
    WHERE NOT EXISTS (SELECT 1 FROM shipments WHERE id = si.shipment_id);
    
    -- Check for GPS tracking without shipments
    RETURN QUERY
    SELECT 
        'Orphaned GPS Records'::TEXT,
        COUNT(*)::INTEGER,
        'Medium'::TEXT,
        'GPS tracking records exist without corresponding shipment'::TEXT
    FROM gps_tracking gt
    WHERE NOT EXISTS (SELECT 1 FROM shipments WHERE id = gt.shipment_id);
    
    -- Check for RFID scans without shipments
    RETURN QUERY
    SELECT 
        'Orphaned RFID Scans'::TEXT,
        COUNT(*)::INTEGER,
        'Medium'::TEXT,
        'RFID scans exist without corresponding shipment'::TEXT
    FROM rfid_scans rs
    WHERE NOT EXISTS (SELECT 1 FROM shipments WHERE id = rs.shipment_id);
    
    -- Check for shipments without items
    RETURN QUERY
    SELECT 
        'Shipments Without Items'::TEXT,
        COUNT(*)::INTEGER,
        'High'::TEXT,
        'Active shipments exist without any items'::TEXT
    FROM shipments s
    WHERE s.status IN ('pending', 'in_transit')
    AND NOT EXISTS (SELECT 1 FROM shipment_items WHERE shipment_id = s.id);
    
    -- Check for stale shipments (in transit > 7 days)
    RETURN QUERY
    SELECT 
        'Stale In-Transit Shipments'::TEXT,
        COUNT(*)::INTEGER,
        'High'::TEXT,
        'Shipments have been in transit for more than 7 days'::TEXT
    FROM shipments
    WHERE status = 'in_transit'
    AND started_at < CURRENT_TIMESTAMP - INTERVAL '7 days';
    
    -- Check for missing delivery verification
    RETURN QUERY
    SELECT 
        'Missing Delivery Verification'::TEXT,
        COUNT(*)::INTEGER,
        'Medium'::TEXT,
        'Delivered shipments without verification records'::TEXT
    FROM shipments s
    WHERE s.status IN ('delivered', 'partially_delivered')
    AND NOT EXISTS (SELECT 1 FROM delivery_verification WHERE shipment_id = s.id);
    
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. BACKUP VERIFICATION
-- CORRECTED: Fixed dollar quote syntax
-- ============================================

-- Get database backup statistics
CREATE OR REPLACE FUNCTION get_backup_info()
RETURNS JSON AS $$
DECLARE
    v_db_size TEXT;
    v_total_tables INTEGER;
    v_total_rows BIGINT := 0;
    v_result JSON;
BEGIN
    -- Get database size
    SELECT pg_size_pretty(pg_database_size(current_database())) INTO v_db_size;
    
    -- Count tables
    SELECT COUNT(*) INTO v_total_tables
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_type = 'BASE TABLE';
    
    -- Estimate total rows (approximate)
    SELECT SUM(n_live_tup) INTO v_total_rows
    FROM pg_stat_user_tables;
    
    v_result := json_build_object(
        'database_name', current_database(),
        'database_size', v_db_size,
        'total_tables', v_total_tables,
        'estimated_total_rows', v_total_rows,
        'critical_tables', json_build_object(
            'shipments', (SELECT COUNT(*) FROM shipments),
            'shipment_items', (SELECT COUNT(*) FROM shipment_items),
            'gps_tracking', (SELECT COUNT(*) FROM gps_tracking),
            'products', (SELECT COUNT(*) FROM products),
            'trucks', (SELECT COUNT(*) FROM trucks),
            'companies', (SELECT COUNT(*) FROM companies)
        ),
        'checked_at', CURRENT_TIMESTAMP
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. PERFORMANCE OPTIMIZATION INDEXES
-- (Additional indexes based on common query patterns)
-- ============================================

-- Composite index for active shipments dashboard
CREATE INDEX IF NOT EXISTS idx_shipments_company_status_created 
ON shipments(company_id, status, created_at DESC);

-- Composite index for GPS tracking by shipment and time
CREATE INDEX IF NOT EXISTS idx_gps_shipment_time 
ON gps_tracking(shipment_id, timestamp DESC);

-- Index for RFID scan lookups
CREATE INDEX IF NOT EXISTS idx_rfid_scans_tag_shipment 
ON rfid_scans(rfid_tag, shipment_id);

-- Index for missing products by company
CREATE INDEX IF NOT EXISTS idx_missing_products_company 
ON missing_products_log(shipment_id) 
INCLUDE (product_id, missing_quantity, estimated_loss_value);

-- Partial index for active shipments only
CREATE INDEX IF NOT EXISTS idx_active_shipments 
ON shipments(company_id, truck_id) 
WHERE status IN ('pending', 'in_transit');

-- Index for delivery verification lookups
CREATE INDEX IF NOT EXISTS idx_delivery_verification_status 
ON delivery_verification(verification_status, verified_at DESC);

-- ============================================
-- 7. QUERY PERFORMANCE HELPERS
-- CORRECTED: Fixed dollar quote syntax
-- ============================================

-- Function to explain query performance
CREATE OR REPLACE FUNCTION explain_query(p_query TEXT)
RETURNS TABLE(query_plan TEXT) AS $$
BEGIN
    RETURN QUERY EXECUTE 'EXPLAIN ANALYZE ' || p_query;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 8. DATABASE STATISTICS & HEALTH CHECK
-- CORRECTED: Fixed dollar quote syntax
-- ============================================

CREATE OR REPLACE FUNCTION database_health_check()
RETURNS JSON AS $$
DECLARE
    v_result JSON;
    v_connection_count INTEGER;
    v_table_bloat TEXT;
    v_cache_hit_ratio NUMERIC;
BEGIN
    -- Check active connections
    SELECT COUNT(*) INTO v_connection_count
    FROM pg_stat_activity
    WHERE state = 'active';
    
    -- Calculate cache hit ratio
    SELECT 
        ROUND(
            100.0 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 
            2
        )
    INTO v_cache_hit_ratio
    FROM pg_stat_database;
    
    v_result := json_build_object(
        'status', 'healthy',
        'active_connections', v_connection_count,
        'cache_hit_ratio_percent', v_cache_hit_ratio,
        'database_size', (SELECT pg_size_pretty(pg_database_size(current_database()))),
        'table_stats', json_build_object(
            'total_shipments', (SELECT COUNT(*) FROM shipments),
            'active_shipments', (SELECT COUNT(*) FROM shipments WHERE status IN ('pending', 'in_transit')),
            'gps_points_today', (SELECT COUNT(*) FROM gps_tracking WHERE DATE(timestamp) = CURRENT_DATE),
            'rfid_scans_today', (SELECT COUNT(*) FROM rfid_scans WHERE DATE(scan_timestamp) = CURRENT_DATE)
        ),
        'recommendations', CASE
            WHEN v_cache_hit_ratio < 90 THEN ARRAY['Consider increasing shared_buffers']
            WHEN v_connection_count > 50 THEN ARRAY['High connection count - consider connection pooling']
            ELSE ARRAY['System performing well']
        END,
        'checked_at', CURRENT_TIMESTAMP
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 9. AUTOMATED ALERTS & NOTIFICATIONS
-- CORRECTED: Fixed dollar quote syntax
-- ============================================

-- Function to check critical alerts
CREATE OR REPLACE FUNCTION check_critical_alerts()
RETURNS TABLE(
    alert_id UUID,
    alert_type TEXT,
    severity TEXT,
    message TEXT,
    affected_entity_id UUID,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    -- GPS offline alerts
    RETURN QUERY
    SELECT 
        uuid_generate_v4(),
        'GPS_OFFLINE'::TEXT,
        'CRITICAL'::TEXT,
        ('Truck ' || t.user_assigned_name || ' - No GPS signal for ' || 
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - gt.last_gps))::INTEGER || ' seconds')::TEXT,
        s.id,
        CURRENT_TIMESTAMP
    FROM shipments s
    JOIN trucks t ON s.truck_id = t.id
    LEFT JOIN LATERAL (
        SELECT MAX(timestamp) as last_gps
        FROM gps_tracking
        WHERE shipment_id = s.id
    ) gt ON true
    WHERE s.status IN ('pending', 'in_transit')
    AND (CURRENT_TIMESTAMP - gt.last_gps) > INTERVAL '1 hour';
    
    -- Overdue deliveries
    RETURN QUERY
    SELECT 
        uuid_generate_v4(),
        'OVERDUE_DELIVERY'::TEXT,
        'HIGH'::TEXT,
        ('Shipment ' || s.shipment_number || ' is ' || 
        EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - s.estimated_arrival))/3600 || ' hours overdue')::TEXT,
        s.id,
        CURRENT_TIMESTAMP
    FROM shipments s
    WHERE s.status = 'in_transit'
    AND s.estimated_arrival < CURRENT_TIMESTAMP - INTERVAL '2 hours';
    
    -- High value missing products
    RETURN QUERY
    SELECT 
        uuid_generate_v4(),
        'HIGH_VALUE_LOSS'::TEXT,
        'CRITICAL'::TEXT,
        ('Missing products worth ₹' || mpl.estimated_loss_value || ' in shipment ' || s.shipment_number)::TEXT,
        mpl.shipment_id,
        mpl.reported_at
    FROM missing_products_log mpl
    JOIN shipments s ON mpl.shipment_id = s.id
    WHERE mpl.resolution_status = 'open'
    AND mpl.estimated_loss_value > 10000
    AND mpl.reported_at > CURRENT_TIMESTAMP - INTERVAL '24 hours';
    
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 10. DATABASE MIGRATION HELPERS
-- CORRECTED: Fixed dollar quote syntax
-- ============================================

-- Function to safely add column if not exists
CREATE OR REPLACE FUNCTION add_column_if_not_exists(
    p_table_name TEXT,
    p_column_name TEXT,
    p_column_type TEXT,
    p_default_value TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_column_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = p_table_name
        AND column_name = p_column_name
    ) INTO v_column_exists;
    
    IF NOT v_column_exists THEN
        EXECUTE format(
            'ALTER TABLE %I ADD COLUMN %I %s %s',
            p_table_name,
            p_column_name,
            p_column_type,
            COALESCE('DEFAULT ' || p_default_value, '')
        );
        RETURN true;
    END IF;
    
    RETURN false;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 11. REPORTING HELPERS
-- CORRECTED: Fixed dollar quote syntax
-- ============================================

-- Generate monthly report for a company
CREATE OR REPLACE FUNCTION generate_monthly_report(
    p_company_id UUID,
    p_month DATE DEFAULT DATE_TRUNC('month', CURRENT_DATE)
)
RETURNS JSON AS $$
DECLARE
    v_result JSON;
BEGIN
    SELECT json_build_object(
        'company_id', p_company_id,
        'company_name', c.company_name,
        'report_period', TO_CHAR(p_month, 'Month YYYY'),
        'shipments', json_build_object(
            'total', COUNT(s.id),
            'delivered', COUNT(*) FILTER (WHERE s.status = 'delivered'),
            'in_transit', COUNT(*) FILTER (WHERE s.status = 'in_transit'),
            'pending', COUNT(*) FILTER (WHERE s.status = 'pending'),
            'on_time_delivery_rate', 
                ROUND(
                    COUNT(*) FILTER (WHERE s.delivered_at <= s.estimated_arrival)::NUMERIC / 
                    NULLIF(COUNT(*) FILTER (WHERE s.status = 'delivered'), 0) * 100, 
                    2
                )
        ),
        'financials', json_build_object(
            'total_shipment_value', COALESCE(SUM(s.total_value), 0),
            'total_loss_value', COALESCE(
                (SELECT SUM(estimated_loss_value) 
                 FROM missing_products_log mpl 
                 JOIN shipments s2 ON mpl.shipment_id = s2.id
                 WHERE s2.company_id = p_company_id
                 AND DATE_TRUNC('month', mpl.reported_at) = p_month),
                0
            ),
            'loss_percentage', ROUND(
                COALESCE(
                    (SELECT SUM(estimated_loss_value) 
                     FROM missing_products_log mpl 
                     JOIN shipments s2 ON mpl.shipment_id = s2.id
                     WHERE s2.company_id = p_company_id
                     AND DATE_TRUNC('month', mpl.reported_at) = p_month),
                    0
                )::NUMERIC / NULLIF(SUM(s.total_value), 0) * 100,
                2
            )
        ),
        'products', json_build_object(
            'total_products_shipped', 
                (SELECT COUNT(DISTINCT product_id) 
                 FROM shipment_items si 
                 JOIN shipments s2 ON si.shipment_id = s2.id
                 WHERE s2.company_id = p_company_id
                 AND DATE_TRUNC('month', s2.created_at) = p_month),
            'total_quantity_shipped',
                (SELECT COALESCE(SUM(quantity), 0)
                 FROM shipment_items si 
                 JOIN shipments s2 ON si.shipment_id = s2.id
                 WHERE s2.company_id = p_company_id
                 AND DATE_TRUNC('month', s2.created_at) = p_month)
        ),
        'trucks_utilized', 
            (SELECT COUNT(DISTINCT truck_id)
             FROM shipments
             WHERE company_id = p_company_id
             AND DATE_TRUNC('month', created_at) = p_month),
        'generated_at', CURRENT_TIMESTAMP
    ) INTO v_result
    FROM companies c
    LEFT JOIN shipments s ON c.id = s.company_id 
        AND DATE_TRUNC('month', s.created_at) = p_month
    WHERE c.id = p_company_id
    GROUP BY c.id, c.company_name;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 12. QUICK COMPANY STATS
-- CORRECTED: Fixed dollar quote syntax
-- ============================================

-- Quick company overview
CREATE OR REPLACE FUNCTION company_quick_stats(p_company_id UUID)
RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_build_object(
            'active_shipments', (
                SELECT COUNT(*) FROM shipments 
                WHERE company_id = p_company_id 
                AND status IN ('pending', 'in_transit')
            ),
            'trucks_in_use', (
                SELECT COUNT(DISTINCT truck_id) FROM shipments 
                WHERE company_id = p_company_id 
                AND status = 'in_transit'
            ),
            'deliveries_today', (
                SELECT COUNT(*) FROM shipments 
                WHERE company_id = p_company_id 
                AND DATE(delivered_at) = CURRENT_DATE
            ),
            'pending_issues', (
                SELECT COUNT(*) FROM missing_products_log mpl
                JOIN shipments s ON mpl.shipment_id = s.id
                WHERE s.company_id = p_company_id
                AND mpl.resolution_status = 'open'
            )
        )
    );
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- COMMENTS & DOCUMENTATION
-- ============================================

COMMENT ON FUNCTION daily_maintenance IS 
'Run this function daily to archive old GPS data, refresh stats, and optimize tables';

COMMENT ON FUNCTION check_data_integrity IS 
'Checks for orphaned records and data inconsistencies';

COMMENT ON FUNCTION database_health_check IS 
'Comprehensive health check of database performance and statistics';

COMMENT ON FUNCTION generate_monthly_report IS 
'Generates detailed monthly performance report for a company';

COMMENT ON VIEW v_table_sizes IS 
'Shows size of all tables including indexes for monitoring database growth';

COMMENT ON VIEW v_index_usage IS 
'Monitors index usage to identify unused indexes that can be dropped';

-- ============================================
-- END OF CORRECTED MAINTENANCE SCRIPTS
-- ============================================