-- =============================================================
-- Supply Chain Management System - Analytics & Reporting Queries
-- =============================================================

USE supply_chain_db;

-- -------------------------------------------------------
-- INVENTORY ANALYTICS
-- -------------------------------------------------------

SELECT
    p.id,
    p.name          AS product_name,
    p.sku,
    SUM(i.quantity) AS total_stock,
    p.price,
    SUM(i.quantity) * p.price AS stock_value
FROM products p
LEFT JOIN inventory i ON i.product_id = p.id
GROUP BY p.id, p.name, p.sku, p.price
ORDER BY stock_value DESC;

SELECT
    w.id,
    w.name              AS warehouse_name,
    w.location,
    COUNT(i.id)         AS distinct_products,
    SUM(i.quantity)     AS total_units
FROM warehouses w
LEFT JOIN inventory i ON i.warehouse_id = w.id
GROUP BY w.id, w.name, w.location
ORDER BY total_units DESC;

SELECT
    w.name  AS warehouse,
    p.name  AS product,
    p.sku,
    i.quantity
FROM inventory i
JOIN warehouses w ON w.id = i.warehouse_id
JOIN products   p ON p.id = i.product_id
WHERE i.quantity < 15
ORDER BY i.quantity ASC;

SELECT
    w.name  AS warehouse,
    p.name  AS product,
    p.sku
FROM inventory i
JOIN warehouses w ON w.id = i.warehouse_id
JOIN products   p ON p.id = i.product_id
WHERE i.quantity = 0;

-- -------------------------------------------------------
-- ORDER ANALYTICS
-- -------------------------------------------------------

SELECT
    status_code,
    COUNT(*) AS order_count
FROM orders
GROUP BY status_code
ORDER BY order_count DESC;

SELECT
    o.order_number,
    o.status_code,
    w.name             AS warehouse,
    o.created_at,
    SUM(oi.line_total) AS total_revenue
FROM orders o
JOIN warehouses w  ON w.id = o.warehouse_id
JOIN order_item oi ON oi.order_id = o.id
GROUP BY o.id, o.order_number, o.status_code, w.name, o.created_at
ORDER BY total_revenue DESC;

SELECT
    SUM(oi.line_total) AS total_delivered_revenue
FROM orders o
JOIN order_item oi ON oi.order_id = o.id
WHERE o.status_code = 'DELIVERED';

SELECT
    p.name              AS product_name,
    p.sku,
    SUM(oi.quantity)    AS total_ordered,
    SUM(oi.line_total)  AS total_revenue
FROM order_item oi
JOIN products p ON p.id = oi.product_id
JOIN orders   o ON o.id = oi.order_id
WHERE o.status_code <> 'CANCELLED'
GROUP BY p.id, p.name, p.sku
ORDER BY total_ordered DESC
LIMIT 5;

SELECT
    o.order_number,
    o.created_at,
    o.delivered_at,
    TIMESTAMPDIFF(DAY, o.created_at, o.delivered_at) AS fulfillment_days
FROM orders o
WHERE o.status_code = 'DELIVERED' AND o.delivered_at IS NOT NULL
ORDER BY fulfillment_days ASC;

SELECT
    w.name             AS warehouse,
    COUNT(o.id)        AS total_orders,
    SUM(oi.line_total) AS total_revenue
FROM warehouses w
LEFT JOIN orders o ON o.warehouse_id = w.id
LEFT JOIN order_item oi ON oi.order_id = o.id
GROUP BY w.id, w.name
ORDER BY total_orders DESC;

-- -------------------------------------------------------
-- SUPPLIER ANALYTICS
-- -------------------------------------------------------

SELECT
    s.id,
    s.name               AS supplier_name,
    COUNT(ps.product_id) AS products_supplied
FROM suppliers s
LEFT JOIN product_suppliers ps ON ps.supplier_id = s.id
GROUP BY s.id, s.name
ORDER BY products_supplied DESC;

SELECT
    s.name                    AS supplier_name,
    SUM(i.quantity * p.price) AS contributed_stock_value
FROM suppliers s
JOIN product_suppliers ps ON ps.supplier_id = s.id
JOIN products p ON p.id = ps.product_id
LEFT JOIN inventory i ON i.product_id = p.id
GROUP BY s.id, s.name
ORDER BY contributed_stock_value DESC;

-- -------------------------------------------------------
-- COMBINED / CROSS-ENTITY QUERIES
-- -------------------------------------------------------

SELECT
    o.order_number,
    o.status_code                    AS order_status,
    w.name                           AS warehouse,
    p.name                           AS product,
    p.sku,
    oi.quantity,
    oi.unit_price,
    oi.line_total,
    o.created_at,
    o.expected_delivery_date,
    o.delivered_at
FROM orders o
JOIN warehouses w  ON w.id = o.warehouse_id
JOIN order_item oi ON oi.order_id = o.id
JOIN products   p  ON p.id = oi.product_id
ORDER BY o.created_at DESC, p.name;

SELECT p.id, p.name, p.sku
FROM products p
LEFT JOIN order_item oi ON oi.product_id = p.id
WHERE oi.id IS NULL;

SELECT
    o.order_number,
    w.name       AS warehouse,
    p.name       AS product,
    oi.quantity  AS ordered_qty,
    i.quantity   AS current_stock
FROM orders o
JOIN warehouses w  ON w.id = o.warehouse_id
JOIN order_item oi ON oi.order_id = o.id
JOIN products   p  ON p.id = oi.product_id
LEFT JOIN inventory i ON i.warehouse_id = o.warehouse_id AND i.product_id = p.id
WHERE o.status_code = 'DELIVERED'
ORDER BY o.order_number, p.name;
