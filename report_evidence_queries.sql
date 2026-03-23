-- =============================================================
-- Supply Chain Management System - Report Evidence Queries
-- =============================================================

USE supply_chain_db;

-- -------------------------------------------------------
-- A) Normalization  (new structures)
-- -------------------------------------------------------

SHOW TABLES LIKE 'order_statuses';
SHOW TABLES LIKE 'inventory_reorder_policy';
SHOW TABLES LIKE 'procurement_requests';

SELECT * FROM order_statuses ORDER BY sort_order;

SELECT
    o.order_number,
    o.status_code,
    os.status_label,
    os.is_terminal
FROM orders o
JOIN order_statuses os ON os.status_code = o.status_code
ORDER BY o.id
LIMIT 20;

-- -------------------------------------------------------
-- B) Constraints and data type 
-- -------------------------------------------------------

SELECT
    c.TABLE_NAME,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.COLUMN_TYPE
FROM information_schema.COLUMNS c
WHERE c.TABLE_SCHEMA = DATABASE()
  AND c.TABLE_NAME IN ('products', 'order_item')
  AND c.COLUMN_NAME IN ('price', 'unit_price', 'line_total')
ORDER BY c.TABLE_NAME, c.COLUMN_NAME;

SELECT
    tc.TABLE_NAME,
    tc.CONSTRAINT_NAME,
    tc.CONSTRAINT_TYPE
FROM information_schema.TABLE_CONSTRAINTS tc
WHERE tc.TABLE_SCHEMA = DATABASE()
  AND tc.TABLE_NAME IN ('products', 'inventory', 'order_item', 'inventory_reorder_policy', 'procurement_requests')
ORDER BY tc.TABLE_NAME, tc.CONSTRAINT_TYPE, tc.CONSTRAINT_NAME;

-- -------------------------------------------------------
-- C) Trigger/procedure automation 
-- -------------------------------------------------------

CALL sp_create_order('ORD-2026-REPORT-01', 1, NOW(), 'Report demo order');
CALL sp_add_order_item('ORD-2026-REPORT-01', 2, 3, NULL);
CALL sp_change_order_status('ORD-2026-REPORT-01', 'CONFIRMED', 'Report test transition', 'REPORT_USER');

SELECT
    o.order_number,
    o.status_code,
    o.delivered_at
FROM orders o
WHERE o.order_number = 'ORD-2026-REPORT-01';

SELECT
    osh.from_status_code,
    osh.to_status_code,
    osh.changed_by,
    osh.comment,
    osh.changed_at
FROM order_status_history osh
JOIN orders o ON o.id = osh.order_id
WHERE o.order_number = 'ORD-2026-REPORT-01'
ORDER BY osh.id;

CALL sp_apply_inventory_adjustment(1, 2, 5, 'Report inbound adjustment');

SELECT
    it.warehouse_id,
    it.product_id,
    it.movement_type,
    it.quantity_change,
    it.reference_type,
    it.reason,
    it.changed_at
FROM inventory_transactions it
WHERE it.warehouse_id = 1 AND it.product_id = 2
ORDER BY it.id DESC
LIMIT 10;

-- -------------------------------------------------------
-- D) Performance  (indexes + explain + views)
-- -------------------------------------------------------

SHOW INDEX FROM orders;
SHOW INDEX FROM order_item;
SHOW INDEX FROM inventory;

EXPLAIN SELECT *
FROM vw_order_totals
WHERE status_code = 'CONFIRMED'
ORDER BY created_at DESC;

SELECT * FROM vw_order_totals ORDER BY created_at DESC LIMIT 10;
SELECT * FROM vw_inventory_snapshot ORDER BY stock_value DESC LIMIT 10;
SELECT * FROM vw_low_stock_alert ORDER BY warehouse_id, product_id LIMIT 20;
SELECT * FROM vw_supplier_product_coverage ORDER BY linked_stock_value DESC LIMIT 10;

