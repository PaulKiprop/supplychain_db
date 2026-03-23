-- =============================================================
-- Supply Chain Management System -  seedning Sample data 
-- =============================================================

USE supply_chain_db;

INSERT INTO order_statuses (status_code, status_label, sort_order, is_terminal) VALUES
    ('PENDING',   'Pending',   1, 0),
    ('CONFIRMED', 'Confirmed', 2, 0),
    ('PICKING',   'Picking',   3, 0),
    ('SHIPPED',   'Shipped',   4, 0),
    ('DELIVERED', 'Delivered', 5, 1),
    ('CANCELLED', 'Cancelled', 6, 1)
ON DUPLICATE KEY UPDATE
    status_label = VALUES(status_label),
    sort_order = VALUES(sort_order),
    is_terminal = VALUES(is_terminal);

-- Suppliers
INSERT INTO suppliers (name, email) VALUES
    ('Global Parts Co.',      'contact@globalparts.com'),
    ('FastShip Logistics',    'sales@fastship.com'),
    ('TechComp Supplies',     'orders@techcomp.com'),
    ('EcoMaterials Ltd.',     'info@ecomaterials.com'),
    ('Prime Distributors',    'prime@distributors.com');

-- Products
INSERT INTO products (name, sku, description, price) VALUES
    ('Laptop 15"',         'PROD-LPT-001', 'High-performance 15-inch laptop',            1299.99),
    ('Mechanical Keyboard','PROD-KBD-002', 'Tactile mechanical keyboard, TKL layout',      89.99),
    ('USB-C Hub 7-in-1',   'PROD-HUB-003', 'Multi-port USB-C hub with HDMI and PD',        45.50),
    ('Monitor 27" 4K',     'PROD-MON-004', 'Ultra-sharp 4K IPS monitor',                  499.00),
    ('Wireless Mouse',     'PROD-MSE-005', 'Ergonomic wireless mouse, 2.4GHz',             39.99),
    ('SSD 1TB NVMe',       'PROD-SSD-006', 'High-speed NVMe SSD, PCIe 4.0',              109.99),
    ('RAM 32GB DDR5',      'PROD-RAM-007', '32GB DDR5 4800MHz desktop memory kit',        149.99),
    ('Webcam 1080p',       'PROD-CAM-008', 'Full HD webcam with built-in microphone',      55.00);

-- Product <-> Supplier relationships
INSERT INTO product_suppliers (product_id, supplier_id) VALUES
    (1, 1), (1, 3),
    (2, 3),
    (3, 2), (3, 5),
    (4, 1), (4, 5),
    (5, 2),
    (6, 3), (6, 4),
    (7, 1), (7, 3),
    (8, 2);

-- Warehouses
INSERT INTO warehouses (name, location) VALUES
    ('Berlin Central',    'Berlin, Germany'),
    ('Hamburg North',     'Hamburg, Germany'),
    ('Munich South',      'Munich, Germany'),
    ('Frankfurt Hub',     'Frankfurt, Germany');

-- Inventory
INSERT INTO inventory (warehouse_id, product_id, quantity) VALUES
    (1, 1, 50),  (1, 2, 120), (1, 3, 200), (1, 4, 30),
    (1, 5, 150), (1, 6, 80),  (1, 7, 60),  (1, 8, 90),
    (2, 1, 20),  (2, 3, 80),  (2, 5, 70),  (2, 6, 40),
    (3, 2, 60),  (3, 4, 15),  (3, 7, 25),  (3, 8, 45),
    (4, 1, 10),  (4, 2, 30),  (4, 4, 8),   (4, 6, 5);

-- Orders
INSERT INTO orders (order_number, status_code, warehouse_id, expected_delivery_date, delivered_at, notes) VALUES
    ('ORD-2024-0001', 'DELIVERED', 1, '2024-01-15 12:00:00', '2024-01-14 11:00:00', 'Q1 laptop restock'),
    ('ORD-2024-0002', 'SHIPPED',   2, '2024-02-20 12:00:00', NULL,                  'Peripheral bundle for Hamburg'),
    ('ORD-2024-0003', 'CONFIRMED', 3, '2024-03-05 12:00:00', NULL,                  'Monitor order Munich'),
    ('ORD-2024-0004', 'PENDING',   4, NULL,                  NULL,                  'Urgent SSD restock Frankfurt'),
    ('ORD-2024-0005', 'CANCELLED', 1, NULL,                  NULL,                  'Duplicate order - cancelled');

-- Order Items

INSERT INTO order_item (order_id, product_id, quantity, unit_price, line_total) VALUES
    (1, 1, 10, 1299.99, 12999.90),
    (1, 6, 20,  109.99,  2199.80),
    (2, 2, 15,   89.99,  1349.85),
    (2, 5, 25,   39.99,   999.75),
    (2, 8, 10,   55.00,   550.00),
    (3, 4,  5,  499.00,  2495.00),
    (3, 7, 10,  149.99,  1499.90),
    (4, 6, 50,  109.99,  5499.50),
    (5, 1,  5, 1299.99,  6499.95);

-- Order Status History
INSERT INTO order_status_history (order_id, from_status_code, to_status_code, changed_at, comment, changed_by) VALUES
    (1, NULL,        'PENDING',   '2024-01-02 09:00:00', 'Order created', 'SYSTEM'),
    (1, 'PENDING',   'CONFIRMED', '2024-01-03 10:00:00', 'Payment confirmed', 'SYSTEM'),
    (1, 'CONFIRMED', 'PICKING',   '2024-01-05 08:00:00', 'Warehouse picking started', 'SYSTEM'),
    (1, 'PICKING',   'SHIPPED',   '2024-01-07 14:00:00', 'Dispatched via DHL', 'SYSTEM'),
    (1, 'SHIPPED',   'DELIVERED', '2024-01-14 11:00:00', 'Delivered to Berlin Central', 'SYSTEM'),
    (2, NULL,        'PENDING',   '2024-01-20 09:00:00', 'Order created', 'SYSTEM'),
    (2, 'PENDING',   'CONFIRMED', '2024-01-21 10:00:00', 'Confirmed', 'SYSTEM'),
    (2, 'CONFIRMED', 'PICKING',   '2024-01-23 08:00:00', 'Picking in progress', 'SYSTEM'),
    (2, 'PICKING',   'SHIPPED',   '2024-01-25 16:00:00', 'In transit', 'SYSTEM'),
    (3, NULL,        'PENDING',   '2024-02-10 09:00:00', 'Order created', 'SYSTEM'),
    (3, 'PENDING',   'CONFIRMED', '2024-02-11 09:00:00', 'Confirmed', 'SYSTEM'),
    (4, NULL,        'PENDING',   '2024-02-25 09:00:00', 'Order created', 'SYSTEM'),
    (5, NULL,        'PENDING',   '2024-01-02 09:00:00', 'Order created', 'SYSTEM'),
    (5, 'PENDING',   'CANCELLED', '2024-01-02 09:30:00', 'Duplicate of ORD-2024-0001', 'SYSTEM');

SELECT 'sample data inserted successfully.' AS status;
