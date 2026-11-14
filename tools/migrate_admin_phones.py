#!/usr/bin/env python3
"""
Yadvi Seeds — Multi-Admin Phone Number Safe Migration Script
Target: Cloud SQL 'yadvi_seeds_db' via local proxy on 127.0.0.1:3307
"""

import sys
import subprocess
import mysql.connector
from mysql.connector import errorcode

TARGET_HOST = "127.0.0.1"
TARGET_PORT = 3307
TARGET_DB = "yadvi_seeds_db"
TARGET_USER = "root"
PRIMARY_ADMIN_ID = 1
PRIMARY_ADMIN_USERNAME = "ADMIN"
PRIMARY_PHONE = "9529403798"
SECONDARY_PHONE = "8080259924"

def get_secret_password() -> str:
    """Fetches the database password directly from Secret Manager without echoing or storing."""
    cmd = [
        "gcloud.cmd", "secrets", "versions", "access", "latest",
        "--secret=yadvi-db-password",
        "--project=yadvi-seed-app-5f306"
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True, shell=True)
    return res.stdout.strip()

def run_migration():
    print("=" * 70)
    print("YADVI SEEDS — MULTI-ADMIN PHONE NUMBER SAFE MIGRATION")
    print(f"Target: {TARGET_HOST}:{TARGET_PORT} | DB: {TARGET_DB} | User: {TARGET_USER}")
    print("=" * 70)

    try:
        db_password = get_secret_password()
    except Exception as e:
        print(f"ERROR: Failed to retrieve secret 'yadvi-db-password': {e}")
        sys.exit(1)

    print("\n[STEP 1] Connecting to Cloud SQL via proxy...")
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
    except mysql.connector.Error as err:
        print(f"FATAL: Database connection failed: {err}")
        sys.exit(1)

    cursor = conn.cursor(dictionary=True)

    try:
        # =====================================================================
        # SAFETY GATE A: PRE-MIGRATION VERIFICATIONS
        # =====================================================================
        print("\n[STEP 2: GATE A] Verifying primary Admin account in 'users' table...")
        cursor.execute("""
            SELECT u.id, u.username, u.phone, u.is_active, r.name as role_name
            FROM users u
            JOIN roles r ON u.role_id = r.id
            WHERE u.id = %s;
        """, (PRIMARY_ADMIN_ID,))
        admin_row = cursor.fetchone()

        if not admin_row:
            print(f"ABORT: User ID {PRIMARY_ADMIN_ID} not found!")
            sys.exit(1)

        print(f"  Found Admin: ID={admin_row['id']}, username='{admin_row['username']}', "
              f"phone='{admin_row['phone']}', is_active={admin_row['is_active']}, role='{admin_row['role_name']}'")

        if admin_row['username'] != PRIMARY_ADMIN_USERNAME:
            print(f"ABORT: Admin username mismatch: expected '{PRIMARY_ADMIN_USERNAME}', got '{admin_row['username']}'")
            sys.exit(1)

        if str(admin_row['phone']).strip() != PRIMARY_PHONE:
            print(f"ABORT: Admin phone mismatch: expected '{PRIMARY_PHONE}', got '{admin_row['phone']}'")
            sys.exit(1)

        if not admin_row['is_active']:
            print("ABORT: Admin account is inactive!")
            sys.exit(1)

        if admin_row['role_name'] != "administrator":
            print(f"ABORT: Admin role mismatch: expected 'administrator', got '{admin_row['role_name']}'")
            sys.exit(1)

        print("  [GATE A PASS] Primary Admin row verified successfully.")

        # Check secondary phone conflict across users table
        candidates = [SECONDARY_PHONE, f"+91{SECONDARY_PHONE}", f"91{SECONDARY_PHONE}", f"0{SECONDARY_PHONE}"]
        format_strings = ','.join(['%s'] * len(candidates))
        cursor.execute(f"""
            SELECT id, username, phone, is_active
            FROM users
            WHERE phone IN ({format_strings});
        """, tuple(candidates))
        conflicts = cursor.fetchall()

        if conflicts:
            print(f"ABORT: Secondary phone {SECONDARY_PHONE} is already registered to user(s): {conflicts}")
            sys.exit(1)
        print(f"  [GATE A PASS] Secondary phone {SECONDARY_PHONE} has 0 conflicts in 'users' table.")

        # Check if admin_phones table exists
        cursor.execute("""
            SELECT TABLE_NAME
            FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = %s AND TABLE_NAME = 'admin_phones';
        """, (TARGET_DB,))
        table_exists = cursor.fetchone() is not None

        if table_exists:
            print("  [INFO] 'admin_phones' table already exists. Inspecting schema...")
            cursor.execute("""
                SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_KEY
                FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = %s AND TABLE_NAME = 'admin_phones';
            """, (TARGET_DB,))
            cols = cursor.fetchall()
            for col in cols:
                print(f"    - {col['COLUMN_NAME']}: {col['DATA_TYPE']} (nullable: {col['IS_NULLABLE']}, key: {col['COLUMN_KEY']})")

            # Check if secondary phone already exists in admin_phones
            cursor.execute("""
                SELECT id, user_id, phone, is_active
                FROM admin_phones
                WHERE phone IN ({});
            """.format(format_strings), tuple(candidates))
            existing_admin_phone = cursor.fetchall()
            if existing_admin_phone:
                for ep in existing_admin_phone:
                    if ep['user_id'] != PRIMARY_ADMIN_ID:
                        print(f"ABORT: Phone {SECONDARY_PHONE} already exists in admin_phones mapped to DIFFERENT user_id {ep['user_id']}!")
                        sys.exit(1)
                    print(f"  [INFO] Phone {SECONDARY_PHONE} already mapped to user_id {PRIMARY_ADMIN_ID} (is_active={ep['is_active']}).")
        else:
            print("  [INFO] 'admin_phones' table does NOT exist yet.")

        # =====================================================================
        # SAFETY GATE C: SCHEMA AND DATA MIGRATION
        # =====================================================================
        if not table_exists:
            print("\n[STEP 3: GATE C] Creating 'admin_phones' table (Independent DDL)...")
            create_table_sql = """
            CREATE TABLE `admin_phones` (
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
            cursor.execute(create_table_sql)
            conn.commit()
            print("  [SUCCESS] 'admin_phones' table created successfully.")

        # Insert secondary phone mapped strictly to user_id = 1
        print("\n[STEP 4: GATE C] Inserting/Verifying secondary admin phone...")
        cursor.execute("""
            SELECT id, user_id, phone, is_active
            FROM admin_phones
            WHERE phone = %s;
        """, (SECONDARY_PHONE,))
        existing_row = cursor.fetchone()

        if existing_row:
            if existing_row['user_id'] != PRIMARY_ADMIN_ID:
                print(f"ABORT: Found unexpected ownership for {SECONDARY_PHONE}: user_id={existing_row['user_id']}")
                conn.rollback()
                sys.exit(1)
            if not existing_row['is_active']:
                print(f"  Re-activating existing mapping for {SECONDARY_PHONE} on user_id={PRIMARY_ADMIN_ID}...")
                cursor.execute("""
                    UPDATE admin_phones
                    SET is_active = 1
                    WHERE id = %s AND user_id = %s;
                """, (existing_row['id'], PRIMARY_ADMIN_ID))
                conn.commit()
                print("  [SUCCESS] Row updated to active.")
            else:
                print("  [SUCCESS] Row already active and correctly mapped to user_id=1. No update needed.")
        else:
            print(f"  Inserting new row: phone='{SECONDARY_PHONE}' -> user_id={PRIMARY_ADMIN_ID}...")
            cursor.execute("""
                INSERT INTO admin_phones (user_id, phone, label, is_active, created_at)
                VALUES (%s, %s, %s, 1, NOW());
            """, (PRIMARY_ADMIN_ID, SECONDARY_PHONE, "Secondary Admin (Ashish)"))
            conn.commit()
            print("  [SUCCESS] Row inserted successfully.")

        # =====================================================================
        # POST-MIGRATION VERIFICATION
        # =====================================================================
        print("\n[STEP 5: POST-MIGRATION AUDIT] Querying authoritative admin phones...")
        cursor.execute("""
            SELECT ap.id, ap.user_id, u.username, ap.phone, ap.label, ap.is_active, ap.created_at
            FROM admin_phones ap
            JOIN users u ON ap.user_id = u.id
            WHERE ap.user_id = %s;
        """, (PRIMARY_ADMIN_ID,))
        all_admin_phones = cursor.fetchall()
        for r in all_admin_phones:
            print(f"  - Row ID={r['id']}: Phone='{r['phone']}' mapped to User ID={r['user_id']} ({r['username']}), Label='{r['label']}', Active={r['is_active']}")

        print("\n" + "=" * 70)
        print("MIGRATION COMPLETED SUCCESSFULLY WITH ZERO ERRORS.")
        print("=" * 70)

    except Exception as e:
        conn.rollback()
        print(f"\nFATAL ERROR DURING MIGRATION: {e}")
        sys.exit(1)
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    run_migration()
