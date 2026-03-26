-- =============================================================
-- Supply Chain Management System - Bulk Seed From CSV
-- =============================================================


USE supply_chain_db;

DROP TEMPORARY TABLE IF EXISTS stg_products;
CREATE TEMPORARY TABLE stg_products (
    sku VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(12,2) NOT NULL
);

LOAD DATA LOCAL INFILE '/absolute/path/to/supplychain_db/seed_data/products.csv'
INTO TABLE stg_products
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(sku, name, description, price);

INSERT INTO products (sku, name, description, price)
SELECT sku, name, description, price
FROM stg_products
ON DUPLICATE KEY UPDATE
    name = VALUES(name),
    description = VALUES(description),
    price = VALUES(price);

DROP TEMPORARY TABLE IF EXISTS stg_product_suppliers;
CREATE TEMPORARY TABLE stg_product_suppliers (
    product_sku VARCHAR(100) NOT NULL,
    supplier_email VARCHAR(255) NOT NULL
);

LOAD DATA LOCAL INFILE '/absolute/path/to/supplychain_db/seed_data/product_suppliers.csv'
INTO TABLE stg_product_suppliers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_sku, supplier_email);

INSERT INTO product_suppliers (product_id, supplier_id)
SELECT DISTINCT p.id, s.id
FROM stg_product_suppliers sps
JOIN products p ON p.sku = sps.product_sku
JOIN suppliers s ON s.email = sps.supplier_email
ON DUPLICATE KEY UPDATE
    product_id = VALUES(product_id);

DROP TEMPORARY TABLE IF EXISTS stg_inventory;
CREATE TEMPORARY TABLE stg_inventory (
    warehouse_name VARCHAR(255) NOT NULL,
    product_sku VARCHAR(100) NOT NULL,
    quantity INT NOT NULL
);

LOAD DATA LOCAL INFILE '/absolute/path/to/supplychain_db/seed_data/inventory.csv'
INTO TABLE stg_inventory
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(warehouse_name, product_sku, quantity);

INSERT INTO inventory (warehouse_id, product_id, quantity)
SELECT w.id, p.id, si.quantity
FROM stg_inventory si
JOIN warehouses w ON w.name = si.warehouse_name
JOIN products p ON p.sku = si.product_sku
ON DUPLICATE KEY UPDATE
    quantity = VALUES(quantity);

DROP TEMPORARY TABLE IF EXISTS stg_orders;
CREATE TEMPORARY TABLE stg_orders (
    order_number VARCHAR(100) NOT NULL,
    warehouse_name VARCHAR(255) NOT NULL,
    status_code VARCHAR(20) NOT NULL,
    expected_delivery_date DATETIME NULL,
    delivered_at DATETIME NULL,
    notes TEXT NULL
);

LOAD DATA LOCAL INFILE '/absolute/path/to/supplychain_db/seed_data/orders.csv'
INTO TABLE stg_orders
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_number, warehouse_name, status_code, expected_delivery_date, delivered_at, notes);

INSERT INTO orders (
    order_number,
    status_code,
    warehouse_id,
    expected_delivery_date,
    delivered_at,
    notes
)
SELECT
    so.order_number,
    so.status_code,
    w.id,
    so.expected_delivery_date,
    so.delivered_at,
    so.notes
FROM stg_orders so
JOIN warehouses w ON w.name = so.warehouse_name
ON DUPLICATE KEY UPDATE
    status_code = VALUES(status_code),
    warehouse_id = VALUES(warehouse_id),
    expected_delivery_date = VALUES(expected_delivery_date),
    delivered_at = VALUES(delivered_at),
    notes = VALUES(notes);

DROP TEMPORARY TABLE IF EXISTS stg_order_items;
CREATE TEMPORARY TABLE stg_order_items (
    order_number VARCHAR(100) NOT NULL,
    product_sku VARCHAR(100) NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(12,2) NULL
);

LOAD DATA LOCAL INFILE '/absolute/path/to/supplychain_db/seed_data/order_items.csv'
INTO TABLE stg_order_items
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(order_number, product_sku, quantity, unit_price);

INSERT INTO order_item (order_id, product_id, quantity, unit_price, line_total)
SELECT
    o.id,
    p.id,
    soi.quantity,
    COALESCE(soi.unit_price, p.price),
    soi.quantity * COALESCE(soi.unit_price, p.price)
FROM stg_order_items soi
JOIN orders o ON o.order_number = soi.order_number
JOIN products p ON p.sku = soi.product_sku
LEFT JOIN order_item oi
  ON oi.order_id = o.id
 AND oi.product_id = p.id
WHERE oi.id IS NULL;

SELECT 'bulk CSV seed template completed successfully.' AS status;
