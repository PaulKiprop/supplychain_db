-- =============================================================
-- Supply Chain Management System -  CRUD operations examples
-- =============================================================

USE supply_chain_db;

INSERT INTO suppliers (name, email)
VALUES ('Unified Trade GmbH', 'hello@unifiedtrade.de')
ON DUPLICATE KEY UPDATE name = VALUES(name);

INSERT INTO products (name, sku, description, price)
VALUES ('Docking Station Pro', 'PROD-DCK-901', 'USB-C docking station with dual display support', 159.99)
ON DUPLICATE KEY UPDATE
  name = VALUES(name),
  description = VALUES(description),
  price = VALUES(price);

INSERT INTO product_suppliers (product_id, supplier_id)
VALUES (
  (SELECT id FROM products WHERE sku = 'PROD-DCK-901' LIMIT 1),
  (SELECT id FROM suppliers WHERE email = 'hello@unifiedtrade.de' LIMIT 1)
)
ON DUPLICATE KEY UPDATE product_id = VALUES(product_id);

-- Add inventory for that product in warehouse 1
INSERT INTO inventory (warehouse_id, product_id, quantity)
VALUES (
    1,
    (SELECT id FROM products WHERE sku = 'PROD-DCK-901' LIMIT 1),
    40
)
ON DUPLICATE KEY UPDATE quantity = quantity + 40;

-- Product with supplier names
SELECT
    p.id,
    p.name,
    p.sku,
    p.price,
    GROUP_CONCAT(s.name ORDER BY s.name SEPARATOR ', ') AS suppliers
FROM products p
LEFT JOIN product_suppliers ps ON ps.product_id = p.id
LEFT JOIN suppliers s ON s.id = ps.supplier_id
WHERE p.sku = 'PROD-DCK-901'
GROUP BY p.id, p.name, p.sku, p.price;

-- Current inventory snapshot for warehouse 1
SELECT
    w.name AS warehouse,
    p.name AS product,
    p.sku,
    i.quantity
FROM inventory i
JOIN warehouses w ON w.id = i.warehouse_id
JOIN products p ON p.id = i.product_id
WHERE i.warehouse_id = 1
ORDER BY p.name
LIMIT 20;

-- Update product price
UPDATE products
SET price = 154.99
WHERE sku = 'PROD-DCK-901';

-- Restock inventory by 10 units
UPDATE inventory
SET quantity = quantity + 10
WHERE warehouse_id = 1
  AND product_id = (SELECT id FROM products WHERE sku = 'PROD-DCK-901' LIMIT 1);

-- Remove supplier mapping for the sample product
DELETE FROM product_suppliers
WHERE product_id = (SELECT id FROM products WHERE sku = 'PROD-DCK-901' LIMIT 1)
  AND supplier_id = (SELECT id FROM suppliers WHERE email = 'hello@unifiedtrade.de' LIMIT 1);

