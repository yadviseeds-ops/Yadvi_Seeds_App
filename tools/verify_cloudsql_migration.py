
import os
import sys
from sqlalchemy import create_engine, text

EXPECTED = {
    "roles": 3,
    "users": 12,
    "field_executives": 4,
    "shop_owners": 5,
    "fcm_device_tokens": 0,
    "products": 7,
    "inventory": 0,
    "orders": 114,
    "order_items": 122,
    "shipments": 6,
    "visits": 10,
    "attendance": 6,
    "fe_locations": 40,
    "eod_reports": 1,
    "notifications": 226,
}

def main():
    url = os.environ.get("TARGET_DATABASE_URL")
    if not url:
        print("ERROR: TARGET_DATABASE_URL is not set.")
        return 1

    engine = create_engine(url)
    try:
        with engine.connect() as conn:
            tables = set(
                conn.execute(text("SHOW TABLES")).scalars().all()
            )

            missing = set(EXPECTED) - tables
            if missing:
                print("ERROR: Missing tables:", sorted(missing))
                return 1

            total = 0
            failed = False
            print("\nCloud SQL migration verification")
            print("-" * 45)

            for table, expected in EXPECTED.items():
                actual = conn.execute(
                    text(f"SELECT COUNT(*) FROM `{table}`")
                ).scalar_one()
                total += actual
                status = "PASS" if actual == expected else "FAIL"
                print(
                    f"{status}: {table:<22} "
                    f"expected={expected:>3} actual={actual:>3}"
                )
                if actual != expected:
                    failed = True

            print("-" * 45)
            print(f"Total rows: {total} (expected 556)")
            print("RESULT:", "FAILED" if failed or total != 556 else "PASSED")
            return 1 if failed or total != 556 else 0
    finally:
        engine.dispose()

if __name__ == "__main__":
    sys.exit(main())
