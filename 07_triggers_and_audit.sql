-- =============================================================
-- Supply Chain Management System - Triggers and Audit
-- =============================================================

USE supply_chain_db;

-- Central audit table for every inventory quantity movement.
CREATE TABLE IF NOT EXISTS inventory_transactions (
    id              BIGINT       NOT NULL AUTO_INCREMENT,
    warehouse_id    BIGINT       NOT NULL,
    product_id      BIGINT       NOT NULL,
    movement_type   ENUM('INBOUND','OUTBOUND','ADJUSTMENT') NOT NULL,
    quantity_change INT          NOT NULL,
    quantity_before INT          NOT NULL,
    quantity_after  INT          NOT NULL,
    reference_type  VARCHAR(50),
    reference_id    VARCHAR(100),
    reason          VARCHAR(255),
    changed_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_inv_tx_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses (id),
    CONSTRAINT fk_inv_tx_product FOREIGN KEY (product_id) REFERENCES products (id)
);

DROP TRIGGER IF EXISTS trg_order_item_before_insert;
DELIMITER $$
-- Validates line input and derives line_total automatically on insert.
CREATE TRIGGER trg_order_item_before_insert
BEFORE INSERT ON order_item
FOR EACH ROW
BEGIN
    IF NEW.quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order item quantity must be greater than zero.';
    END IF;

    IF NEW.unit_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order item unit price cannot be negative.';
    END IF;

    SET NEW.line_total = NEW.quantity * NEW.unit_price;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_order_item_before_update;
DELIMITER $$
-- Re-validates and recalculates line_total when order lines are edited.
CREATE TRIGGER trg_order_item_before_update
BEFORE UPDATE ON order_item
FOR EACH ROW
BEGIN
    IF NEW.quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order item quantity must be greater than zero.';
    END IF;

    IF NEW.unit_price < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Order item unit price cannot be negative.';
    END IF;

    SET NEW.line_total = NEW.quantity * NEW.unit_price;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_orders_before_update;
DELIMITER $$
-- Auto-stamps delivered_at the first time an order reaches DELIVERED.
CREATE TRIGGER trg_orders_before_update
BEFORE UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.status_code <> OLD.status_code AND NEW.status_code = 'DELIVERED' AND NEW.delivered_at IS NULL THEN
        SET NEW.delivered_at = NOW();
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_orders_after_update;
DELIMITER $$
-- Appends one lifecycle history row whenever status_code changes.
CREATE TRIGGER trg_orders_after_update
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.status_code <> OLD.status_code THEN
        INSERT INTO order_status_history (
            order_id,
            from_status_code,
            to_status_code,
            comment,
            changed_by
        ) VALUES (
            NEW.id,
            OLD.status_code,
            NEW.status_code,
            COALESCE(@audit_comment, 'Status change captured by trigger'),
            COALESCE(@audit_changed_by, 'SYSTEM')
        );

        -- Clear session variables so they do not leak into unrelated updates.
        SET @audit_comment = NULL;
        SET @audit_changed_by = NULL;
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_orders_after_insert;
DELIMITER $$
-- Writes initial status event for newly created orders.
CREATE TRIGGER trg_orders_after_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    INSERT INTO order_status_history (
        order_id,
        from_status_code,
        to_status_code,
        comment,
        changed_by
    ) VALUES (
        NEW.id,
        NULL,
        NEW.status_code,
        'Initial order status',
        'SYSTEM'
    );
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_inventory_before_update;
DELIMITER $$
-- Blocks any update that would move stock below zero.
CREATE TRIGGER trg_inventory_before_update
BEFORE UPDATE ON inventory
FOR EACH ROW
BEGIN
    IF NEW.quantity < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Inventory quantity cannot be negative.';
    END IF;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_inventory_after_insert;
DELIMITER $$
-- Logs initial stock creation as an INBOUND movement.
CREATE TRIGGER trg_inventory_after_insert
AFTER INSERT ON inventory
FOR EACH ROW
BEGIN
    INSERT INTO inventory_transactions (
        warehouse_id,
        product_id,
        movement_type,
        quantity_change,
        quantity_before,
        quantity_after,
        reference_type,
        reference_id,
        reason
    ) VALUES (
        NEW.warehouse_id,
        NEW.product_id,
        'INBOUND',
        NEW.quantity,
        0,
        NEW.quantity,
        COALESCE(@inv_ref_type, 'MANUAL'),
        @inv_ref_id,
        COALESCE(@inv_reason, 'Initial inventory insert')
    );

    -- Clear per-session context after audit row is written.
    SET @inv_reason = NULL;
    SET @inv_ref_type = NULL;
    SET @inv_ref_id = NULL;
END $$
DELIMITER ;

DROP TRIGGER IF EXISTS trg_inventory_after_update;
DELIMITER $$
-- Logs stock deltas as INBOUND/OUTBOUND movements.
CREATE TRIGGER trg_inventory_after_update
AFTER UPDATE ON inventory
FOR EACH ROW
BEGIN
    DECLARE v_delta INT;

    SET v_delta = NEW.quantity - OLD.quantity;

    IF v_delta <> 0 THEN
        INSERT INTO inventory_transactions (
            warehouse_id,
            product_id,
            movement_type,
            quantity_change,
            quantity_before,
            quantity_after,
            reference_type,
            reference_id,
            reason
        ) VALUES (
            NEW.warehouse_id,
            NEW.product_id,
            CASE
                WHEN v_delta > 0 THEN 'INBOUND'
                ELSE 'OUTBOUND'
            END,
            v_delta,
            OLD.quantity,
            NEW.quantity,
            COALESCE(@inv_ref_type, 'MANUAL'),
            @inv_ref_id,
            COALESCE(@inv_reason, 'Inventory change captured by trigger')
        );

        -- Reset context variables for the next transaction scope.
        SET @inv_reason = NULL;
        SET @inv_ref_type = NULL;
        SET @inv_ref_id = NULL;
    END IF;
END $$
DELIMITER ;

