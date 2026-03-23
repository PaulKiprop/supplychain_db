-- =============================================================
-- Supply Chain Management System - Stored Procedures (Master)
-- =============================================================
-- Procedures are split into individual files for easier maintenance.
-- Execute the files below in this order:
-- 06_01_sp_create_order.sql
-- 06_02_sp_add_order_item.sql
-- 06_03_sp_change_order_status.sql
-- 06_04_sp_apply_inventory_adjustment.sql
-- 06_05_sp_generate_reorder_requests.sql

USE supply_chain_db;

-- Optional mysql CLI execution helpers:
-- SOURCE 06_01_sp_create_order.sql;
-- SOURCE 06_02_sp_add_order_item.sql;
-- SOURCE 06_03_sp_change_order_status.sql;
-- SOURCE 06_04_sp_apply_inventory_adjustment.sql;
-- SOURCE 06_05_sp_generate_reorder_requests.sql;

SELECT '06_business_logic_procedures.sql: run the split procedure files listed above.' AS status;
