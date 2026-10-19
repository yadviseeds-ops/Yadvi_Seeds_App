#!/usr/bin/env python3
"""
Yadvi Seeds — Ephemeral MySQL 8.0 Live Compatibility Integration Runner
Location: backend/test_mysql_live_integration.py

Performs offline live verification against an ephemeral MySQL 8.0 container:
1. Target Database Pre-flight Emptiness & Table Set Verification (Base.metadata.create_all).
2. DATETIME(6) Microsecond Precision Verification across all datetime columns.
3. Pre-flight Dry-Run Verification (zero-mutation assertion).
4. Live Migration Execution & 100% SHA-256 Checksum Parity (332 rows across 15 tables).
5. Dynamic AUTO_INCREMENT Behavior & Synthetic Test Order try...finally Cleanup.
6. Foreign Key Constraint Enforcement (MySQL Error 1452).
7. Isolated Atomic Rollback & Unique Key Constraint Verification (MySQL Error 1062) in Dedicated Rollback DB.
"""

import os
import sys
import re
import time
import uuid
import argparse
from typing import Dict, Any

from sqlalchemy import create_engine, text, inspect
from sqlalchemy.engine import make_url, URL
from sqlalchemy.exc import IntegrityError

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app.models.all_models import Base
from migrate_sqlite_to_cloudsql import (
    YadviCloudSQLMigrator,
    TOPOLOGICAL_ORDER,
    mask_url,
)


def wait_for_mysql_ready(engine, timeout_seconds: int = 60):
    """Polls MySQL engine until ready or timeout expires."""
    start = time.time()
    last_err = None
    while time.time() - start < timeout_seconds:
        try:
            with engine.connect() as conn:
                conn.execute(text("SELECT 1;"))
                return
        except Exception as e:
            last_err = e
            time.sleep(2)
    raise TimeoutError(f"MySQL container did not become ready within {timeout_seconds}s. Last error: {last_err}")


def run_integration_tests(
    source_path: str,
    confirm_target: str,
    checkpoint_path: str,
    timestamp: str
) -> Dict[str, Any]:
    target_url_str = os.environ.get("TARGET_DATABASE_URL")
    if not target_url_str:
        print("ERROR: TARGET_DATABASE_URL environment variable is required.")
        sys.exit(1)

    url_obj = make_url(target_url_str)
    masked_url = mask_url(target_url_str)
    print(f"Target Database URI: {masked_url}")

    # Validate disposable database naming convention
    expected_db_pattern = rf"^yadvi_seeds_disposable_{timestamp}$"
    if not re.match(expected_db_pattern, confirm_target):
        print(f"ERROR: Target database name '{confirm_target}' does not match expected disposable pattern '{expected_db_pattern}'.")
        sys.exit(1)

    engine = create_engine(url_obj, pool_pre_ping=True)
    report: Dict[str, Any] = {"checks": {}, "per_table": {}}

    try:
        # Wait for MySQL to accept connections
        print("Waiting for MySQL engine readiness...")
        wait_for_mysql_ready(engine, timeout_seconds=60)
        print("MySQL engine is ready.")

        # =====================================================================
        # CHECK 1: Target Database Pre-flight Emptiness & Table Set Verification
        # =====================================================================
        with engine.connect() as conn:
            existing_tables = conn.execute(text("SHOW TABLES;")).fetchall()
            if existing_tables:
                print(f"ERROR: Target database '{confirm_target}' is not clean. Tables found: {existing_tables}")
                sys.exit(1)

        # Create schema using SQLAlchemy models
        Base.metadata.create_all(bind=engine)

        with engine.connect() as conn:
            created_tables = [r[0] for r in conn.execute(text("SHOW TABLES;")).fetchall()]
            missing_tables = [t for t in TOPOLOGICAL_ORDER if t not in created_tables]
            unexpected_tables = [t for t in created_tables if t not in TOPOLOGICAL_ORDER]

            if missing_tables:
                print(f"ERROR: Missing expected schema tables: {missing_tables}")
                sys.exit(1)
            if unexpected_tables:
                print(f"ERROR: Unexpected tables found in target: {unexpected_tables}")
                sys.exit(1)

        report["checks"]["check_1_schema_creation"] = {
            "status": "PASS",
            "tables_created": len(created_tables)
        }
        print(f"[PASS] 1. Verified disposable target database is clean and all {len(created_tables)} schema tables created.")

        # =====================================================================
        # CHECK 2: DATETIME(6) Microsecond Precision Verification
        # =====================================================================
        with engine.connect() as conn:
            fsp_cols = conn.execute(text("""
                SELECT table_name, column_name, datetime_precision
                FROM information_schema.columns
                WHERE table_schema = DATABASE() AND data_type = 'datetime';
            """)).fetchall()
            non_fsp6 = [f"{r[0]}.{r[1]} (precision={r[2]})" for r in fsp_cols if r[2] != 6]
            if non_fsp6:
                print(f"ERROR: Non-DATETIME(6) columns detected: {non_fsp6}")
                sys.exit(1)

        report["checks"]["check_2_datetime6_precision"] = {
            "status": "PASS",
            "total_datetime_columns": len(fsp_cols),
            "non_fsp6_count": 0
        }
        print(f"[PASS] 2. Verified all {len(fsp_cols)} datetime columns created as DATETIME(6) microsecond precision.")

        # =====================================================================
        # CHECK 3: Pre-flight Dry-Run Verification (Zero Mutation)
        # =====================================================================
        dry_runner = YadviCloudSQLMigrator(
            source_path=source_path,
            target_url=target_url_str,
            execute=False,
            checkpoint_path=checkpoint_path
        )
        dry_res = dry_runner.run_dry_run()
        assert dry_res["source_summary"]["total_rows"] == 332, f"Dry-run row count mismatch: {dry_res}"

        # Verify zero rows written to target tables during dry-run
        with engine.connect() as conn:
            for tbl in TOPOLOGICAL_ORDER:
                cnt = conn.execute(text(f"SELECT count(*) FROM `{tbl}`;")).scalar()
                if cnt != 0:
                    print(f"ERROR: Dry-run mutation detected! Table '{tbl}' has {cnt} rows.")
                    sys.exit(1)

        report["checks"]["check_3_dry_run"] = {
            "status": "PASS",
            "source_total_rows": dry_res["source_summary"]["total_rows"],
            "target_mutations": 0
        }
        print("[PASS] 3. Pre-flight dry-run completed successfully with 0 target mutations.")

        # =====================================================================
        # CHECK 4: Live Migration Execution & 100% SHA-256 Checksum Parity
        # =====================================================================
        migrator = YadviCloudSQLMigrator(
            source_path=source_path,
            target_url=target_url_str,
            execute=True,
            confirm_target=confirm_target,
            checkpoint_path=checkpoint_path
        )
        mig_res = migrator.execute_migration()
        assert mig_res["status"] == "SUCCESS", f"Migration returned status: {mig_res.get('status')}"
        assert mig_res["total_rows"] == 332, f"Total rows {mig_res['total_rows']} != 332"
        assert mig_res["tables_migrated"] == 15, f"Tables migrated {mig_res['tables_migrated']} != 15"

        for tbl in TOPOLOGICAL_ORDER:
            s_cnt = migrator.source_counts[tbl]
            t_cnt = migrator.target_counts[tbl]
            s_chk = migrator.source_checksums[tbl]
            t_chk = migrator.target_checksums[tbl]
            assert s_cnt == t_cnt, f"Row count mismatch on {tbl}: {s_cnt} vs {t_cnt}"
            assert s_chk == t_chk, f"Checksum mismatch on {tbl}: {s_chk} vs {t_chk}"
            report["per_table"][tbl] = {
                "source_rows": s_cnt,
                "target_rows": t_cnt,
                "source_sha256": s_chk,
                "target_sha256": t_chk,
                "parity": "MATCH"
            }

        report["checks"]["check_4_live_migration"] = {
            "status": "PASS",
            "total_rows_migrated": mig_res["total_rows"],
            "tables_migrated": mig_res["tables_migrated"],
            "checksum_parity": "100% (15/15 tables)"
        }
        print(f"[PASS] 4. Live migration completed with 100% checksum parity (332 rows across 15 tables).")

        # =====================================================================
        # CHECK 5: Dynamic AUTO_INCREMENT Behavior with try...finally Cleanup
        # =====================================================================
        with engine.connect() as conn:
            pre_max_id = conn.execute(text("SELECT COALESCE(MAX(id), 0) FROM `orders`;")).scalar()
            expected_next = pre_max_id + 1
            reported_next = mig_res["auto_increments"].get("orders")
            assert reported_next == expected_next, f"Auto-increment mismatch for orders: {reported_next} != {expected_next}"

            shop_id = conn.execute(text("SELECT id FROM `shop_owners` LIMIT 1;")).scalar()
            test_order_num = f"SYNTH-ORDER-{uuid.uuid4().hex[:8]}"
            test_order_inserted = False

            try:
                conn.execute(text("""
                    INSERT INTO `orders` (`order_number`, `shop_id`, `total_quantity_bags`, `total_items_count`, `status`, `source`)
                    VALUES (:order_num, :shop_id, 2, 1, 'New', 'Integration Test Runner');
                """), {"order_num": test_order_num, "shop_id": shop_id})
                conn.commit()
                test_order_inserted = True

                inserted_id = conn.execute(
                    text("SELECT id FROM `orders` WHERE `order_number` = :order_num;"),
                    {"order_num": test_order_num}
                ).scalar()

                if inserted_id != expected_next:
                    print(f"ERROR: AUTO_INCREMENT assigned ID {inserted_id}, expected {expected_next}!")
                    sys.exit(1)
                print(f"[PASS] 5. Dynamic AUTO_INCREMENT sequence verified without collision (Assigned ID: {inserted_id}).")
                report["checks"]["check_5_auto_increment"] = {
                    "status": "PASS",
                    "pre_max_id": pre_max_id,
                    "expected_next_id": expected_next,
                    "assigned_id": inserted_id
                }
            finally:
                if test_order_inserted:
                    try:
                        conn.execute(
                            text("DELETE FROM `orders` WHERE `order_number` = :order_num;"),
                            {"order_num": test_order_num}
                        )
                        conn.commit()
                        remaining = conn.execute(
                            text("SELECT count(*) FROM `orders` WHERE `order_number` = :order_num;"),
                            {"order_num": test_order_num}
                        ).scalar()
                        if remaining != 0:
                            print(f"CRITICAL CLEANUP FAILURE: Test order {test_order_num} still present in database!")
                            sys.exit(1)
                        print(f"  Verified cleanup: Synthetic test order '{test_order_num}' removed cleanly.")
                    except Exception as cleanup_err:
                        print(f"CRITICAL CLEANUP EXCEPTION: Failed to remove test order: {cleanup_err}")
                        sys.exit(1)

        # =====================================================================
        # CHECK 6: MySQL Foreign Key Constraint Verification (Error 1452)
        # =====================================================================
        with engine.connect() as conn:
            fk_violation_caught = False
            try:
                conn.execute(text("""
                    INSERT INTO `users` (`phone`, `full_name`, `role_id`)
                    VALUES ('9990001111', 'Orphan FK Test User', 99999);
                """))
                conn.commit()
                print("ERROR: MySQL allowed orphan foreign key insertion (role_id=99999)!")
                sys.exit(1)
            except IntegrityError as exc:
                err_str = str(exc)
                # Check for MySQL Error 1452 (ER_NO_REFERENCED_ROW_2)
                orig = getattr(exc, "orig", None)
                errno = getattr(orig, "errno", None)
                if errno == 1452 or "1452" in err_str or "foreign key constraint fails" in err_str.lower():
                    fk_violation_caught = True
                    print(f"[PASS] 6. MySQL actively enforced foreign key constraint (Error 1452 verified).")
                    report["checks"]["check_6_foreign_key_1452"] = {
                        "status": "PASS",
                        "error_code": 1452,
                        "description": "ER_NO_REFERENCED_ROW_2 enforced"
                    }
                else:
                    print(f"ERROR: Expected foreign key Error 1452, but got: {err_str}")
                    sys.exit(1)

            if not fk_violation_caught:
                print("ERROR: Foreign key constraint was not enforced by MySQL!")
                sys.exit(1)

        # =====================================================================
        # CHECK 7: Isolated Rollback Verification & Unique Key Error 1062
        # =====================================================================
        rollback_db = f"yadvi_seeds_rollback_{timestamp}"
        if not re.match(r"^yadvi_seeds_rollback_[0-9]{8}_[0-9]{6}$", rollback_db):
            print(f"ERROR: Rollback database identifier '{rollback_db}' violates safety regex.")
            sys.exit(1)

        root_url = url_obj.set(database=None)
        root_engine = create_engine(root_url, pool_pre_ping=True)
        created_rollback_db = False

        try:
            with root_engine.connect() as conn:
                existing_dbs = {r[0] for r in conn.execute(text("SHOW DATABASES;")).fetchall()}
                if rollback_db in existing_dbs:
                    print(f"ERROR: Rollback database '{rollback_db}' already exists!")
                    sys.exit(1)
                conn.execute(text(f"CREATE DATABASE `{rollback_db}`;"))
                conn.commit()
                created_rollback_db = True
                print(f"  Created isolated rollback database '{rollback_db}'.")

            rb_url = url_obj.set(database=rollback_db)
            rb_engine = create_engine(rb_url, pool_pre_ping=True)

            try:
                with rb_engine.begin() as conn:
                    conn.execute(text("CREATE TABLE `test_rb` (`id` INT PRIMARY KEY, `val` VARCHAR(50) UNIQUE);"))

                dup_caught = False
                try:
                    with rb_engine.begin() as conn:
                        conn.execute(text("INSERT INTO `test_rb` (`id`, `val`) VALUES (1, 'row1');"))
                        conn.execute(text("INSERT INTO `test_rb` (`id`, `val`) VALUES (2, 'row1');"))  # Unique key violation
                except IntegrityError as exc:
                    orig = getattr(exc, "orig", None)
                    errno = getattr(orig, "errno", None)
                    err_str = str(exc)
                    if errno == 1062 or "1062" in err_str or "duplicate entry" in err_str.lower():
                        dup_caught = True
                    else:
                        print(f"ERROR: Expected Error 1062, got: {err_str}")
                        sys.exit(1)

                if not dup_caught:
                    print("ERROR: MySQL did not raise duplicate key error on unique violation!")
                    sys.exit(1)

                with rb_engine.connect() as conn:
                    cnt = conn.execute(text("SELECT count(*) FROM `test_rb`;")).scalar()
                    assert cnt == 0, f"Rollback failed: {cnt} rows committed instead of 0"

                print("[PASS] 7. Atomic transaction rollback & unique error 1062 verified in dedicated test database.")
                report["checks"]["check_7_rollback_and_1062"] = {
                    "status": "PASS",
                    "error_code": 1062,
                    "committed_rows_after_failure": 0
                }
            finally:
                rb_engine.dispose()

        finally:
            if created_rollback_db:
                with root_engine.connect() as conn:
                    conn.execute(text(f"DROP DATABASE `{rollback_db}`;"))
                    conn.commit()
                    print(f"  Verified teardown: Dropped dedicated rollback database '{rollback_db}'.")
            root_engine.dispose()

        print("\n=== ALL 7 LIVE MYSQL 8.0 INTEGRATION TESTS COMPLETED SUCCESSFULLY ===")
        return report

    finally:
        engine.dispose()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Yadvi Seeds Ephemeral MySQL Integration Runner")
    parser.add_argument("--source", required=True, help="Path to copied disposable SQLite backup")
    parser.add_argument("--confirm-target", required=True, help="Exact target disposable database name")
    parser.add_argument("--checkpoint-file", required=True, help="Path to dedicated disposable checkpoint")
    parser.add_argument("--timestamp", required=True, help="Execution timestamp matching disposable resource names")
    args = parser.parse_args()

    run_integration_tests(
        source_path=args.source,
        confirm_target=args.confirm_target,
        checkpoint_path=args.checkpoint_file,
        timestamp=args.timestamp
    )
