import sqlite3
import sys

def migrate_db():
    try:
        conn = sqlite3.connect('yadvi_seeds.db')
        cur = conn.cursor()

        # Check if username exists
        cur.execute("PRAGMA table_info(users);")
        columns = [row[1] for row in cur.fetchall()]

        if 'username' not in columns:
            print("Adding username column to users table...")
            cur.execute("ALTER TABLE users ADD COLUMN username VARCHAR(50);")

            # Set default usernames based on role and id
            cur.execute("""
                UPDATE users
                SET username = 'ADMIN'
                WHERE email = 'admin@yadvi.com' OR phone = '9876543210'
            """)

            cur.execute("""
                UPDATE users
                SET username = 'FE' || id
                WHERE role_id IN (SELECT id FROM roles WHERE name = 'field_executive')
            """)

            cur.execute("""
                UPDATE users
                SET username = 'SHOP' || id
                WHERE role_id IN (SELECT id FROM roles WHERE name = 'shop_owner')
            """)

            conn.commit()
            print("Migration successful.")
        # Check notifications columns
        cur.execute("PRAGMA table_info(notifications);")
        notif_cols = [row[1] for row in cur.fetchall()]

        columns_to_add = [
            ("meta_message_id", "VARCHAR(100)"),
            ("delivery_status", "VARCHAR(50) DEFAULT 'Accepted'"),
            ("meta_error_code", "INTEGER"),
            ("meta_error_message", "TEXT"),
            ("delivered_at", "DATETIME"),
            ("read_at", "DATETIME")
        ]

        for col_name, col_type in columns_to_add:
            if col_name not in notif_cols:
                print(f"Adding {col_name} column to notifications table...")
                cur.execute(f"ALTER TABLE notifications ADD COLUMN {col_name} {col_type};")

        # Ensure dealer_code is removed from shop_owners
        cur.execute("PRAGMA table_info(shop_owners);")
        shop_cols = [row[1] for row in cur.fetchall()]
        if "dealer_code" in shop_cols:
            print("Removing dealer_code from shop_owners...")
            from migrate_remove_dealer_code import migrate_database_file
            migrate_database_file('yadvi_seeds.db')

        conn.commit()
        print("Notifications migration check completed.")

    except Exception as e:
        print(f"Migration failed: {e}")
        sys.exit(1)
    finally:
        if 'conn' in locals():
            conn.close()

if __name__ == '__main__':
    migrate_db()
