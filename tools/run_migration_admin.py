#!/usr/bin/env python3
"""
Yadvi Seeds — Secure Administrator Migration Runner
Location: tools/run_migration_admin.py

Connects to Cloud SQL Auth Proxy on 127.0.0.1:3307 as a DDL-authorized user
(e.g., 'yadvi_app_user' or 'root') using secure getpass (never echoes or stores credentials).
Executes only the 10 reviewed additive column migrations with full idempotency.
"""

import sys
import getpass
import mysql.connector

TARGET_HOST = "127.0.0.1"
TARGET_PORT = 3307
TARGET_DB = "yadvi_seeds_db"

MIGRATION_OPERATIONS = [
    {
        "table": "shop_owners",
        "column": "opening_stock_kg",
        "sql": "ALTER TABLE `shop_owners` ADD COLUMN `opening_stock_kg` DOUBLE NULL DEFAULT 0.0 AFTER `current_stock_bags`;"
    },
    {
        "table": "shop_owners",
        "column": "current_stock_kg",
        "sql": "ALTER TABLE `shop_owners` ADD COLUMN `current_stock_kg` DOUBLE NULL DEFAULT 0.0 AFTER `opening_stock_kg`;"
    },
    {
        "table": "products",
        "column": "available_stock_kg",
        "sql": "ALTER TABLE `products` ADD COLUMN `available_stock_kg` DOUBLE NULL DEFAULT NULL AFTER `available_stock_bags`;"
    },
    {
        "table": "inventory",
        "column": "total_kg",
        "sql": "ALTER TABLE `inventory` ADD COLUMN `total_kg` DOUBLE NULL DEFAULT 0.0 AFTER `reserved_bags`;"
    },
    {
        "table": "inventory",
        "column": "reserved_kg",
        "sql": "ALTER TABLE `inventory` ADD COLUMN `reserved_kg` DOUBLE NULL DEFAULT 0.0 AFTER `total_kg`;"
    },
    {
        "table": "orders",
        "column": "total_quantity_kg",
        "sql": "ALTER TABLE `orders` ADD COLUMN `total_quantity_kg` DOUBLE NULL DEFAULT NULL AFTER `total_quantity_bags`;"
    },
    {
        "table": "order_items",
        "column": "quantity",
        "sql": "ALTER TABLE `order_items` ADD COLUMN `quantity` DOUBLE NULL DEFAULT NULL AFTER `quantity_bags`;"
    },
    {
        "table": "order_items",
        "column": "unit",
        "sql": "ALTER TABLE `order_items` ADD COLUMN `unit` VARCHAR(10) COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL AFTER `quantity`;"
    },
    {
        "table": "visits",
        "column": "quantity_booked_kg",
        "sql": "ALTER TABLE `visits` ADD COLUMN `quantity_booked_kg` DOUBLE NULL DEFAULT 0.0 AFTER `bags_ordered`;"
    },
    {
        "table": "notifications",
        "column": "total_quantity_kg",
        "sql": "ALTER TABLE `notifications` ADD COLUMN `total_quantity_kg` DOUBLE NULL DEFAULT NULL AFTER `total_bags`;"
    }
]

def main():
    print("=" * 70)
    print("Yadvi Seeds: Secure Administrator Schema Migration Runner")
    print(f"Target Proxy: {TARGET_HOST}:{TARGET_PORT}")
    print(f"Target Database: {TARGET_DB}")
    print("=" * 70)

    # 1. Prompt for DBA username
    default_user = "yadvi_app_user"
    user_input = input(f"Enter MySQL DDL username [{default_user}]: ").strip()
    db_user = user_input if user_input else default_user

    # 2. Prompt for password securely with no echo
    try:
        db_password = getpass.getpass(f"Enter password for '{db_user}': ")
    except (KeyboardInterrupt, EOFError):
        print("\nOperation cancelled by user.")
        sys.exit(1)

    print(f"\nConnecting to Cloud SQL via proxy as '{db_user}'...")
    try:
        conn = mysql.connector.connect(
            host=TARGET_HOST,
            port=TARGET_PORT,
            user=db_user,
            password=db_password,
            database=TARGET_DB,
            connection_timeout=10
        )
    except mysql.connector.Error as err:
        print(f"Authentication/Connection Error: {err}")
        sys.exit(1)

    cursor = conn.cursor()

    # 3. Read-only privilege check on connected user
    cursor.execute("SHOW GRANTS FOR CURRENT_USER();")
    user_grants = [row[0] for row in cursor.fetchall()]
    print("\nVerified User Grants:")
    has_alter = False
    for g in user_grants:
        print(f"  {g}")
        if "ALL PRIVILEGES" in g.upper() or "ALTER" in g.upper():
            has_alter = True

    if not has_alter:
        print(f"\nERROR: Connected user '{db_user}' does not have ALTER privileges on {TARGET_DB}.")
        print("Halting migration immediately without executing any DDL. An authorized DBA account is required.")
        conn.close()
        sys.exit(1)

    print("\nPrivilege check passed: User is authorized for DDL.")

    # 4. Check existing columns in information_schema
    cursor.execute("""
        SELECT TABLE_NAME, COLUMN_NAME 
        FROM information_schema.COLUMNS 
        WHERE TABLE_SCHEMA = %s;
    """, (TARGET_DB,))
    existing_cols = {(row[0], row[1]) for row in cursor.fetchall()}

    executed_count = 0
    skipped_count = 0

    print("\nExecuting Reviewed DDL Operations:")
    for op in MIGRATION_OPERATIONS:
        tbl = op["table"]
        col = op["column"]
        sql = op["sql"]

        if (tbl, col) in existing_cols:
            print(f"  [SKIP] `{tbl}`.`{col}` already exists.")
            skipped_count += 1
        else:
            print(f"  [RUNNING] {sql}")
            cursor.execute(sql)
            conn.commit()
            print(f"  [SUCCESS] Added `{tbl}`.`{col}`.")
            executed_count += 1

    print("\n" + "=" * 70)
    print(f"Migration Complete: {executed_count} columns added, {skipped_count} skipped.")
    print("=" * 70)

    cursor.close()
    conn.close()

if __name__ == "__main__":
    main()
