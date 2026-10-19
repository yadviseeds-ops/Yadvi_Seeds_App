import sqlite3
import shutil
import os
import sys

def migrate_database_file(db_path: str):
    if not os.path.exists(db_path):
        print(f"[SKIP] Database file does not exist: {db_path}")
        return

    print(f"\n--- Migrating database: {db_path} ---")

    # 1. Verify if dealer_code column exists
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    cur.execute("PRAGMA table_info(shop_owners)")
    columns = [col[1] for col in cur.fetchall()]

    if "dealer_code" not in columns:
        print(f"[INFO] 'dealer_code' column already removed from {db_path}.")
        conn.close()
        return

    # 2. Create safety backup
    backup_dir = os.path.join(os.path.dirname(os.path.abspath(db_path)), "backups")
    os.makedirs(backup_dir, exist_ok=True)
    backup_path = os.path.join(backup_dir, f"{os.path.basename(db_path)}_pre_dealer_code_removal.bak")
    shutil.copyfile(db_path, backup_path)
    print(f"[BACKUP] Safety backup created at: {backup_path}")

    # 3. Perform atomic table rebuild migration
    try:
        cur.execute("PRAGMA foreign_keys = OFF")
        cur.execute("BEGIN TRANSACTION")

        cur.execute("""
        CREATE TABLE shop_owners_new (
            id INTEGER NOT NULL PRIMARY KEY,
            user_id INTEGER NOT NULL UNIQUE REFERENCES users (id),
            shop_name VARCHAR(150) NOT NULL,
            market_location VARCHAR(150) NOT NULL,
            territory VARCHAR(100),
            city VARCHAR(100),
            address TEXT NOT NULL,
            lat FLOAT,
            lng FLOAT,
            shop_photo_url VARCHAR(255),
            owner_photo_url VARCHAR(255),
            opening_stock_bags INTEGER DEFAULT 0,
            current_stock_bags INTEGER DEFAULT 0,
            primary_demand_crop VARCHAR(100),
            status VARCHAR(20) DEFAULT 'Active',
            assigned_executive_id INTEGER REFERENCES field_executives (id)
        )
        """)

        cur.execute("PRAGMA table_info(shop_owners)")
        existing_cols = [col[1] for col in cur.fetchall()]
        cols_to_copy = [c for c in existing_cols if c != "dealer_code"]
        cols_str = ", ".join(cols_to_copy)

        cur.execute(f"""
        INSERT INTO shop_owners_new ({cols_str})
        SELECT {cols_str}
        FROM shop_owners
        """)

        cur.execute("DROP TABLE shop_owners")
        cur.execute("ALTER TABLE shop_owners_new RENAME TO shop_owners")
        cur.execute("CREATE INDEX IF NOT EXISTS ix_shop_owners_id ON shop_owners (id)")

        conn.commit()
        cur.execute("PRAGMA foreign_keys = ON")

        # 4. Integrity verification
        cur.execute("PRAGMA foreign_key_check")
        fk_errors = cur.fetchall()
        if fk_errors:
            raise RuntimeError(f"Foreign key integrity check failed after rebuild: {fk_errors}")

        cur.execute("PRAGMA table_info(shop_owners)")
        new_cols = [c[1] for c in cur.fetchall()]
        assert "dealer_code" not in new_cols, "dealer_code still present in table!"

        cur.execute("SELECT COUNT(*) FROM shop_owners")
        count = cur.fetchone()[0]
        print(f"[SUCCESS] Migration completed for {db_path}!")
        print(f"[VERIFIED] Columns now: {new_cols}")
        print(f"[VERIFIED] Preserved total shop owner records: {count}")

    except Exception as exc:
        conn.rollback()
        print(f"[ERROR] Migration failed: {exc}", file=sys.stderr)
        raise exc
    finally:
        conn.close()

if __name__ == "__main__":
    targets = [
        "backend/yadvi_seeds.db",
        "yadvi_seeds.db"
    ]
    for db in targets:
        migrate_database_file(db)
