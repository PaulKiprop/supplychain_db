-- =============================================================
-- Procedure: sp_generate_reorder_requests
-- =============================================================

USE supply_chain_db;

-- Creates procurement requests for items below reorder thresholds.
DROP PROCEDURE IF EXISTS sp_generate_reorder_requests;
DELIMITER $$
CREATE PROCEDURE sp_generate_reorder_requests ()
BEGIN
    INSERT INTO procurement_requests (
        warehouse_id,
        product_id,
        requested_qty,
        supplier_id,
        reason
    )
    SELECT
        rp.warehouse_id,
        rp.product_id,
        rp.reorder_quantity,
        rp.preferred_supplier_id,
        CONCAT('Auto reorder: stock below minimum threshold (', rp.min_stock_level, ')')
    FROM inventory_reorder_policy rp
    JOIN inventory i
      ON i.warehouse_id = rp.warehouse_id
     AND i.product_id = rp.product_id
    LEFT JOIN procurement_requests pr
      ON pr.warehouse_id = rp.warehouse_id
     AND pr.product_id = rp.product_id
     AND pr.status IN ('OPEN', 'APPROVED', 'ORDERED')
    WHERE i.quantity < rp.min_stock_level
      AND pr.id IS NULL;
END $$
DELIMITER ;

SELECT 'sp_generate_reorder_requests created successfully.' AS status;
