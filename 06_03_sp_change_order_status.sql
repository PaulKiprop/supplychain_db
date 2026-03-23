-- =============================================================
-- Procedure: sp_change_order_status
-- =============================================================

USE supply_chain_db;

-- Changes order status while enforcing allowed lifecycle transitions.
DROP PROCEDURE IF EXISTS sp_change_order_status;
DELIMITER $$
CREATE PROCEDURE sp_change_order_status (
    IN p_order_number VARCHAR(100),
    IN p_new_status_code VARCHAR(20),
    IN p_comment TEXT,
    IN p_changed_by VARCHAR(100)
)
BEGIN
    DECLARE v_order_id BIGINT;
    DECLARE v_current_status_code VARCHAR(20);

    SELECT id, status_code
    INTO v_order_id, v_current_status_code
    FROM orders
    WHERE order_number = p_order_number
    LIMIT 1;

    IF v_order_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order not found.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM order_statuses WHERE status_code = p_new_status_code) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid target status.';
    END IF;

    IF v_current_status_code = p_new_status_code THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order is already in this status.';
    END IF;

    IF v_current_status_code = 'PENDING'   AND p_new_status_code NOT IN ('CONFIRMED', 'CANCELLED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid transition from PENDING.';
    END IF;

    IF v_current_status_code = 'CONFIRMED' AND p_new_status_code NOT IN ('PICKING', 'CANCELLED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid transition from CONFIRMED.';
    END IF;

    IF v_current_status_code = 'PICKING'   AND p_new_status_code <> 'SHIPPED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid transition from PICKING.';
    END IF;

    IF v_current_status_code = 'SHIPPED'   AND p_new_status_code <> 'DELIVERED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid transition from SHIPPED.';
    END IF;

    IF v_current_status_code IN ('DELIVERED', 'CANCELLED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Terminal status cannot transition.';
    END IF;

    SET @audit_comment = COALESCE(p_comment, 'Status updated by procedure');
    SET @audit_changed_by = COALESCE(p_changed_by, 'SYSTEM');

    UPDATE orders
    SET delivered_at = CASE
            WHEN p_new_status_code = 'DELIVERED' AND delivered_at IS NULL THEN NOW()
            ELSE delivered_at
        END,
        status_code = p_new_status_code
    WHERE id = v_order_id;
END $$
DELIMITER ;

SELECT 'sp_change_order_status created successfully.' AS status;
