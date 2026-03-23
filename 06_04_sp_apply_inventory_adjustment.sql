-- =============================================================
-- Procedure: sp_apply_inventory_adjustment
-- =============================================================

USE supply_chain_db;

-- Applies a positive or negative inventory adjustment atomically.
DROP PROCEDURE IF EXISTS sp_apply_inventory_adjustment;
DELIMITER $$
CREATE PROCEDURE sp_apply_inventory_adjustment (
    IN p_warehouse_id BIGINT,
    IN p_product_id BIGINT,
    IN p_delta_qty INT,
    IN p_reason VARCHAR(255)
)
BEGIN
    DECLARE v_current_qty INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT quantity INTO v_current_qty
    FROM inventory
    WHERE warehouse_id = p_warehouse_id
      AND product_id = p_product_id
    LIMIT 1
    FOR UPDATE;

    SET @inv_reason = COALESCE(p_reason, 'Inventory adjusted via procedure');
    SET @inv_ref_type = 'PROCEDURE';
    SET @inv_ref_id = CONCAT('WH:', p_warehouse_id, '|PRD:', p_product_id);

    IF v_current_qty IS NULL THEN
        IF p_delta_qty < 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot reduce stock for non-existing inventory row.';
        END IF;

        INSERT INTO inventory (warehouse_id, product_id, quantity)
        VALUES (p_warehouse_id, p_product_id, p_delta_qty);
    ELSE
        IF (v_current_qty + p_delta_qty) < 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory cannot go below zero.';
        END IF;

        UPDATE inventory
        SET quantity = quantity + p_delta_qty
        WHERE warehouse_id = p_warehouse_id
          AND product_id = p_product_id;
    END IF;

    COMMIT;
END $$
DELIMITER ;

SELECT 'sp_apply_inventory_adjustment created successfully.' AS status;
