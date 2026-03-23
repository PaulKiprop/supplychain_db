-- =============================================================
-- Procedure: sp_create_order
-- =============================================================

USE supply_chain_db;

-- Creates a new order with an initial PENDING status.
DROP PROCEDURE IF EXISTS sp_create_order;
DELIMITER $$
CREATE PROCEDURE sp_create_order (
    IN p_order_number VARCHAR(100),
    IN p_warehouse_id BIGINT,
    IN p_expected_delivery_date DATETIME,
    IN p_notes TEXT
)
BEGIN
    IF EXISTS (SELECT 1 FROM orders WHERE order_number = p_order_number) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order number already exists.';
    END IF;

    INSERT INTO orders (
        order_number,
        status_code,
        warehouse_id,
        expected_delivery_date,
        notes
    )
    VALUES (
        p_order_number,
        'PENDING',
        p_warehouse_id,
        p_expected_delivery_date,
        p_notes
    );
END $$
DELIMITER ;

SELECT 'sp_create_order created successfully.' AS status;
