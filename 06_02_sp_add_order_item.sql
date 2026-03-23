-- =============================================================
-- Procedure: sp_add_order_item
-- =============================================================

USE supply_chain_db;

-- Adds an item to an order, validates stock, and reserves inventory.
DROP PROCEDURE IF EXISTS sp_add_order_item;
DELIMITER $$
CREATE PROCEDURE sp_add_order_item (
    IN p_order_number VARCHAR(100),
    IN p_product_id BIGINT,
    IN p_quantity INT,
    IN p_unit_price DECIMAL(12,2)
)
BEGIN
    DECLARE v_order_id BIGINT;
    DECLARE v_warehouse_id BIGINT;
    DECLARE v_status_code VARCHAR(20);
    DECLARE v_available_qty INT;
    DECLARE v_effective_price DECIMAL(12,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be greater than zero.';
    END IF;

    START TRANSACTION;

    SELECT id, warehouse_id, status_code
    INTO v_order_id, v_warehouse_id, v_status_code
    FROM orders
    WHERE order_number = p_order_number
    LIMIT 1
    FOR UPDATE;

    IF v_order_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order not found.';
    END IF;

    IF v_status_code IN ('CANCELLED', 'DELIVERED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot add items to a terminal order status.';
    END IF;

    IF p_unit_price IS NULL THEN
        SELECT price INTO v_effective_price
        FROM products
        WHERE id = p_product_id;
    ELSE
        SET v_effective_price = p_unit_price;
    END IF;

    IF v_effective_price IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Product not found or invalid price.';
    END IF;

    SELECT quantity INTO v_available_qty
    FROM inventory
    WHERE warehouse_id = v_warehouse_id
      AND product_id = p_product_id
    LIMIT 1
    FOR UPDATE;

    IF v_available_qty IS NULL OR v_available_qty < p_quantity THEN
        INSERT INTO procurement_requests (
            warehouse_id,
            product_id,
            requested_qty,
            supplier_id,
            reason
        )
        SELECT
            v_warehouse_id,
            p_product_id,
            GREATEST(COALESCE(rp.reorder_quantity, p_quantity), p_quantity),
            rp.preferred_supplier_id,
            CONCAT(
                'Auto request: insufficient stock for order ',
                p_order_number,
                ' (needed ', p_quantity,
                ', available ', COALESCE(v_available_qty, 0),
                ')'
            )
        FROM (SELECT 1) x
        LEFT JOIN inventory_reorder_policy rp
          ON rp.warehouse_id = v_warehouse_id
         AND rp.product_id = p_product_id
        LEFT JOIN procurement_requests pr
          ON pr.warehouse_id = v_warehouse_id
         AND pr.product_id = p_product_id
         AND pr.status IN ('OPEN', 'APPROVED', 'ORDERED')
        WHERE pr.id IS NULL;

        COMMIT;

        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient stock in warehouse. Procurement request created or already open.';
    END IF;

    INSERT INTO order_item (
        order_id,
        product_id,
        quantity,
        unit_price,
        line_total
    ) VALUES (
        v_order_id,
        p_product_id,
        p_quantity,
        v_effective_price,
        p_quantity * v_effective_price
    );

    SET @inv_reason = CONCAT('Stock reserved for order ', p_order_number);
    SET @inv_ref_type = 'ORDER';
    SET @inv_ref_id = CONCAT(p_order_number, '|PRD:', p_product_id);

    UPDATE inventory
    SET quantity = quantity - p_quantity
    WHERE warehouse_id = v_warehouse_id
      AND product_id = p_product_id;

    COMMIT;
END $$
DELIMITER ;

SELECT 'sp_add_order_item created successfully.' AS status;
