# Supply Chain Management Database

This repository contains a MySQL-based supply chain management database for managing products, suppliers, warehouses, inventory, orders, replenishment rules, and audit history. The project was built as an advanced databases submission and focuses on a normalized relational design, transactional business logic, and reporting queries.

# Features
The database includes the following features:

Supplier and product management: Stores supplier data, product catalogue data, and supplier-product relationships.

Warehouse and inventory management: Tracks stock by warehouse and product, including inventory movement auditing.

Order lifecycle management: Stores orders and line items with normalized order statuses and status history.

Replenishment support: Uses reorder policies and procurement requests to support low-stock workflows.

Business logic in SQL: Includes stored procedures for order creation, status changes, and inventory adjustment.

Reporting and analytics: Includes analytical SQL queries, views, and indexes for reporting.

Bulk seeding support: Includes CSV-based seed templates for scaling test data.

# Requirements
To use this project locally, you will need:

MySQL 8.x

A MySQL client such as MySQL Workbench

Permission to run SQL scripts and, if using CSV bulk load, `LOAD DATA LOCAL INFILE`


# Installation
To create the database locally, follow these steps:

Clone the repository to your local machine.

Open MySQL Workbench or another MySQL client and connect to your MySQL server.

Run the SQL files in the following order:

1. `00_database_setup.sql`
2. `01_schema.sql`
3. `02_insert_data.sql`
4. `06_business_logic_procedures (sp_)`
5. `07_triggers_and_audit.sql`
6. `08_performance_indexes_views.sql`
7. `validation_and_scenario_tests_.sql` 


# Usage
To use the supply chain management database, follow these steps:

Add your suppliers to the suppliers table. Add your products or raw materials to the products table. Create orders in the orders table and add line items through order_item. Track order progress using normalized statuses from order_statuses and review lifecycle changes in order_status_history. Record and monitor stock movements through inventory_transactions and generate replenishment actions through procurement_requests. Run analytical SQL queries, views, and reporting scripts to review inventory levels, order activity, supplier coverage, and operational performance.

# Bulk Seed Data
The project includes optional CSV-based bulk seeding for larger test datasets.

To use bulk seeding:

1. Update the file paths in `10_bulk_seed_from_csv_template.sql` so they point to your local `seed_data/` directory.
2. Save or run that updated script in MySQL Workbench.
3. Ensure `LOAD DATA LOCAL INFILE` is enabled on your MySQL server and client.

Notes:

`02_insert_data.sql` provides the base deterministic dataset.

`10_bulk_seed_from_csv_template.sql` is intended for larger-scale testing.

# Recommended Workflow
A simple workflow for local use is:

1. Create the database with `00_database_setup.sql`.
2. Build the schema with `01_schema.sql`.
3. Insert base data with `02_insert_data.sql`.
4. Load procedures, triggers, views, and indexes.
5. Run `test_queries.sql` to confirm that the project works as expected.
6. Optionally load larger CSV seed data for more extensive testing.

# Notes
This project is designed for MySQL and uses MySQL-specific features such as triggers, stored procedures, and `LOAD DATA LOCAL INFILE`.

