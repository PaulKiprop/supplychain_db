-- =============================================================
-- Supply Chain Management System -  Final Normalised schema
-- =============================================================

USE supply_chain_db;

CREATE TABLE IF NOT EXISTS suppliers (
    id         BIGINT       NOT NULL AUTO_INCREMENT,
    name       VARCHAR(255) NOT NULL,
    email      VARCHAR(255) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT uq_supplier_email UNIQUE (email)
);

CREATE TABLE IF NOT EXISTS products (
    id          BIGINT        NOT NULL AUTO_INCREMENT,
    name        VARCHAR(255)  NOT NULL,
    sku         VARCHAR(100)  NOT NULL,
    description TEXT,
    price       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uq_product_sku UNIQUE (sku),
    CONSTRAINT chk_products_price_nonnegative CHECK (price >= 0)
);

CREATE TABLE IF NOT EXISTS product_suppliers (
    product_id  BIGINT NOT NULL,
    supplier_id BIGINT NOT NULL,
    PRIMARY KEY (product_id, supplier_id),
    CONSTRAINT fk_ps_product  FOREIGN KEY (product_id)  REFERENCES products  (id) ON DELETE CASCADE,
    CONSTRAINT fk_ps_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS warehouses (
    id       BIGINT       NOT NULL AUTO_INCREMENT,
    name     VARCHAR(255) NOT NULL,
    location VARCHAR(255) NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE IF NOT EXISTS order_statuses (
    status_code  VARCHAR(20) NOT NULL,
    status_label VARCHAR(50) NOT NULL,
    sort_order   INT         NOT NULL,
    is_terminal  TINYINT(1)  NOT NULL DEFAULT 0,
    PRIMARY KEY (status_code),
    CONSTRAINT uq_order_statuses_label UNIQUE (status_label),
    CONSTRAINT uq_order_statuses_sort UNIQUE (sort_order)
);

CREATE TABLE IF NOT EXISTS inventory (
    id           BIGINT NOT NULL AUTO_INCREMENT,
    warehouse_id BIGINT NOT NULL,
    product_id   BIGINT NOT NULL,
    quantity     INT    NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    CONSTRAINT uq_inventory_wh_prod UNIQUE (warehouse_id, product_id),
    CONSTRAINT fk_inv_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses (id) ON DELETE CASCADE,
    CONSTRAINT fk_inv_product   FOREIGN KEY (product_id)   REFERENCES products   (id) ON DELETE CASCADE,
    CONSTRAINT chk_inventory_quantity_nonnegative CHECK (quantity >= 0)
);

CREATE TABLE IF NOT EXISTS orders (
    id                     BIGINT       NOT NULL AUTO_INCREMENT,
    order_number           VARCHAR(100) NOT NULL,
    status_code            VARCHAR(20)  NOT NULL,
    warehouse_id           BIGINT       NOT NULL,
    created_at             DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at             DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    expected_delivery_date DATETIME,
    delivered_at           DATETIME,
    notes                  TEXT,
    PRIMARY KEY (id),
    CONSTRAINT uq_order_number UNIQUE (order_number),
    CONSTRAINT fk_order_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses (id),
    CONSTRAINT fk_orders_status_code FOREIGN KEY (status_code) REFERENCES order_statuses (status_code)
);

CREATE TABLE IF NOT EXISTS order_item (
    id         BIGINT        NOT NULL AUTO_INCREMENT,
    order_id   BIGINT        NOT NULL,
    product_id BIGINT        NOT NULL,
    quantity   INT           NOT NULL,
    unit_price DECIMAL(12,2) NOT NULL,
    line_total DECIMAL(14,2) NOT NULL,
    PRIMARY KEY (id),
    CONSTRAINT fk_oi_order   FOREIGN KEY (order_id)   REFERENCES orders   (id) ON DELETE CASCADE,
    CONSTRAINT fk_oi_product FOREIGN KEY (product_id) REFERENCES products (id),
    CONSTRAINT chk_order_item_quantity_positive CHECK (quantity > 0),
    CONSTRAINT chk_order_item_unit_price_nonnegative CHECK (unit_price >= 0),
    CONSTRAINT chk_order_item_line_total_nonnegative CHECK (line_total >= 0)
);

CREATE TABLE IF NOT EXISTS order_status_history (
    id               BIGINT      NOT NULL AUTO_INCREMENT,
    order_id         BIGINT      NOT NULL,
    from_status_code VARCHAR(20),
    to_status_code   VARCHAR(20) NOT NULL,
    changed_at       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comment          TEXT,
    changed_by       VARCHAR(100),
    PRIMARY KEY (id),
    CONSTRAINT fk_osh_order FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
    CONSTRAINT fk_osh_from_status_code FOREIGN KEY (from_status_code) REFERENCES order_statuses (status_code),
    CONSTRAINT fk_osh_to_status_code FOREIGN KEY (to_status_code) REFERENCES order_statuses (status_code)
);

CREATE TABLE IF NOT EXISTS inventory_reorder_policy (
    id                    BIGINT   NOT NULL AUTO_INCREMENT,
    warehouse_id          BIGINT   NOT NULL,
    product_id            BIGINT   NOT NULL,
    min_stock_level       INT      NOT NULL,
    reorder_quantity      INT      NOT NULL,
    preferred_supplier_id BIGINT,
    lead_time_days        INT      NOT NULL DEFAULT 7,
    updated_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT uq_reorder_policy_wh_prod UNIQUE (warehouse_id, product_id),
    CONSTRAINT fk_reorder_policy_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses (id) ON DELETE CASCADE,
    CONSTRAINT fk_reorder_policy_product FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE CASCADE,
    CONSTRAINT fk_reorder_policy_supplier FOREIGN KEY (preferred_supplier_id) REFERENCES suppliers (id),
    CONSTRAINT chk_reorder_policy_min_nonnegative CHECK (min_stock_level >= 0),
    CONSTRAINT chk_reorder_policy_qty_positive CHECK (reorder_quantity > 0),
    CONSTRAINT chk_reorder_policy_lead_time_positive CHECK (lead_time_days > 0)
);

CREATE TABLE IF NOT EXISTS procurement_requests (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    warehouse_id  BIGINT       NOT NULL,
    product_id    BIGINT       NOT NULL,
    requested_qty INT          NOT NULL,
    supplier_id   BIGINT,
    status        ENUM('OPEN','APPROVED','ORDERED','RECEIVED','CANCELLED') NOT NULL DEFAULT 'OPEN',
    reason        VARCHAR(255) NOT NULL,
    requested_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fulfilled_at  DATETIME,
    PRIMARY KEY (id),
    CONSTRAINT fk_proc_req_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouses (id),
    CONSTRAINT fk_proc_req_product FOREIGN KEY (product_id) REFERENCES products (id),
    CONSTRAINT fk_proc_req_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
    CONSTRAINT chk_proc_req_qty_positive CHECK (requested_qty > 0)
);

SHOW TABLES;
