-- =============================================================
-- Supply Chain Management System - Advanced Tests
-- =============================================================

USE supply_chain_db;

-- -------------------------------------------------------
-- 0) Pre-clean from any prior interrupted test run
-- -------------------------------------------------------

SET @existing_order_id := (
    SELECT id
    FROM orders
    WHERE order_number = 'ORD-2026-9001'
    LIMIT 1
);

SET @existing_qty_p2 := COALESCE((
    SELECT SUM(quantity)
    FROM order_item
    WHERE order_id = @existing_order_id
      AND product_id = 2
), 0);

SET @existing_qty_p5 := COALESCE((
    SELECT SUM(quantity)
    FROM order_item
    WHERE order_id = @existing_order_id
      AND product_id = 5
), 0);

CALL sp_apply_inventory_adjustment(1, 2, @existing_qty_p2, 'Test pre-clean restore baseline for warehouse 1 product 2');
CALL sp_apply_inventory_adjustment(1, 5, @existing_qty_p5, 'Test pre-clean restore baseline for warehouse 1 product 5');

DELETE FROM orders WHERE order_number = 'ORD-2026-9001';

DELETE FROM procurement_requests
WHERE (warehouse_id = 4 AND product_id = 6)
   OR (warehouse_id = 4 AND product_id = 4)
   OR (warehouse_id = 2 AND product_id = 1)
   OR reason LIKE 'Auto request: insufficient stock for order ORD-2026-9001%';

DELETE FROM inventory_reorder_policy
WHERE (warehouse_id = 4 AND product_id = 6)
   OR (warehouse_id = 4 AND product_id = 4)
   OR (warehouse_id = 2 AND product_id = 1);

DELETE FROM inventory_transactions
WHERE reason LIKE 'Test %'
   OR reference_id LIKE 'ORD-2026-9001|PRD:%'
   OR reason = 'Stock reserved for order ORD-2026-9001';

-- -------------------------------------------------------
-- 1) Snapshot baseline quantities for repeatable cleanup
-- -------------------------------------------------------

SET @baseline_wh1_p2 := (
    SELECT quantity
    FROM inventory
    WHERE warehouse_id = 1 AND product_id = 2
    LIMIT 1
);

SET @baseline_wh1_p5 := (
    SELECT quantity
    FROM inventory
    WHERE warehouse_id = 1 AND product_id = 5
    LIMIT 1
);

SET @baseline_wh4_p6 := (
    SELECT quantity
    FROM inventory
    WHERE warehouse_id = 4 AND product_id = 6
    LIMIT 1
);

-- -------------------------------------------------------
-- 2) Configure reorder policies for low-stock automation
-- -------------------------------------------------------

INSERT INTO inventory_reorder_policy (
    warehouse_id,
    product_id,
    min_stock_level,
    reorder_quantity,
    preferred_supplier_id,
    lead_time_days
) VALUES
    (4, 6, 10, 40, 3, 5),
    (4, 4, 12, 20, 1, 7),
    (2, 1, 25, 30, 1, 6)
ON DUPLICATE KEY UPDATE
    min_stock_level = VALUES(min_stock_level),
    reorder_quantity = VALUES(reorder_quantity),
    preferred_supplier_id = VALUES(preferred_supplier_id),
    lead_time_days = VALUES(lead_time_days);

SELECT *
FROM inventory_reorder_policy
ORDER BY warehouse_id, product_id;

-- -------------------------------------------------------
-- 3) Procedure tests: create order and add items
-- -------------------------------------------------------

CALL sp_create_order(
    'ORD-2026-9001',
    1,
    '2026-04-15 12:00:00',
    'Automated test order for advanced SQL features'
);

CALL sp_add_order_item('ORD-2026-9001', 2, 12, NULL);
CALL sp_add_order_item('ORD-2026-9001', 5, 20, 39.99);

SELECT
    o.order_number,
    o.status_code,
    oi.product_id,
    oi.quantity,
    oi.unit_price,
    oi.line_total
FROM orders o
JOIN order_item oi ON oi.order_id = o.id
WHERE o.order_number = 'ORD-2026-9001'
ORDER BY oi.product_id;

-- -------------------------------------------------------
-- 4) Procedure + trigger tests: status transitions and history
-- -------------------------------------------------------

CALL sp_change_order_status('ORD-2026-9001', 'CONFIRMED', 'Payment validated', 'QA_USER');
CALL sp_change_order_status('ORD-2026-9001', 'PICKING', 'Picking started in warehouse', 'QA_USER');
CALL sp_change_order_status('ORD-2026-9001', 'SHIPPED', 'Shipment dispatched via carrier', 'QA_USER');
CALL sp_change_order_status('ORD-2026-9001', 'DELIVERED', 'Goods received successfully', 'QA_USER');

SELECT
    order_number,
    status_code,
    delivered_at
FROM orders
WHERE order_number = 'ORD-2026-9001';

SELECT
    osh.order_id,
    osh.from_status_code,
    osh.to_status_code,
    osh.changed_at,
    osh.changed_by,
    osh.comment
FROM order_status_history osh
JOIN orders o ON o.id = osh.order_id
WHERE o.order_number = 'ORD-2026-9001'
ORDER BY osh.changed_at;

-- -------------------------------------------------------
-- 5) Inventory procedure tests and trigger-based auditing
-- -------------------------------------------------------

CALL sp_apply_inventory_adjustment(4, 6, -2, 'Test outbound movement');
CALL sp_apply_inventory_adjustment(4, 6, 10, 'Test inbound movement');

SELECT
    warehouse_id,
    product_id,
    quantity
FROM inventory
WHERE warehouse_id = 4 AND product_id = 6;

SELECT
    warehouse_id,
    product_id,
    movement_type,
    quantity_change,
    quantity_before,
    quantity_after,
    changed_at
FROM inventory_transactions
WHERE warehouse_id = 4 AND product_id = 6
ORDER BY id DESC
LIMIT 10;

-- -------------------------------------------------------
-- 6) Reorder generation test
-- -------------------------------------------------------

CALL sp_generate_reorder_requests();

SELECT
    pr.id,
    w.name AS warehouse,
    p.name AS product,
    pr.requested_qty,
    pr.status,
    pr.reason,
    pr.requested_at
FROM procurement_requests pr
JOIN warehouses w ON w.id = pr.warehouse_id
JOIN products p ON p.id = pr.product_id
ORDER BY pr.id DESC;

-- -------------------------------------------------------
-- 7) Performance view checks
-- -------------------------------------------------------

SELECT *
FROM vw_order_totals
WHERE order_number = 'ORD-2026-9001';

SELECT *
FROM vw_inventory_snapshot
WHERE warehouse_id = 4 AND product_id = 6;

SELECT *
FROM vw_low_stock_alert
ORDER BY warehouse_id, product_id;

SELECT *
FROM vw_supplier_product_coverage
ORDER BY linked_stock_value DESC;

-- -------------------------------------------------------
-- 8) Negative test (this is expected to fail)
-- -------------------------------------------------------
-- CALL sp_change_order_status('ORD-2026-9001', 'PENDING', 'Invalid reverse transition', 'QA_USER');
-- UPDATE inventory SET quantity = -1 WHERE warehouse_id = 4 AND product_id = 6;
-- CALL sp_add_order_item('ORD-2026-9001', 6, 9999, NULL); -- insufficient stock -> error + procurement request

-- -------------------------------------------------------
-- 9) Cleanup: restore baseline state for repeatable reruns
-- -------------------------------------------------------

SET @delta_wh1_p2 := @baseline_wh1_p2 - (
    SELECT quantity
    FROM inventory
    WHERE warehouse_id = 1 AND product_id = 2
    LIMIT 1
);

SET @delta_wh1_p5 := @baseline_wh1_p5 - (
    SELECT quantity
    FROM inventory
    WHERE warehouse_id = 1 AND product_id = 5
    LIMIT 1
);

SET @delta_wh4_p6 := @baseline_wh4_p6 - (
    SELECT quantity
    FROM inventory
    WHERE warehouse_id = 4 AND product_id = 6
    LIMIT 1
);

CALL sp_apply_inventory_adjustment(1, 2, @delta_wh1_p2, 'Test cleanup restore baseline for warehouse 1 product 2');
CALL sp_apply_inventory_adjustment(1, 5, @delta_wh1_p5, 'Test cleanup restore baseline for warehouse 1 product 5');
CALL sp_apply_inventory_adjustment(4, 6, @delta_wh4_p6, 'Test cleanup restore baseline for warehouse 4 product 6');

DELETE FROM orders WHERE order_number = 'ORD-2026-9001';

DELETE FROM procurement_requests
WHERE (warehouse_id = 4 AND product_id = 6)
   OR (warehouse_id = 4 AND product_id = 4)
   OR (warehouse_id = 2 AND product_id = 1)
   OR reason LIKE 'Auto request: insufficient stock for order ORD-2026-9001%';

DELETE FROM inventory_reorder_policy
WHERE (warehouse_id = 4 AND product_id = 6)
   OR (warehouse_id = 4 AND product_id = 4)
   OR (warehouse_id = 2 AND product_id = 1);

DELETE FROM inventory_transactions
WHERE reason LIKE 'Test %'
   OR reference_id LIKE 'ORD-2026-9001|PRD:%'
   OR reason = 'Stock reserved for order ORD-2026-9001';

SELECT '09_validation_and_scenario_tests.sql completed with cleanup and baseline restoration.' AS status;

