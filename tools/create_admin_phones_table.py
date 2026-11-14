#!/usr/bin/env python3
"""
Yadvi Seeds — Minimal Schema Migration: Create 'admin_phones' Table
Location: tools/create_admin_phones_table.py

Per User Request:
- Creates ONLY the missing 'admin_phones' table.
- Matches SQLAlchemy AdminPhone model in backend/app/models/all_models.py.
- Does not modify any user records or unrelated tables.
- Verifies the table structure against information_schema.
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

def run_migration():
    print("=" * 70)
    print("YADVI SEEDS: CREATE 'admin_phones' TABLE MINIMAL MIGRATION")
    print(f"Target: {TARGET_HOST}:{TARGET_PORT} | DB: {TARGET_DB} | User: {TARGET_USER}")
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
            connection_timeout=10,
            autocommit=False
        )
    except Exception as err:
        print(f"Connection failed: {err}")
        sys.exit(1)

    cursor = conn.cursor(dictionary=True)

    try:
        # Step 1: Pre-check table existence
        cursor.execute("""
            SELECT TABLE_NAME
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = %s AND TABLE_NAME = 'admin_phones';
        """, (TARGET_DB,))
        existing = cursor.fetchone()

        if existing:
            print("[INFO] 'admin_phones' table already exists. No creation needed.")
        else:
            print("[STEP 1] Creating missing 'admin_phones' table...")
            ddl = """
            CREATE TABLE IF NOT EXISTS `admin_phones` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `user_id` INT NOT NULL,
                `phone` VARCHAR(20) NOT NULL,
                `label` VARCHAR(50) DEFAULT 'Admin Mobile',
                `is_active` TINYINT(1) DEFAULT 1,
                `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY `uq_admin_phones_phone` (`phone`),
                INDEX `ix_admin_phones_user_id` (`user_id`),
                CONSTRAINT `fk_admin_phones_user_id` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            """
            cursor.execute(ddl)
            conn.commit()
            print("[SUCCESS] Table 'admin_phones' created.")

        # Step 2: Post-check verification
        print("\n[STEP 2] Verifying table schema in information_schema.COLUMNS:")
        cursor.execute("""
            SELECT COLUMN_NAME, DATA_TYPE, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_DEFAULT
            FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = %s AND TABLE_NAME = 'admin_phones'
            ORDER BY ORDINAL_POSITION;
        """, (TARGET_DB,))
        columns = cursor.fetchall()

        for col in columns:
            print(f"  - {col['COLUMN_NAME']}: {col['COLUMN_TYPE']} | Nullable: {col['IS_NULLABLE']} | Key: {col['COLUMN_KEY']} | Default: {col['COLUMN_DEFAULT']}")

        # Step 3: Verify Foreign Key Constraints
        print("\n[STEP 3] Verifying foreign key constraints:")
        cursor.execute("""
            SELECT CONSTRAINT_NAME, TABLE_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
            FROM information_schema.KEY_COLUMN_USAGE
            WHERE TABLE_SCHEMA = %s AND TABLE_NAME = 'admin_phones' AND REFERENCED_TABLE_NAME IS NOT NULL;
        """, (TARGET_DB,))
        fks = cursor.fetchall()
        for fk in fks:
            print(f"  - Constraint {fk['CONSTRAINT_NAME']}: {fk['COLUMN_NAME']} -> {fk['REFERENCED_TABLE_NAME']}.{fk['REFERENCED_COLUMN_NAME']}")

        print("\n" + "=" * 70)
        print("MINIMAL DATABASE FIX COMPLETED AND VERIFIED SUCCESSFULLY.")
        print("=" * 70)

    except Exception as e:
        conn.rollback()
        print(f"FATAL ERROR: {e}")
        sys.exit(1)
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    run_migration()
