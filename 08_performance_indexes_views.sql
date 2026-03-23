-- =============================================================
-- Supply Chain Management System - Performance Layer
-- =============================================================

USE supply_chain_db;

-- Index optimization for high-frequency filters, joins, and sorting

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'orders'
      AND INDEX_NAME = 'idx_orders_status_warehouse_created'
);
SET @sql := IF(
    @idx_exists = 0,
    'CREATE INDEX idx_orders_status_warehouse_created ON orders (status_code, warehouse_id, created_at)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'orders'
      AND INDEX_NAME = 'idx_orders_created_at'
);
SET @sql := IF(
    @idx_exists = 0,
    'CREATE INDEX idx_orders_created_at ON orders (created_at)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'order_item'
      AND INDEX_NAME = 'idx_order_item_order_product'
);
SET @sql := IF(
    @idx_exists = 0,
    'CREATE INDEX idx_order_item_order_product ON order_item (order_id, product_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'inventory'
      AND INDEX_NAME = 'idx_inventory_product_warehouse_qty'
);
SET @sql := IF(
    @idx_exists = 0,
    'CREATE INDEX idx_inventory_product_warehouse_qty ON inventory (product_id, warehouse_id, quantity)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'order_status_history'
      AND INDEX_NAME = 'idx_osh_order_changed_at'
);
SET @sql := IF(
    @idx_exists = 0,
    'CREATE INDEX idx_osh_order_changed_at ON order_status_history (order_id, changed_at)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'procurement_requests'
      AND INDEX_NAME = 'idx_proc_req_status_requested_at'
);
SET @sql := IF(
    @idx_exists = 0,
    'CREATE INDEX idx_proc_req_status_requested_at ON procurement_requests (status, requested_at)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'inventory_reorder_policy'
      AND INDEX_NAME = 'idx_reorder_policy_warehouse_product'
);
SET @sql := IF(
    @idx_exists = 0,
    'CREATE INDEX idx_reorder_policy_warehouse_product ON inventory_reorder_policy (warehouse_id, product_id)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_exists := (
    SELECT COUNT(*)
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'inventory_transactions'
      AND INDEX_NAME = 'idx_inventory_transactions_lookup'
);
SET @sql := IF(
    @idx_exists = 0,
    'CREATE INDEX idx_inventory_transactions_lookup ON inventory_transactions (warehouse_id, product_id, changed_at)',
    'SELECT 1'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- -------------------------------------------------------
-- Views for faster data access and cleaner reporting SQL
-- -------------------------------------------------------

CREATE OR REPLACE VIEW vw_order_totals AS
SELECT
    o.id,
    o.order_number,
    o.status_code,
    o.warehouse_id,
    o.created_at,
    COALESCE(SUM(oi.line_total), 0.00) AS order_total,
    COALESCE(SUM(oi.quantity), 0) AS total_units
FROM orders o
LEFT JOIN order_item oi ON oi.order_id = o.id
GROUP BY o.id, o.order_number, o.status_code, o.warehouse_id, o.created_at;

CREATE OR REPLACE VIEW vw_inventory_snapshot AS
SELECT
    i.warehouse_id,
    w.name AS warehouse_name,
    i.product_id,
    p.name AS product_name,
    p.sku,
    i.quantity,
    p.price,
    (i.quantity * p.price) AS stock_value
FROM inventory i
JOIN warehouses w ON w.id = i.warehouse_id
JOIN products p ON p.id = i.product_id;

CREATE OR REPLACE VIEW vw_low_stock_alert AS
SELECT
    rp.warehouse_id,
    w.name AS warehouse_name,
    rp.product_id,
    p.name AS product_name,
    p.sku,
    i.quantity AS current_stock,
    rp.min_stock_level,
    rp.reorder_quantity,
    s.name AS preferred_supplier
FROM inventory_reorder_policy rp
JOIN inventory i
  ON i.warehouse_id = rp.warehouse_id
 AND i.product_id = rp.product_id
JOIN warehouses w ON w.id = rp.warehouse_id
JOIN products p ON p.id = rp.product_id
LEFT JOIN suppliers s ON s.id = rp.preferred_supplier_id
WHERE i.quantity < rp.min_stock_level;

CREATE OR REPLACE VIEW vw_supplier_product_coverage AS
SELECT
    s.id AS supplier_id,
    s.name AS supplier_name,
    COUNT(DISTINCT ps.product_id) AS distinct_products,
    COALESCE(SUM(i.quantity * p.price), 0.00) AS linked_stock_value
FROM suppliers s
LEFT JOIN product_suppliers ps ON ps.supplier_id = s.id
LEFT JOIN products p ON p.id = ps.product_id
LEFT JOIN inventory i ON i.product_id = p.id
GROUP BY s.id, s.name;
