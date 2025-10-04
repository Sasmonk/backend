-- ============================================
-- SEED DATA FOR TESTING
-- Sample data to test the logistics tracking system
-- ============================================

-- Note: Run this AFTER the main schema and stored procedures

-- ============================================
-- 1. SAMPLE USERS
-- ============================================
INSERT INTO users (id, email, full_name, phone) VALUES
    ('a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'rajesh.kumar@example.com', 'Rajesh Kumar', '+91-9876543210'),
    ('b2c3d4e5-f6a7-5b6c-9d0e-1f2a3b4c5d6e', 'priya.sharma@example.com', 'Priya Sharma', '+91-9876543211'),
    ('c3d4e5f6-a7b8-6c7d-0e1f-2a3b4c5d6e7f', 'amit.patel@example.com', 'Amit Patel', '+91-9876543212');

-- ============================================
-- 2. SAMPLE COMPANIES
-- ============================================
INSERT INTO companies (id, owner_id, company_name, company_code, address, phone, email) VALUES
    -- Rajesh owns 2 companies
    ('d4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 
     'Kumar Electronics Ltd', 'KEL001', 
     'Plot No. 45, Industrial Area, Hyderabad, Telangana 500032', 
     '+91-40-12345678', 'info@kumarelectronics.com'),
    
    ('e5f6a7b8-c9d0-8e9f-2a3b-4c5d6e7f8a9b', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 
     'Kumar Textiles Pvt Ltd', 'KTX002', 
     'Lane 7, Textile Park, Secunderabad, Telangana 500003', 
     '+91-40-23456789', 'contact@kumartextiles.com'),
    
    -- Priya owns 1 company
    ('f6a7b8c9-d0e1-9f0a-3b4c-5d6e7f8a9b0c', 'b2c3d4e5-f6a7-5b6c-9d0e-1f2a3b4c5d6e', 
     'Sharma Logistics Solutions', 'SLS003', 
     'Building 12, Logistics Hub, Pune, Maharashtra 411001', 
     '+91-20-34567890', 'operations@sharmalogistics.com'),
    
    -- Amit owns 1 company
    ('a7b8c9d0-e1f2-0a1b-4c5d-6e7f8a9b0c1d', 'c3d4e5f6-a7b8-6c7d-0e1f-2a3b4c5d6e7f', 
     'Patel Pharmaceuticals', 'PPH004', 
     'Zone 3, Pharma City, Ahmedabad, Gujarat 380001', 
     '+91-79-45678901', 'admin@patelpharma.com');

-- ============================================
-- 3. SAMPLE TRUCKS
-- ============================================
INSERT INTO trucks (id, registration_number, user_assigned_name, truck_type, capacity_kg, 
                   driver_name, driver_phone, driver_license, esp_device_id) VALUES
    ('b8c9d0e1-f2a3-1b2c-5d6e-7f8a9b0c1d2e', 'TS09AB1234', 'Express Truck 1', 'Container', 5000.00,
     'Ravi Kumar', '+91-9876501234', 'DL1234567890', 'ESP32-TRUCK-001'),
    
    ('c9d0e1f2-a3b4-2c3d-6e7f-8a9b0c1d2e3f', 'MH12CD5678', 'Speed Carrier', 'Flatbed', 8000.00,
     'Suresh Reddy', '+91-9876502345', 'DL2345678901', 'ESP32-TRUCK-002'),
    
    ('d0e1f2a3-b4c5-3d4e-7f8a-9b0c1d2e3f4a', 'GJ01EF9012', 'Pharma Express', 'Refrigerated', 3000.00,
     'Vijay Singh', '+91-9876503456', 'DL3456789012', 'ESP32-TRUCK-003'),
    
    ('e1f2a3b4-c5d6-4e5f-8a9b-0c1d2e3f4a5b', 'TS10GH3456', 'Textile Hauler', 'Container', 6000.00,
     'Mohan Rao', '+91-9876504567', 'DL4567890123', 'ESP32-TRUCK-004'),
    
    ('f2a3b4c5-d6e7-5f6a-9b0c-1d2e3f4a5b6c', 'MH14IJ7890', 'City Runner', 'Box Truck', 2500.00,
     'Rahul Sharma', '+91-9876505678', 'DL5678901234', 'ESP32-TRUCK-005');

-- ============================================
-- 4. ASSOCIATE TRUCKS WITH COMPANIES
-- Some trucks are shared between companies
-- ============================================
INSERT INTO company_trucks (company_id, truck_id) VALUES
    -- Kumar Electronics uses 3 trucks
    ('d4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a', 'b8c9d0e1-f2a3-1b2c-5d6e-7f8a9b0c1d2e'),
    ('d4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a', 'c9d0e1f2-a3b4-2c3d-6e7f-8a9b0c1d2e3f'),
    ('d4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a', 'f2a3b4c5-d6e7-5f6a-9b0c-1d2e3f4a5b6c'),
    
    -- Kumar Textiles uses 2 trucks (one shared with Electronics)
    ('e5f6a7b8-c9d0-8e9f-2a3b-4c5d6e7f8a9b', 'e1f2a3b4-c5d6-4e5f-8a9b-0c1d2e3f4a5b'),
    ('e5f6a7b8-c9d0-8e9f-2a3b-4c5d6e7f8a9b', 'f2a3b4c5-d6e7-5f6a-9b0c-1d2e3f4a5b6c'), -- Shared
    
    -- Sharma Logistics uses 2 trucks
    ('f6a7b8c9-d0e1-9f0a-3b4c-5d6e7f8a9b0c', 'c9d0e1f2-a3b4-2c3d-6e7f-8a9b0c1d2e3f'), -- Shared
    ('f6a7b8c9-d0e1-9f0a-3b4c-5d6e7f8a9b0c', 'f2a3b4c5-d6e7-5f6a-9b0c-1d2e3f4a5b6c'), -- Shared
    
    -- Patel Pharmaceuticals uses 1 dedicated truck
    ('a7b8c9d0-e1f2-0a1b-4c5d-6e7f8a9b0c1d', 'd0e1f2a3-b4c5-3d4e-7f8a-9b0c1d2e3f4a');

-- ============================================
-- 5. SAMPLE RFID DESTINATIONS
-- ============================================
INSERT INTO rfid_destinations (id, company_id, location_name, address, esp_device_id, latitude, longitude) VALUES
    -- Kumar Electronics destinations
    ('a3b4c5d6-e7f8-6a7b-0c1d-2e3f4a5b6c7d', 'd4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a',
     'Main Warehouse - Hyderabad', 'Warehouse Complex, JNTU Road, Hyderabad', 
     'ESP32-RFID-001', 17.4485, 78.3908),
    
    ('b4c5d6e7-f8a9-7b8c-1d2e-3f4a5b6c7d8e', 'd4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a',
     'Distribution Center - Bangalore', 'Industrial Estate, Whitefield, Bangalore', 
     'ESP32-RFID-002', 12.9698, 77.7500),
    
    -- Kumar Textiles destinations
    ('c5d6e7f8-a9b0-8c9d-2e3f-4a5b6c7d8e9f', 'e5f6a7b8-c9d0-8e9f-2a3b-4c5d6e7f8a9b',
     'Textile Warehouse - Secunderabad', 'Export Zone, Secunderabad', 
     'ESP32-RFID-003', 17.4399, 78.4983),
    
    -- Sharma Logistics destinations
    ('d6e7f8a9-b0c1-9d0e-3f4a-5b6c7d8e9f0a', 'f6a7b8c9-d0e1-9f0a-3b4c-5d6e7f8a9b0c',
     'Central Hub - Pune', 'Logistics Park, Hinjewadi, Pune', 
     'ESP32-RFID-004', 18.5993, 73.7386),
    
    ('e7f8a9b0-c1d2-0e1f-4a5b-6c7d8e9f0a1b', 'f6a7b8c9-d0e1-9f0a-3b4c-5d6e7f8a9b0c',
     'Mumbai Distribution Point', 'Andheri MIDC, Mumbai', 
     'ESP32-RFID-005', 19.1136, 72.8697),
    
    -- Patel Pharmaceuticals destinations
    ('f8a9b0c1-d2e3-1f2a-5b6c-7d8e9f0a1b2c', 'a7b8c9d0-e1f2-0a1b-4c5d-6e7f8a9b0c1d',
     'Pharma Cold Storage - Ahmedabad', 'Temperature Controlled Facility, Ahmedabad', 
     'ESP32-RFID-006', 23.0225, 72.5714);

-- ============================================
-- 6. SAMPLE PRODUCTS
-- ============================================
INSERT INTO products (id, company_id, product_name, category_id, sku, unit_value, tracking_mode) VALUES
    -- Kumar Electronics products
    ('a9b0c1d2-e3f4-2a3b-6c7d-8e9f0a1b2c3d', 'd4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a',
     'LED TV 55 inch', (SELECT id FROM product_categories WHERE category_name = 'Electronics'),
     'KEL-TV-55-001', 45000.00, 'individual'),
    
    ('b0c1d2e3-f4a5-3b4c-7d8e-9f0a1b2c3d4e', 'd4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a',
     'Washing Machine 7kg', (SELECT id FROM product_categories WHERE category_name = 'Electronics'),
     'KEL-WM-7KG-002', 28000.00, 'individual'),
    
    ('c1d2e3f4-a5b6-4c5d-8e9f-0a1b2c3d4e5f', 'd4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a',
     'Microwave Oven', (SELECT id FROM product_categories WHERE category_name = 'Electronics'),
     'KEL-MW-001', 12000.00, 'batch'),
    
    -- Kumar Textiles products
    ('d2e3f4a5-b6c7-5d6e-9f0a-1b2c3d4e5f6a', 'e5f6a7b8-c9d0-8e9f-2a3b-4c5d6e7f8a9b',
     'Cotton Fabric Roll', (SELECT id FROM product_categories WHERE category_name = 'Textiles'),
     'KTX-CFR-001', 1500.00, 'batch'),
    
    ('e3f4a5b6-c7d8-6e7f-0a1b-2c3d4e5f6a7b', 'e5f6a7b8-c9d0-8e9f-2a3b-4c5d6e7f8a9b',
     'Silk Saree', (SELECT id FROM product_categories WHERE category_name = 'Textiles'),
     'KTX-SS-001', 8500.00, 'individual'),
    
    -- Sharma Logistics (they transport various goods)
    ('f4a5b6c7-d8e9-7f8a-1b2c-3d4e5f6a7b8c', 'f6a7b8c9-d0e1-9f0a-3b4c-5d6e7f8a9b0c',
     'Industrial Equipment Parts', (SELECT id FROM product_categories WHERE category_name = 'Raw Materials'),
     'SLS-IEP-001', 5000.00, 'batch'),
    
    -- Patel Pharmaceuticals products
    ('a5b6c7d8-e9f0-8a9b-2c3d-4e5f6a7b8c9d', 'a7b8c9d0-e1f2-0a1b-4c5d-6e7f8a9b0c1d',
     'Antibiotic Tablets (Box)', (SELECT id FROM product_categories WHERE category_name = 'Chemicals'),
     'PPH-ANT-001', 850.00, 'batch'),
    
    ('b6c7d8e9-f0a1-9b0c-3d4e-5f6a7b8c9d0e', 'a7b8c9d0-e1f2-0a1b-4c5d-6e7f8a9b0c1d',
     'Insulin Vials (Temperature Controlled)', (SELECT id FROM product_categories WHERE category_name = 'Chemicals'),
     'PPH-INS-002', 2500.00, 'individual');

-- ============================================
-- 7. SAMPLE SHIPMENTS
-- ============================================

-- Active Shipment 1: Kumar Electronics - In Transit
INSERT INTO shipments (id, company_id, truck_id, destination_id, shipment_number,
                      origin_location, origin_latitude, origin_longitude,
                      destination_location, destination_latitude, destination_longitude,
                      status, started_at, estimated_arrival, total_value)
VALUES (
    'c7d8e9f0-a1b2-0c1d-4e5f-6a7b8c9d0e1f',
    'd4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a', -- Kumar Electronics
    'b8c9d0e1-f2a3-1b2c-5d6e-7f8a9b0c1d2e', -- Express Truck 1
    'a3b4c5d6-e7f8-6a7b-0c1d-2e3f4a5b6c7d', -- Main Warehouse Hyderabad
    'SHP-20251004-000001',
    'Factory Gate, Uppal, Hyderabad', 17.4065, 78.5550,
    'Main Warehouse, JNTU Road, Hyderabad', 17.4485, 78.3908,
    'in_transit',
    CURRENT_TIMESTAMP - INTERVAL '2 hours',
    CURRENT_TIMESTAMP + INTERVAL '1 hour',
    135000.00
);

-- Active Shipment 2: Patel Pharmaceuticals - In Transit
INSERT INTO shipments (id, company_id, truck_id, destination_id, shipment_number,
                      origin_location, origin_latitude, origin_longitude,
                      destination_location, destination_latitude, destination_longitude,
                      status, started_at, estimated_arrival, total_value)
VALUES (
    'd8e9f0a1-b2c3-1d2e-5f6a-7b8c9d0e1f2a',
    'a7b8c9d0-e1f2-0a1b-4c5d-6e7f8a9b0c1d', -- Patel Pharmaceuticals
    'd0e1f2a3-b4c5-3d4e-7f8a-9b0c1d2e3f4a', -- Pharma Express
    'f8a9b0c1-d2e3-1f2a-5b6c-7d8e9f0a1b2c', -- Pharma Cold Storage
    'SHP-20251004-000002',
    'Manufacturing Unit, Vatva, Ahmedabad', 22.9801, 72.6338,
    'Pharma Cold Storage, Ahmedabad', 23.0225, 72.5714,
    'in_transit',
    CURRENT_TIMESTAMP - INTERVAL '30 minutes',
    CURRENT_TIMESTAMP + INTERVAL '2 hours',
    62500.00
);

-- Pending Shipment: Kumar Textiles
INSERT INTO shipments (id, company_id, truck_id, destination_id, shipment_number,
                      origin_location, origin_latitude, origin_longitude,
                      destination_location, destination_latitude, destination_longitude,
                      status, estimated_arrival, total_value)
VALUES (
    'e9f0a1b2-c3d4-2e3f-6a7b-8c9d0e1f2a3b',
    'e5f6a7b8-c9d0-8e9f-2a3b-4c5d6e7f8a9b', -- Kumar Textiles
    'e1f2a3b4-c5d6-4e5f-8a9b-0c1d2e3f4a5b', -- Textile Hauler
    'c5d6e7f8-a9b0-8c9d-2e3f-4a5b6c7d8e9f', -- Textile Warehouse
    'SHP-20251004-000003',
    'Textile Mill, Warangal', 18.0044, 79.5941,
    'Textile Warehouse, Secunderabad', 17.4399, 78.4983,
    'pending',
    CURRENT_TIMESTAMP + INTERVAL '4 hours',
    34500.00
);

-- Completed Shipment: Sharma Logistics
INSERT INTO shipments (id, company_id, truck_id, destination_id, shipment_number,
                      origin_location, origin_latitude, origin_longitude,
                      destination_location, destination_latitude, destination_longitude,
                      status, started_at, estimated_arrival, delivered_at, total_value)
VALUES (
    'f0a1b2c3-d4e5-3f4a-7b8c-9d0e1f2a3b4c',
    'f6a7b8c9-d0e1-9f0a-3b4c-5d6e7f8a9b0c', -- Sharma Logistics
    'c9d0e1f2-a3b4-2c3d-6e7f-8a9b0c1d2e3f', -- Speed Carrier
    'd6e7f8a9-b0c1-9d0e-3f4a-5b6c7d8e9f0a', -- Central Hub Pune
    'SHP-20251003-000001',
    'Industrial Park, Nashik', 19.9975, 73.7898,
    'Central Hub, Pune', 18.5993, 73.7386,
    'delivered',
    CURRENT_TIMESTAMP - INTERVAL '1 day 3 hours',
    CURRENT_TIMESTAMP - INTERVAL '1 day 30 minutes',
    CURRENT_TIMESTAMP - INTERVAL '1 day 15 minutes',
    25000.00
);

-- ============================================
-- 8. SHIPMENT ITEMS
-- ============================================

-- Items for Shipment 1 (Kumar Electronics - In Transit)
INSERT INTO shipment_items (shipment_id, product_id, quantity, unit, unit_value, rfid_tag, status)
VALUES 
    ('c7d8e9f0-a1b2-0c1d-4e5f-6a7b8c9d0e1f', 'a9b0c1d2-e3f4-2a3b-6c7d-8e9f0a1b2c3d',
     2, 'pieces', 45000.00, 'RFID-KEL-TV-001', 'in_transit'),
    
    ('c7d8e9f0-a1b2-0c1d-4e5f-6a7b8c9d0e1f', 'a9b0c1d2-e3f4-2a3b-6c7d-8e9f0a1b2c3d',
     1, 'pieces', 45000.00, 'RFID-KEL-TV-002', 'in_transit');

-- Items for Shipment 2 (Patel Pharma - In Transit)
INSERT INTO shipment_items (shipment_id, product_id, quantity, unit, unit_value, rfid_tag, status)
VALUES 
    ('d8e9f0a1-b2c3-1d2e-5f6a-7b8c9d0e1f2a', 'a5b6c7d8-e9f0-8a9b-2c3d-4e5f6a7b8c9d',
     50, 'boxes', 850.00, 'RFID-PPH-ANT-B001', 'in_transit'),
    
    ('d8e9f0a1-b2c3-1d2e-5f6a-7b8c9d0e1f2a', 'b6c7d8e9-f0a1-9b0c-3d4e-5f6a7b8c9d0e',
     10, 'pieces', 2500.00, 'RFID-PPH-INS-001', 'in_transit');

-- Items for Shipment 3 (Kumar Textiles - Pending)
INSERT INTO shipment_items (shipment_id, product_id, quantity, unit, unit_value, rfid_tag, status)
VALUES 
    ('e9f0a1b2-c3d4-2e3f-6a7b-8c9d0e1f2a3b', 'd2e3f4a5-b6c7-5d6e-9f0a-1b2c3d4e5f6a',
     20, 'rolls', 1500.00, 'RFID-KTX-CFR-B001', 'pending'),
    
    ('e9f0a1b2-c3d4-2e3f-6a7b-8c9d0e1f2a3b', 'e3f4a5b6-c7d8-6e7f-0a1b-2c3d4e5f6a7b',
     2, 'pieces', 8500.00, 'RFID-KTX-SS-001', 'pending');

-- Items for Shipment 4 (Sharma - Delivered with 1 missing)
INSERT INTO shipment_items (shipment_id, product_id, quantity, unit, unit_value, rfid_tag, status, quantity_received, quantity_missing)
VALUES 
    ('f0a1b2c3-d4e5-3f4a-7b8c-9d0e1f2a3b4c', 'f4a5b6c7-d8e9-7f8a-1b2c-3d4e5f6a7b8c',
     4, 'boxes', 5000.00, 'RFID-SLS-IEP-B001', 'delivered', 4, 0),
    
    ('f0a1b2c3-d4e5-3f4a-7b8c-9d0e1f2a3b4c', 'f4a5b6c7-d8e9-7f8a-1b2c-3d4e5f6a7b8c',
     1, 'boxes', 5000.00, 'RFID-SLS-IEP-B002', 'missing', 0, 1);

-- ============================================
-- 9. GPS TRACKING DATA (Recent points for active shipments)
-- ============================================

-- GPS points for Shipment 1 (Kumar Electronics - Express Truck 1)
-- Simulating movement from Uppal to JNTU Road
INSERT INTO gps_tracking (shipment_id, truck_id, latitude, longitude, speed, heading, esp_device_id, timestamp)
VALUES 
    -- Starting point
    ('c7d8e9f0-a1b2-0c1d-4e5f-6a7b8c9d0e1f', 'b8c9d0e1-f2a3-1b2c-5d6e-7f8a9b0c1d2e',
     17.4065, 78.5550, 45.5, 270.0, 'ESP32-TRUCK-001', CURRENT_TIMESTAMP - INTERVAL '2 hours'),
    
    -- Midway points
    ('c7d8e9f0-a1b2-0c1d-4e5f-6a7b8c9d0e1f', 'b8c9d0e1-f2a3-1b2c-5d6e-7f8a9b0c1d2e',
     17.4200, 78.5200, 50.2, 265.0, 'ESP32-TRUCK-001', CURRENT_TIMESTAMP - INTERVAL '1 hour 30 minutes'),
    
    ('c7d8e9f0-a1b2-0c1d-4e5f-6a7b8c9d0e1f', 'b8c9d0e1-f2a3-1b2c-5d6e-7f8a9b0c1d2e',
     17.4350, 78.4600, 48.7, 268.0, 'ESP32-TRUCK-001', CURRENT_TIMESTAMP - INTERVAL '1 hour'),
    
    ('c7d8e9f0-a1b2-0c1d-4e5f-6a7b8c9d0e1f', 'b8c9d0e1-f2a3-1b2c-5d6e-7f8a9b0c1d2e',
     17.4420, 78.4200, 42.3, 270.0, 'ESP32-TRUCK-001', CURRENT_TIMESTAMP - INTERVAL '30 minutes'),
    
    -- Current/latest position
    ('c7d8e9f0-a1b2-0c1d-4e5f-6a7b8c9d0e1f', 'b8c9d0e1-f2a3-1b2c-5d6e-7f8a9b0c1d2e',
     17.4470, 78.4000, 35.8, 272.0, 'ESP32-TRUCK-001', CURRENT_TIMESTAMP - INTERVAL '5 minutes');

-- GPS points for Shipment 2 (Patel Pharma - Pharma Express)
INSERT INTO gps_tracking (shipment_id, truck_id, latitude, longitude, speed, heading, esp_device_id, battery_level, signal_strength, timestamp)
VALUES 
    -- Starting point
    ('d8e9f0a1-b2c3-1d2e-5f6a-7b8c9d0e1f2a', 'd0e1f2a3-b4c5-3d4e-7f8a-9b0c1d2e3f4a',
     22.9801, 72.6338, 40.0, 180.0, 'ESP32-TRUCK-003', 95, 85, CURRENT_TIMESTAMP - INTERVAL '30 minutes'),
    
    ('d8e9f0a1-b2c3-1d2e-5f6a-7b8c9d0e1f2a', 'd0e1f2a3-b4c5-3d4e-7f8a-9b0c1d2e3f4a',
     22.9950, 72.6100, 38.5, 175.0, 'ESP32-TRUCK-003', 94, 82, CURRENT_TIMESTAMP - INTERVAL '15 minutes'),
    
    -- Current position
    ('d8e9f0a1-b2c3-1d2e-5f6a-7b8c9d0e1f2a', 'd0e1f2a3-b4c5-3d4e-7f8a-9b0c1d2e3f4a',
     23.0100, 72.5900, 42.0, 178.0, 'ESP32-TRUCK-003', 93, 80, CURRENT_TIMESTAMP - INTERVAL '2 minutes');

-- ============================================
-- 10. RFID SCANS (For completed shipment)
-- ============================================

-- All items scanned for the first product (all 4 boxes received)
INSERT INTO rfid_scans (shipment_id, destination_id, shipment_item_id, rfid_tag, 
                       scan_timestamp, esp_device_id, is_expected, is_matched)
VALUES 
    ('f0a1b2c3-d4e5-3f4a-7b8c-9d0e1f2a3b4c', 'd6e7f8a9-b0c1-9d0e-3f4a-5b6c7d8e9f0a',
     (SELECT id FROM shipment_items WHERE rfid_tag = 'RFID-SLS-IEP-B001'),
     'RFID-SLS-IEP-B001',
     CURRENT_TIMESTAMP - INTERVAL '1 day 15 minutes',
     'ESP32-RFID-004', true, true);

-- Second product item NOT scanned (missing) - no entry for RFID-SLS-IEP-B002

-- ============================================
-- 11. DELIVERY VERIFICATION (For completed shipment)
-- ============================================
INSERT INTO delivery_verification (shipment_id, destination_id, total_items_expected, 
                                  total_items_received, total_items_missing, 
                                  verification_status, verified_by, verified_at)
VALUES 
    ('f0a1b2c3-d4e5-3f4a-7b8c-9d0e1f2a3b4c', 'd6e7f8a9-b0c1-9d0e-3f4a-5b6c7d8e9f0a',
     2, 1, 1, 'discrepancy', 'Warehouse Staff - Pune', 
     CURRENT_TIMESTAMP - INTERVAL '1 day 10 minutes');

-- ============================================
-- 12. MISSING PRODUCTS LOG (For completed shipment)
-- ============================================
INSERT INTO missing_products_log (shipment_id, shipment_item_id, product_id,
                                 expected_quantity, received_quantity, missing_quantity,
                                 rfid_tag, discrepancy_type, estimated_loss_value,
                                 resolution_status)
VALUES 
    ('f0a1b2c3-d4e5-3f4a-7b8c-9d0e1f2a3b4c',
     (SELECT id FROM shipment_items WHERE rfid_tag = 'RFID-SLS-IEP-B002'),
     'f4a5b6c7-d8e9-7f8a-1b2c-3d4e5f6a7b8c',
     1, 0, 1,
     'RFID-SLS-IEP-B002',
     'missing',
     5000.00,
     'open');

-- ============================================
-- 13. AUDIT LOGS (Sample entries)
-- ============================================
INSERT INTO audit_logs (user_id, company_id, action, table_name, record_id, 
                       new_values, ip_address)
VALUES 
    ('a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'd4e5f6a7-b8c9-7d8e-1f2a-3b4c5d6e7f8a',
     'CREATE_SHIPMENT', 'shipments', 'c7d8e9f0-a1b2-0c1d-4e5f-6a7b8c9d0e1f',
     '{"shipment_number": "SHP-20251004-000001", "status": "pending"}'::jsonb,
     '103.216.82.14'),
    
    ('c3d4e5f6-a7b8-6c7d-0e1f-2a3b4c5d6e7f', 'a7b8c9d0-e1f2-0a1b-4c5d-6e7f8a9b0c1d',
     'CREATE_SHIPMENT', 'shipments', 'd8e9f0a1-b2c3-1d2e-5f6a-7b8c9d0e1f2a',
     '{"shipment_number": "SHP-20251004-000002", "status": "pending"}'::jsonb,
     '110.227.196.35'),
    
    ('b2c3d4e5-f6a7-5b6c-9d0e-1f2a3b4c5d6e', 'f6a7b8c9-d0e1-9f0a-3b4c-5d6e7f8a9b0c',
     'FINALIZE_DELIVERY', 'shipments', 'f0a1b2c3-d4e5-3f4a-7b8c-9d0e1f2a3b4c',
     '{"status": "delivered", "verification_status": "discrepancy"}'::jsonb,
     '117.247.183.92');

-- ============================================
-- SUMMARY OF SEED DATA
-- ============================================

-- Count summary
DO $$
BEGIN
    RAISE NOTICE '=== SEED DATA SUMMARY ===';
    RAISE NOTICE 'Users: %', (SELECT COUNT(*) FROM users);
    RAISE NOTICE 'Companies: %', (SELECT COUNT(*) FROM companies);
    RAISE NOTICE 'Trucks: %', (SELECT COUNT(*) FROM trucks);
    RAISE NOTICE 'Company-Truck Associations: %', (SELECT COUNT(*) FROM company_trucks);
    RAISE NOTICE 'RFID Destinations: %', (SELECT COUNT(*) FROM rfid_destinations);
    RAISE NOTICE 'Products: %', (SELECT COUNT(*) FROM products);
    RAISE NOTICE 'Shipments: %', (SELECT COUNT(*) FROM shipments);
    RAISE NOTICE '  - In Transit: %', (SELECT COUNT(*) FROM shipments WHERE status = 'in_transit');
    RAISE NOTICE '  - Pending: %', (SELECT COUNT(*) FROM shipments WHERE status = 'pending');
    RAISE NOTICE '  - Delivered: %', (SELECT COUNT(*) FROM shipments WHERE status = 'delivered');
    RAISE NOTICE 'Shipment Items: %', (SELECT COUNT(*) FROM shipment_items);
    RAISE NOTICE 'GPS Tracking Points: %', (SELECT COUNT(*) FROM gps_tracking);
    RAISE NOTICE 'RFID Scans: %', (SELECT COUNT(*) FROM rfid_scans);
    RAISE NOTICE 'Missing Products: %', (SELECT COUNT(*) FROM missing_products_log);
    RAISE NOTICE '========================';
END $$;