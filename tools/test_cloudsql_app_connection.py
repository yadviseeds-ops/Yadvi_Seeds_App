#!/usr/bin/env python3
"""
Yadvi Seeds — Read-Only Cloud SQL Connection Test Script
Location: tools/test_cloudsql_app_connection.py

Connects to Cloud SQL via the local proxy at 127.0.0.1:3307 as 'yadvi_app_user'.
Prompts for password securely using getpass (never echoes, logs, or stores it).
Executes only read-only verification queries:
- SELECT DATABASE()
- SELECT CURRENT_USER()
- SHOW TABLES
"""

import sys
import getpass
import mysql.connector
from mysql.connector import errorcode

TARGET_HOST = "127.0.0.1"
TARGET_PORT = 3307
TARGET_DB = "yadvi_seeds_db"
TARGET_USER = "yadvi_runtime_user"

def main():
    print("=" * 60)
    print("Yadvi Seeds: Read-Only Cloud SQL App Connection Test")
    print(f"Target Proxy: {TARGET_HOST}:{TARGET_PORT}")
    print(f"Target Database: {TARGET_DB}")
    print(f"Target Username: {TARGET_USER}")
    print("=" * 60)

    # 1. Prompt for app user's password securely with no echo
    try:
        app_password = getpass.getpass(f"Enter password for '{TARGET_USER}': ")
    except (KeyboardInterrupt, EOFError):
        print("\nTest cancelled by user.")
        sys.exit(1)

    print("\nAttempting connection through Cloud SQL Auth Proxy...")

    # 2. Connect
    try:
        conn = mysql.connector.connect(
            host=TARGET_HOST,
            port=TARGET_PORT,
            user=TARGET_USER,
            password=app_password,
            database=TARGET_DB,
            connection_timeout=10
        )
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
            print(f"FAILED: Access denied for user '{TARGET_USER}'. Check the password and host permissions.")
        elif err.errno == errorcode.ER_BAD_DB_ERROR:
            print(f"FAILED: Database '{TARGET_DB}' does not exist or user has no access.")
        else:
            # Mask any accidental password reflection in connection error messages
            safe_err = str(err).replace(app_password, "***") if app_password else str(err)
            print(f"FAILED: Connection error on {TARGET_HOST}:{TARGET_PORT}: {safe_err}")
        sys.exit(1)

    cursor = conn.cursor()

    try:
        # 3. Read-only checks
        cursor.execute("SELECT DATABASE(), CURRENT_USER();")
        active_db, current_user = cursor.fetchone()
        print("SUCCESS: Connected to Cloud SQL successfully!")
        print(f"  Active Database: {active_db}")
        print(f"  Authenticated As: {current_user}")

        # 4. Check existing tables
        cursor.execute("SHOW TABLES;")
        tables = cursor.fetchall()
        table_count = len(tables)

        print(f"\nTables in '{active_db}' ({table_count} found):")
        if table_count == 0:
            print("  (Database is currently empty; ready for schema initialization)")
        else:
            for row in tables:
                print(f"  - {row[0]}")

        print("\nRead-only connection test completed successfully with zero modifications.")

    except mysql.connector.Error as err:
        safe_err = str(err).replace(app_password, "***") if app_password else str(err)
        print(f"SQL Execution Error: {safe_err}")
        sys.exit(1)
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    main()
