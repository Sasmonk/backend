-- ============================================
-- LOGISTICS TRACKING SYSTEM - DATABASE SCHEMA
-- For Supabase PostgreSQL
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- 1. USERS TABLE
-- Stores individual users who can own multiple companies
-- ============================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 2. COMPANIES TABLE
-- Multiple companies per user with data isolation
-- ============================================
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    company_name VARCHAR(255) NOT NULL,
    company_code VARCHAR(50) UNIQUE NOT NULL, -- For easy identification
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_companies_owner ON companies(owner_id);

-- ============================================
-- 3. TRUCKS TABLE
-- Trucks that can be shared between companies
-- ============================================
CREATE TABLE trucks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    registration_number VARCHAR(50) UNIQUE NOT NULL,
    user_assigned_name VARCHAR(255), -- Custom name given by user
    truck_type VARCHAR(100), -- e.g., Container, Flatbed, Refrigerated
    capacity_kg DECIMAL(10, 2),
    driver_name VARCHAR(255),
    driver_phone VARCHAR(20),
    driver_license VARCHAR(100),
    esp_device_id VARCHAR(100) UNIQUE, -- ESP32 device identifier
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_trucks_esp_device ON trucks(esp_device_id);
CREATE INDEX idx_trucks_registration ON trucks(registration_number);

-- ============================================
-- 4. COMPANY_TRUCKS (Join Table)
-- Associates trucks with companies (many-to-many)
-- ============================================
CREATE TABLE company_trucks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    truck_id UUID NOT NULL REFERENCES trucks(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(company_id, truck_id)
);

CREATE INDEX idx_company_trucks_company ON company_trucks(company_id);
CREATE INDEX idx_company_trucks_truck ON company_trucks(truck_id);

-- ============================================
-- 5. PRODUCT_CATEGORIES TABLE
-- Product categories for organization
-- ============================================
CREATE TABLE product_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Insert default categories
INSERT INTO product_categories (category_name, description) VALUES
    ('Electronics', 'Electronic devices and components'),
    ('Perishables', 'Food items and perishable goods'),
    ('Raw Materials', 'Industrial raw materials'),
    ('Finished Goods', 'Manufactured finished products'),
    ('Chemicals', 'Chemical products'),
    ('Textiles', 'Clothing and fabric materials'),
    ('Other', 'Miscellaneous products');

-- ============================================
-- 6. PRODUCTS TABLE
-- Master product catalog for each company
-- ============================================
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    product_name VARCHAR(255) NOT NULL,
    category_id UUID REFERENCES product_categories(id),
    sku VARCHAR(100), -- Stock Keeping Unit (optional)
    description TEXT,
    unit_value DECIMAL(12, 2), -- Value per unit
    tracking_mode VARCHAR(20) DEFAULT 'batch' CHECK (tracking_mode IN ('individual', 'batch')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_products_company ON products(company_id);
CREATE INDEX idx_products_category ON products(category_id);

-- ============================================
-- 7. RFID_DESTINATIONS TABLE
-- RFID scanning locations/destinations
-- ============================================
CREATE TABLE rfid_destinations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    location_name VARCHAR(255) NOT NULL,
    address TEXT,
    esp_device_id VARCHAR(100) UNIQUE, -- ESP32 device identifier at destination
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_rfid_destinations_company ON rfid_destinations(company_id);
CREATE INDEX idx_rfid_destinations_esp ON rfid_destinations(esp_device_id);

-- ============================================
-- 8. SHIPMENTS TABLE
-- Main shipment/transport sessions
-- ============================================
CREATE TABLE shipments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    truck_id UUID NOT NULL REFERENCES trucks(id),
    destination_id UUID NOT NULL REFERENCES rfid_destinations(id),
    
    shipment_number VARCHAR(100) UNIQUE NOT NULL, -- Auto-generated or user-provided
    
    origin_location VARCHAR(255),
    origin_latitude DECIMAL(10, 8),
    origin_longitude DECIMAL(11, 8),
    
    destination_location VARCHAR(255),
    destination_latitude DECIMAL(10, 8),
    destination_longitude DECIMAL(11, 8),
    
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'in_transit', 'delivered', 'partially_delivered', 'cancelled')),
    
    started_at TIMESTAMP WITH TIME ZONE,
    estimated_arrival TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    
    total_value DECIMAL(15, 2), -- Total shipment value
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_shipments_company ON shipments(company_id);
CREATE INDEX idx_shipments_truck ON shipments(truck_id);
CREATE INDEX idx_shipments_status ON shipments(status);
CREATE INDEX idx_shipments_destination ON shipments(destination_id);

-- ============================================
-- 9. SHIPMENT_ITEMS TABLE
-- Products included in each shipment
-- ============================================
CREATE TABLE shipment_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_id UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id),
    
    quantity DECIMAL(10, 2) NOT NULL, -- Can be decimal for weight-based items
    unit VARCHAR(20) DEFAULT 'pieces', -- pieces, kg, liters, etc.
    
    unit_value DECIMAL(12, 2), -- Value per unit at time of shipment
    total_value DECIMAL(15, 2), -- quantity * unit_value
    
    rfid_tag VARCHAR(255), -- RFID tag if tracking individually/batch
    
    quantity_received DECIMAL(10, 2) DEFAULT 0,
    quantity_missing DECIMAL(10, 2) DEFAULT 0,
    
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'in_transit', 'delivered', 'partially_delivered', 'missing')),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_shipment_items_shipment ON shipment_items(shipment_id);
CREATE INDEX idx_shipment_items_product ON shipment_items(product_id);
CREATE INDEX idx_shipment_items_rfid ON shipment_items(rfid_tag);

-- ============================================
-- 10. GPS_TRACKING TABLE
-- Real-time GPS coordinates from truck
-- Stores last 24 hours, older data can be archived
-- ============================================
CREATE TABLE gps_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_id UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
    truck_id UUID NOT NULL REFERENCES trucks(id),
    
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    altitude DECIMAL(8, 2), -- Optional
    speed DECIMAL(6, 2), -- km/h
    heading DECIMAL(5, 2), -- Degrees (0-360)
    
    accuracy DECIMAL(6, 2), -- GPS accuracy in meters
    
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- For ESP32 tracking
    esp_device_id VARCHAR(100),
    battery_level INTEGER, -- Battery percentage if applicable
    signal_strength INTEGER -- GSM signal strength
);

CREATE INDEX idx_gps_tracking_shipment ON gps_tracking(shipment_id);
CREATE INDEX idx_gps_tracking_truck ON gps_tracking(truck_id);
CREATE INDEX idx_gps_tracking_timestamp ON gps_tracking(timestamp DESC);
CREATE INDEX idx_gps_tracking_esp ON gps_tracking(esp_device_id);

-- ============================================
-- 11. RFID_SCANS TABLE
-- Records each RFID scan at destination
-- ============================================
CREATE TABLE rfid_scans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_id UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
    destination_id UUID NOT NULL REFERENCES rfid_destinations(id),
    shipment_item_id UUID REFERENCES shipment_items(id),
    
    rfid_tag VARCHAR(255) NOT NULL,
    
    scan_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    esp_device_id VARCHAR(100), -- ESP32 device at destination
    
    is_expected BOOLEAN DEFAULT false, -- Was this item expected in shipment?
    is_matched BOOLEAN DEFAULT false -- Did it match a shipment item?
);

CREATE INDEX idx_rfid_scans_shipment ON rfid_scans(shipment_id);
CREATE INDEX idx_rfid_scans_destination ON rfid_scans(destination_id);
CREATE INDEX idx_rfid_scans_rfid_tag ON rfid_scans(rfid_tag);
CREATE INDEX idx_rfid_scans_timestamp ON rfid_scans(scan_timestamp DESC);

-- ============================================
-- 12. DELIVERY_VERIFICATION TABLE
-- Final delivery report with discrepancies
-- ============================================
CREATE TABLE delivery_verification (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_id UUID UNIQUE NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
    destination_id UUID NOT NULL REFERENCES rfid_destinations(id),
    
    total_items_expected INTEGER NOT NULL,
    total_items_received INTEGER NOT NULL,
    total_items_missing INTEGER NOT NULL,
    
    verification_status VARCHAR(50) DEFAULT 'pending' CHECK (verification_status IN ('pending', 'complete', 'discrepancy')),
    
    verified_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    verified_by VARCHAR(255), -- Person/system who verified
    
    notes TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_delivery_verification_shipment ON delivery_verification(shipment_id);

-- ============================================
-- 13. MISSING_PRODUCTS_LOG TABLE
-- Detailed log of missing/discrepant items
-- ============================================
CREATE TABLE missing_products_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_id UUID NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
    shipment_item_id UUID NOT NULL REFERENCES shipment_items(id),
    product_id UUID NOT NULL REFERENCES products(id),
    
    expected_quantity DECIMAL(10, 2) NOT NULL,
    received_quantity DECIMAL(10, 2) NOT NULL,
    missing_quantity DECIMAL(10, 2) NOT NULL,
    
    rfid_tag VARCHAR(255),
    
    discrepancy_type VARCHAR(50) CHECK (discrepancy_type IN ('missing', 'partial', 'damaged', 'other')),
    
    estimated_loss_value DECIMAL(15, 2),
    
    reported_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    resolution_status VARCHAR(50) DEFAULT 'open' CHECK (resolution_status IN ('open', 'investigating', 'resolved', 'closed')),
    resolution_notes TEXT
);

CREATE INDEX idx_missing_products_shipment ON missing_products_log(shipment_id);
CREATE INDEX idx_missing_products_item ON missing_products_log(shipment_item_id);

-- ============================================
-- 14. AUDIT_LOGS TABLE
-- Privacy and compliance audit trail
-- ============================================
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    company_id UUID REFERENCES companies(id),
    
    action VARCHAR(100) NOT NULL, -- e.g., 'CREATE_SHIPMENT', 'UPDATE_TRUCK', 'DELETE_PRODUCT'
    table_name VARCHAR(100),
    record_id UUID,
    
    old_values JSONB,
    new_values JSONB,
    
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_company ON audit_logs(company_id);
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp DESC);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_companies_updated_at BEFORE UPDATE ON companies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_trucks_updated_at BEFORE UPDATE ON trucks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rfid_destinations_updated_at BEFORE UPDATE ON rfid_destinations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shipments_updated_at BEFORE UPDATE ON shipments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_shipment_items_updated_at BEFORE UPDATE ON shipment_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to generate shipment number
CREATE OR REPLACE FUNCTION generate_shipment_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.shipment_number IS NULL THEN
        NEW.shipment_number := 'SHP-' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDD') || '-' || LPAD(nextval('shipment_number_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE shipment_number_seq START 1;

CREATE TRIGGER set_shipment_number BEFORE INSERT ON shipments
    FOR EACH ROW EXECUTE FUNCTION generate_shipment_number();

-- Function to calculate total_value in shipment_items
CREATE OR REPLACE FUNCTION calculate_shipment_item_total()
RETURNS TRIGGER AS $$
BEGIN
    NEW.total_value := NEW.quantity * NEW.unit_value;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_shipment_item_total_trigger BEFORE INSERT OR UPDATE ON shipment_items
    FOR EACH ROW EXECUTE FUNCTION calculate_shipment_item_total();

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- For privacy and data isolation between companies
-- ============================================

-- Enable RLS on all tables
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE trucks ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_trucks ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfid_destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipment_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE gps_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE rfid_scans ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_verification ENABLE ROW LEVEL SECURITY;
ALTER TABLE missing_products_log ENABLE ROW LEVEL SECURITY;

-- Companies: Users can only see their own companies
CREATE POLICY companies_isolation_policy ON companies
    FOR ALL
    USING (owner_id = auth.uid());

-- Products: Users can only see products from their companies
CREATE POLICY products_isolation_policy ON products
    FOR ALL
    USING (
        company_id IN (
            SELECT id FROM companies WHERE owner_id = auth.uid()
        )
    );

-- Shipments: Users can only see shipments from their companies
CREATE POLICY shipments_isolation_policy ON shipments
    FOR ALL
    USING (
        company_id IN (
            SELECT id FROM companies WHERE owner_id = auth.uid()
        )
    );

-- Similar policies can be created for other tables...

-- ============================================
-- VIEWS FOR COMMON QUERIES
-- ============================================

-- Active shipments with current location
CREATE VIEW active_shipments_with_location AS
SELECT 
    s.id,
    s.shipment_number,
    s.company_id,
    c.company_name,
    s.truck_id,
    t.registration_number,
    t.user_assigned_name as truck_name,
    s.status,
    s.origin_location,
    s.destination_location,
    s.started_at,
    s.estimated_arrival,
    gt.latitude as current_latitude,
    gt.longitude as current_longitude,
    gt.speed as current_speed,
    gt.timestamp as last_updated
FROM shipments s
JOIN companies c ON s.company_id = c.id
JOIN trucks t ON s.truck_id = t.id
LEFT JOIN LATERAL (
    SELECT latitude, longitude, speed, timestamp
    FROM gps_tracking
    WHERE shipment_id = s.id
    ORDER BY timestamp DESC
    LIMIT 1
) gt ON true
WHERE s.status IN ('pending', 'in_transit');

-- Shipment summary with item counts
CREATE VIEW shipment_summary AS
SELECT 
    s.id,
    s.shipment_number,
    s.company_id,
    s.status,
    COUNT(si.id) as total_items,
    SUM(si.quantity) as total_quantity,
    SUM(si.total_value) as total_value,
    SUM(si.quantity_received) as total_received,
    SUM(si.quantity_missing) as total_missing
FROM shipments s
LEFT JOIN shipment_items si ON s.id = si.shipment_id
GROUP BY s.id, s.shipment_number, s.company_id, s.status;

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

-- Additional composite indexes for common queries
CREATE INDEX idx_gps_tracking_shipment_timestamp ON gps_tracking(shipment_id, timestamp DESC);
CREATE INDEX idx_shipment_items_shipment_status ON shipment_items(shipment_id, status);

-- ============================================
-- COMMENTS FOR DOCUMENTATION
-- ============================================

COMMENT ON TABLE shipments IS 'Main table for tracking shipments/transports. Each shipment represents one transport session from origin to destination.';
COMMENT ON TABLE gps_tracking IS 'Stores GPS coordinates sent by ESP32/GSM module in truck. Consider archiving data older than 24-48 hours for performance.';
COMMENT ON TABLE rfid_scans IS 'Records each RFID scan at destination. Used to verify received products against shipment manifest.';
COMMENT ON TABLE missing_products_log IS 'Detailed log of discrepancies found during delivery verification. Critical for loss tracking and claims.';

-- ============================================
-- END OF SCHEMA
-- ============================================