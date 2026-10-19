#!/usr/bin/env python3
"""
Yadvi Seeds — Apply Least-Privilege MySQL Grants
Location: tools/apply_mysql_grants.py

Connects to Cloud SQL Auth Proxy on 127.0.0.1:3307 as 'root' using secure getpass.
Verifies preconditions, prompts for confirmation, applies database-scoped grants,
and verifies results via SHOW GRANTS.
"""

import sys
import getpass
import mysql.connector
from mysql.connector import errorcode

TARGET_HOST = "127.0.0.1"
TARGET_PORT = 3307
TARGET_DB = "yadvi_seeds_db"
TARGET_USER = "yadvi_app_user"
TARGET_USER_HOST = "%"

GRANTED_PRIVILEGES = "SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, REFERENCES"

def main():
    print("=" * 60)
    print("Yadvi Seeds: Apply Least-Privilege Grants to 'yadvi_app_user'")
    print(f"Target Proxy: {TARGET_HOST}:{TARGET_PORT}")
    print(f"Target Database: {TARGET_DB}")
    print(f"Target User: '{TARGET_USER}'@'{TARGET_USER_HOST}'")
    print("=" * 60)

    # 1. Prompt for root password securely using getpass (no echo)
    try:
        root_password = getpass.getpass("Enter MySQL root password (press Enter if blank): ")
    except (KeyboardInterrupt, EOFError):
        print("\nAborted.")
        sys.exit(1)

    # 2. Establish connection
    print("\nConnecting to Cloud SQL via proxy on 127.0.0.1:3307...")
    try:
        conn = mysql.connector.connect(
            host=TARGET_HOST,
            port=TARGET_PORT,
            user="root",
            password=root_password,
            connection_timeout=10
        )
    except mysql.connector.Error as err:
        if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
            print("ERROR: Authentication failed for administrative user 'root'.")
            print("Please verify the root password. No changes were made.")
        else:
            print(f"ERROR: Could not connect to MySQL proxy on {TARGET_HOST}:{TARGET_PORT}: {err}")
        sys.exit(1)

    cursor = conn.cursor()

    try:
        # 3. Verify target database exists
        cursor.execute(
            "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = %s",
            (TARGET_DB,)
        )
        if not cursor.fetchone():
            print(f"ERROR: Database '{TARGET_DB}' does not exist on instance. Halting.")
            sys.exit(1)
        print(f"Pre-check passed: Database '{TARGET_DB}' exists.")

        # 4. Verify target user exists
        cursor.execute(
            "SELECT user, host FROM mysql.user WHERE user = %s AND host = %s",
            (TARGET_USER, TARGET_USER_HOST)
        )
        if not cursor.fetchone():
            print(f"ERROR: User '{TARGET_USER}'@'{TARGET_USER_HOST}' does not exist on instance. Halting.")
            sys.exit(1)
        print(f"Pre-check passed: User '{TARGET_USER}'@'{TARGET_USER_HOST}' exists.")

        # 5. Display proposed statement and request explicit confirmation
        grant_sql = f"GRANT {GRANTED_PRIVILEGES} ON `{TARGET_DB}`.* TO '{TARGET_USER}'@'{TARGET_USER_HOST}';"
        print("\nProposed SQL Statement to Execute:")
        print(f"  {grant_sql}")
        print("Note: No global, administrative, or GRANT OPTION privileges will be granted.")

        try:
            confirm = input("\nDo you confirm execution of this GRANT statement? (yes/no): ").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print("\nCancelled.")
            sys.exit(1)

        if confirm != "yes":
            print("Grant execution cancelled by user. Zero database permissions were modified.")
            sys.exit(0)

        # 6. Execute GRANT
        print("\nExecuting GRANT statement...")
        cursor.execute(grant_sql)
        cursor.execute("FLUSH PRIVILEGES;")
        conn.commit()
        print("GRANT executed and privileges flushed successfully.")

        # 7. Verify grants with read-only query
        print("\nVerifying resulting grants with SHOW GRANTS:")
        cursor.execute(f"SHOW GRANTS FOR '{TARGET_USER}'@'{TARGET_USER_HOST}';")
        grants = cursor.fetchall()
        for row in grants:
            print(f"  {row[0]}")

        print("\nLeast-privilege setup for 'yadvi_app_user' completed successfully.")

    except mysql.connector.Error as err:
        print(f"MySQL Execution Error: {err}")
        sys.exit(1)
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    main()
