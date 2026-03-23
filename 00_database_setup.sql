-- =============================================================
-- Supply Chain Management System - setup
-- =============================================================
CREATE DATABASE IF NOT EXISTS supply_chain_db
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE supply_chain_db;

Show variables like 'local_infile';
Set global local_infile = 1;
