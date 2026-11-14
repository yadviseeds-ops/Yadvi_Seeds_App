#!/usr/bin/env python3
"""
Yadvi Seeds — Schema Migration: Make Obsolete 'dealer_code' Nullable
Location: tools/migrate_dealer_code_nullable.py

Prepares and executes the safe, non-destructive migration on Cloud SQL:
  ALTER TABLE `shop_owners` MODIFY COLUMN `dealer_code` VARCHAR(50) COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL;

Safety Guarantees:
- Does NOT drop the column (non-destructive).
- Preserves all existing Shop Owner records and existing dealer codes.
- Compatible with existing UNIQUE constraint in MySQL (InnoDB permits multiple NULLs).
- Eliminates MySQL Error 1364: Field 'dealer_code' doesn't have a default value.
- Performs pre-checks and post-checks via information_schema.
"""

import sys
import subprocess
import mysql.connector

TARGET_HOST = "127.0.0.1"
TARGET_PORT = 3307
TARGET_DB = "yadvi_seeds_db"
TARGET_USER = "root"

def get_secret_password() -> str:
    cmd = [
        "gcloud.cmd", "secrets", "versions", "access", "latest",
        "--secret=yadvi-db-password",
        "--project=yadvi-seed-app-5f306"
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True, shell=True)
    return res.stdout.strip()

def run_migration(dry_run=True):
    print("=" * 70)
    print("YADVI SEEDS: MAKE 'dealer_code' NULLABLE SCHEMA MIGRATION")
    print(f"Target: {TARGET_HOST}:{TARGET_PORT} | DB: {TARGET_DB} | User: {TARGET_USER}")
    print(f"Mode: {'DRY RUN (READ ONLY)' if dry_run else 'LIVE EXECUTION'}")
    print("=" * 70)

    try:
        db_password = get_secret_password()
    except Exception as e:
        print(f"ERROR: Could not retrieve DB secret: {e}")
        sys.exit(1)

    try:
        conn = mysql.connector.connect(
            host=TARGET_HOST,
            port=TARGET_PORT,
            user=TARGET_USER,
            password=db_password,
            database=TARGET_DB,
            connection_timeout=10
        )
    except Exception as err:
        print(f"Connection failed: {err}")
        sys.exit(1)

    cur = conn.cursor(dictionary=True)

    try:
        # 1. Inspect current column definition
        cur.execute("""
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_TYPE
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = %s AND TABLE_NAME = 'shop_owners' AND COLUMN_NAME = 'dealer_code';
        """, (TARGET_DB,))
        col_info = cur.fetchone()

        if not col_info:
            print("[INFO] 'dealer_code' column does not exist in 'shop_owners' table. No migration needed.")
            return

        print("\nCurrent Column Definition in Cloud SQL:")
        print(f"  Column: {col_info['COLUMN_NAME']}")
        print(f"  Type: {col_info['COLUMN_TYPE']}")
        print(f"  Is Nullable: {col_info['IS_NULLABLE']}")
        print(f"  Default Value: {col_info['COLUMN_DEFAULT']}")

        # 2. Count existing records
        cur.execute("SELECT COUNT(*) as cnt FROM shop_owners;")
        total_shops = cur.fetchone()['cnt']
        print(f"\nExisting Shop Owner Records: {total_shops} (all will be preserved)")

        if col_info['IS_NULLABLE'] == 'YES':
            print("\n[SKIP] 'dealer_code' is ALREADY nullable with DEFAULT NULL. No action needed.")
            return

        ddl = "ALTER TABLE `shop_owners` MODIFY COLUMN `dealer_code` VARCHAR(50) COLLATE utf8mb4_unicode_ci NULL DEFAULT NULL;"

        if dry_run:
            print(f"\n[DRY RUN] Reviewed DDL statement to execute upon approval:\n  {ddl}")
            print("\nDry run completed successfully. Zero changes were made to the database.")
            return

        print(f"\n[EXECUTING DDL] {ddl}")
        cur.execute(ddl)
        conn.commit()
        print("  [SUCCESS] DDL executed successfully.")

        # 3. Post-migration verification
        cur.execute("""
            SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_TYPE
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = %s AND TABLE_NAME = 'shop_owners' AND COLUMN_NAME = 'dealer_code';
        """, (TARGET_DB,))
        updated_col = cur.fetchone()
        print("\nUpdated Column Definition:")
        print(f"  Is Nullable: {updated_col['IS_NULLABLE']}")
        print(f"  Default: {updated_col['COLUMN_DEFAULT']}")

        assert updated_col['IS_NULLABLE'] == 'YES', "Column must now be nullable"
        print("\nMigration verified successfully!")

    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    is_live = "--execute" in sys.argv
    run_migration(dry_run=not is_live)
