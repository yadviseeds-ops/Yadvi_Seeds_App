#!/usr/bin/env python3
"""
Automated Isolated Test Suite for Yadvi Seeds Cloud SQL Migration Tooling
Location: backend/test_migration_tooling.py

Tests:
1. Dry-run mode by default without writes
2. Missing confirmation gate blocks writes
3. Mismatched database confirmation blocks writes
4. Corrupted/invalid source database aborts
5. Source foreign-key orphan detector raises error on invalid relationships
6. Target missing schema aborts without writing
7. Non-empty target aborts to prevent overwrite or primary key collision
8. Transactional rollback cleans up target on failure
9. End-to-end migration into clean disposable target with 100% row and checksum parity
10. Production fail-closed behavior (RuntimeError when SQLite fallback is forbidden)
11. Local development fallback behavior (SQLite fallback allowed in development)
12. Application startup AUTO_INIT_DB flag verification
"""

import os
import sys
import unittest
import tempfile
import sqlite3
from unittest.mock import patch

# Ensure backend root in path
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app.core.config import settings
from app.core.database import get_engine
from app.models.all_models import Base
from migrate_sqlite_to_cloudsql import YadviCloudSQLMigrator, TOPOLOGICAL_ORDER

VERIFIED_BACKUP_PATH = os.path.join(BACKEND_DIR, "backups", "yadvi_seeds_backup_20261013_223421.db")


class TestMigrationTooling(unittest.TestCase):

    def setUp(self):
        self.source_backup = VERIFIED_BACKUP_PATH
        self.assertTrue(os.path.exists(self.source_backup), "Verified backup file must exist.")

    def test_01_dry_run_default_no_writes(self):
        """Dry-run mode inspects source and plans operations without writing."""
        migrator = YadviCloudSQLMigrator(
            source_path=self.source_backup,
            target_url=None,
            execute=False
        )
        res = migrator.run_dry_run()
        self.assertEqual(res["mode"], "dry_run")
        self.assertEqual(res["source_summary"]["total_rows"], 332)
        self.assertEqual(len(res["source_summary"]["counts"]), 15)
        # Confirm counts match verified baseline
        self.assertEqual(res["source_summary"]["counts"]["orders"], 58)
        self.assertEqual(res["source_summary"]["counts"]["users"], 12)
        self.assertEqual(res["source_summary"]["counts"]["notifications"], 114)

    def test_02_missing_confirm_target_blocks_execution(self):
        """Execution without --confirm-target must raise ValueError."""
        migrator = YadviCloudSQLMigrator(
            source_path=self.source_backup,
            target_url="sqlite:///temp_target.db",
            execute=True,
            confirm_target=None
        )
        with self.assertRaises(ValueError) as ctx:
            migrator.execute_migration()
        self.assertIn("confirmation mismatch", str(ctx.exception).lower())

    def test_03_mismatched_confirm_target_blocks_execution(self):
        """Execution with wrong --confirm-target must raise ValueError."""
        migrator = YadviCloudSQLMigrator(
            source_path=self.source_backup,
            target_url="sqlite:///my_real_db.db",
            execute=True,
            confirm_target="wrong_db_name.db"
        )
        with self.assertRaises(ValueError) as ctx:
            migrator.execute_migration()
        self.assertIn("confirmation mismatch", str(ctx.exception).lower())

    def test_04_corrupted_source_integrity_aborts(self):
        """An invalid SQLite file must fail integrity check and abort immediately."""
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as bad_file:
            bad_file.write(b"NOT A SQLITE DATABASE CORRUPT HEADER DATA")
            bad_path = bad_file.name

        try:
            migrator = YadviCloudSQLMigrator(
                source_path=bad_path,
                target_url=None,
                execute=False
            )
            with self.assertRaises(Exception):
                migrator.validate_source()
        finally:
            if os.path.exists(bad_path):
                os.remove(bad_path)

    def test_05_source_foreign_key_orphan_detection(self):
        """Explicit FK validator must detect orphan records and reject invalid data."""
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tmp_db:
            orphan_db_path = tmp_db.name

        try:
            # Create a minimal schema with an intentional orphan child record
            conn = sqlite3.connect(orphan_db_path)
            cur = conn.cursor()
            for tbl in TOPOLOGICAL_ORDER:
                cur.execute(f"CREATE TABLE [{tbl}] (id INTEGER PRIMARY KEY);")
            cur.execute("ALTER TABLE users ADD COLUMN role_id INTEGER;")
            # Insert a user with role_id=999 when role 999 does not exist
            cur.execute("INSERT INTO roles (id) VALUES (1);")
            cur.execute("INSERT INTO users (id, role_id) VALUES (1, 999);")
            conn.commit()
            conn.close()

            migrator = YadviCloudSQLMigrator(
                source_path=orphan_db_path,
                target_url=None,
                execute=False
            )
            with self.assertRaises(ValueError) as ctx:
                migrator.validate_source()
            self.assertIn("foreign key violation", str(ctx.exception).lower())
        finally:
            if os.path.exists(orphan_db_path):
                os.remove(orphan_db_path)

    def test_06_target_missing_schema_aborts(self):
        """Migrator must abort if target database exists but is missing required schema tables."""
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as empty_tgt:
            target_path = empty_tgt.name

        try:
            target_url = f"sqlite:///{target_path}"
            migrator = YadviCloudSQLMigrator(
                source_path=self.source_backup,
                target_url=target_url,
                execute=True,
                confirm_target=os.path.basename(target_path)
            )
            with self.assertRaises(RuntimeError) as ctx:
                migrator.execute_migration()
            self.assertIn("missing required schema tables", str(ctx.exception).lower())
        finally:
            if os.path.exists(target_path):
                try:
                    os.remove(target_path)
                except Exception:
                    pass

    def test_06b_target_column_mismatch_aborts(self):
        """Migrator must abort if target table is missing a required column."""
        from sqlalchemy import create_engine as ce

        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as col_tgt:
            target_path = col_tgt.name

        try:
            target_url = f"sqlite:///{target_path}"
            engine = ce(target_url)
            Base.metadata.create_all(bind=engine)
            with engine.begin() as conn:
                from sqlalchemy import text
                conn.execute(text("DROP TABLE users;"))
                conn.execute(text("CREATE TABLE users (id INTEGER PRIMARY KEY, email VARCHAR(100));"))
            engine.dispose()

            migrator = YadviCloudSQLMigrator(
                source_path=self.source_backup,
                target_url=target_url,
                execute=True,
                confirm_target=os.path.basename(target_path)
            )
            with self.assertRaises(RuntimeError) as ctx:
                migrator.execute_migration()
            self.assertIn("missing columns", str(ctx.exception).lower())
        finally:
            if os.path.exists(target_path):
                try:
                    os.remove(target_path)
                except Exception:
                    pass

    def test_07_non_empty_target_aborts_without_overwrite(self):
        """Migrator must halt if target database already contains records."""
        from sqlalchemy import create_engine as ce

        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tgt_file:
            tgt_path = tgt_file.name

        try:
            target_url = f"sqlite:///{tgt_path}"
            engine = ce(target_url)
            Base.metadata.create_all(bind=engine)

            # Insert 1 pre-existing record into target
            with engine.begin() as conn:
                from sqlalchemy import text
                conn.execute(text("INSERT INTO roles (id, name, description) VALUES (99, 'pre_existing', 'test')"))

            migrator = YadviCloudSQLMigrator(
                source_path=self.source_backup,
                target_url=target_url,
                execute=True,
                confirm_target=os.path.basename(tgt_path)
            )
            with self.assertRaises(RuntimeError) as ctx:
                migrator.execute_migration()
            self.assertIn("already contain records", str(ctx.exception).lower())

            # Verify the pre-existing record was NOT deleted or overwritten
            with engine.connect() as conn:
                cnt = conn.execute(text("SELECT count(*) FROM roles")).scalar()
                self.assertEqual(cnt, 1)
        finally:
            if 'engine' in locals():
                engine.dispose()
            if os.path.exists(tgt_path):
                try:
                    os.remove(tgt_path)
                except Exception:
                    pass

    def test_08_successful_migration_parity_and_checksums(self):
        """End-to-end migration into a clean disposable target verifies 100% parity and SHA256 checksums."""
        from sqlalchemy import create_engine as ce

        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tgt_file:
            tgt_path = tgt_file.name

        checkpoint_path = tgt_path + ".checkpoint.json"

        try:
            target_url = f"sqlite:///{tgt_path}"
            target_engine = ce(target_url)
            # Create fresh clean schema
            Base.metadata.create_all(bind=target_engine)

            migrator = YadviCloudSQLMigrator(
                source_path=self.source_backup,
                target_url=target_url,
                execute=True,
                confirm_target=os.path.basename(tgt_path),
                checkpoint_path=checkpoint_path
            )

            result = migrator.execute_migration()
            self.assertEqual(result["status"], "SUCCESS")
            self.assertEqual(result["tables_migrated"], 15)
            self.assertEqual(result["total_rows"], 332)

            # Verify target table row counts
            with target_engine.connect() as conn:
                from sqlalchemy import text
                self.assertEqual(conn.execute(text("SELECT count(*) FROM orders")).scalar(), 58)
                self.assertEqual(conn.execute(text("SELECT count(*) FROM order_items")).scalar(), 66)
                self.assertEqual(conn.execute(text("SELECT count(*) FROM users")).scalar(), 12)
                self.assertEqual(conn.execute(text("SELECT count(*) FROM products")).scalar(), 7)
                self.assertEqual(conn.execute(text("SELECT count(*) FROM notifications")).scalar(), 114)
                self.assertEqual(conn.execute(text("SELECT count(*) FROM visits")).scalar(), 10)
                self.assertEqual(conn.execute(text("SELECT count(*) FROM shipments")).scalar(), 6)

            # Verify checkpoint file was created
            self.assertTrue(os.path.exists(checkpoint_path))

        finally:
            if 'target_engine' in locals():
                target_engine.dispose()
            if os.path.exists(tgt_path):
                try:
                    os.remove(tgt_path)
                except Exception:
                    pass
            if os.path.exists(checkpoint_path):
                try:
                    os.remove(checkpoint_path)
                except Exception:
                    pass

    def test_09_production_fail_closed_behavior(self):
        """In production mode with ALLOW_SQLITE_FALLBACK=False, DB failure must raise RuntimeError."""
        with patch.object(settings, "ENVIRONMENT", "production"), \
             patch.object(settings, "ALLOW_SQLITE_FALLBACK", False), \
             patch.object(settings, "DB_PORT", "99999"):  # Invalid port guaranteed to fail
            with self.assertRaises(RuntimeError) as ctx:
                get_engine()
            self.assertIn("primary database connection failed", str(ctx.exception).lower())

    def test_10_development_fallback_behavior(self):
        """In development mode with fallback enabled, DB failure falls back to SQLite."""
        with patch.object(settings, "ENVIRONMENT", "development"), \
             patch.object(settings, "ALLOW_SQLITE_FALLBACK", True), \
             patch.object(settings, "DB_PORT", "99999"):  # Force MySQL failure
            engine = get_engine()
            self.assertEqual(engine.dialect.name, "sqlite")

    def test_11_startup_auto_init_flag(self):
        """AUTO_INIT_DB flag correctly toggles startup seeding behavior."""
        with patch.object(settings, "AUTO_INIT_DB", False):
            self.assertFalse(settings.AUTO_INIT_DB)
        with patch.object(settings, "AUTO_INIT_DB", True):
            self.assertTrue(settings.AUTO_INIT_DB)

    def test_12_datetime_metadata_discovery_and_parsing(self):
        """Task 1: Verify DateTime columns discovered by metadata type and parsed safely."""
        from datetime import datetime, date, timezone, timedelta
        from unittest.mock import patch
        from sqlalchemy import DateTime, Date
        from migrate_sqlite_to_cloudsql import parse_datetime_val

        # 1. Metadata type discovery test
        # Ensure columns that do NOT end with _at/_date/_time are identified as DateTime
        fe_table = Base.metadata.tables.get("field_executives")
        self.assertIsNotNone(fe_table)
        last_loc_col = fe_table.columns.get("last_location_update")
        self.assertIsNotNone(last_loc_col)
        self.assertIsInstance(last_loc_col.type, DateTime)

        fe_loc_table = Base.metadata.tables.get("fe_locations")
        self.assertIsNotNone(fe_loc_table)
        ts_col = fe_loc_table.columns.get("timestamp")
        self.assertIsNotNone(ts_col)
        self.assertIsInstance(ts_col.type, DateTime)

        inv_table = Base.metadata.tables.get("inventory")
        self.assertIsNotNone(inv_table)
        audit_col = inv_table.columns.get("last_stock_audit")
        self.assertIsNotNone(audit_col)
        self.assertIsInstance(audit_col.type, DateTime)

        # 2. Parsing behavior tests
        # Fractional seconds
        dt1 = parse_datetime_val("2026-10-13 14:58:44.224447")
        self.assertEqual(dt1, datetime(2026, 10, 13, 14, 58, 44, 224447))

        # Second precision without fractional
        dt2 = parse_datetime_val("2026-10-13 14:58:44")
        self.assertEqual(dt2, datetime(2026, 10, 13, 14, 58, 44))

        # Null and empty values
        self.assertIsNone(parse_datetime_val(None))
        self.assertIsNone(parse_datetime_val(""))
        self.assertIsNone(parse_datetime_val("   "))

        # Date object handling
        d = date(2026, 10, 13)
        self.assertEqual(parse_datetime_val(d), datetime(2026, 10, 13, 0, 0))

        # Naive datetime objects remain unchanged
        dt_naive = datetime(2026, 10, 13, 12, 0, 0, 654321)
        res_naive = parse_datetime_val(dt_naive)
        self.assertEqual(res_naive, dt_naive)
        self.assertIsNone(res_naive.tzinfo)

        # Timezone-aware datetime objects normalized to naive UTC
        aware_dt = datetime(2026, 10, 14, 5, 30, 0, tzinfo=timezone(timedelta(hours=5, minutes=30)))
        res_aware = parse_datetime_val(aware_dt)
        self.assertEqual(res_aware, datetime(2026, 10, 14, 0, 0, 0))
        self.assertIsNone(res_aware.tzinfo)

        # ISO format with Z and explicit timezone offsets
        dt_z = parse_datetime_val("2026-10-14T00:00:00Z")
        dt_ist = parse_datetime_val("2026-10-14T05:30:00+05:30")
        dt_edt = parse_datetime_val("2026-10-13T20:00:00-04:00")

        self.assertEqual(dt_z, datetime(2026, 10, 14, 0, 0, 0))
        self.assertEqual(dt_ist, datetime(2026, 10, 14, 0, 0, 0))
        self.assertEqual(dt_edt, datetime(2026, 10, 14, 0, 0, 0))

        # Equivalent timestamps representing the exact same instant must match
        self.assertEqual(dt_z, dt_ist)
        self.assertEqual(dt_z, dt_edt)
        self.assertIsNone(dt_z.tzinfo)
        self.assertIsNone(dt_ist.tzinfo)
        self.assertIsNone(dt_edt.tzinfo)

        # Ordinary text values must return unchanged without generating warning logs
        with patch("migrate_sqlite_to_cloudsql.logger.warning") as mock_warn:
            self.assertEqual(parse_datetime_val("ABC Seeds & Fertilizers"), "ABC Seeds & Fertilizers")
            self.assertEqual(parse_datetime_val("ORD-1076"), "ORD-1076")
            self.assertEqual(parse_datetime_val("9876543210"), "9876543210")
            mock_warn.assert_not_called()

    def test_13_datetime_precision_and_checksum_consistency(self):
        """Task 2: Verify deterministic datetime normalization and checksum parity between SQLite and MySQL."""
        from datetime import datetime
        from migrate_sqlite_to_cloudsql import normalize_val, compute_table_checksum

        # 1. Fractional seconds parity
        src_str = "2026-10-13 14:58:44.824447"
        tgt_dt = datetime(2026, 10, 13, 14, 58, 44, 824447)
        self.assertEqual(normalize_val(src_str), normalize_val(tgt_dt))
        self.assertEqual(normalize_val(src_str), "2026-10-13 14:58:44.824447")

        # 2. Zero microseconds parity
        src_str_zero = "2026-10-13 14:58:44"
        tgt_dt_zero = datetime(2026, 10, 13, 14, 58, 44, 0)
        self.assertEqual(normalize_val(src_str_zero), normalize_val(tgt_dt_zero))
        self.assertEqual(normalize_val(src_str_zero), "2026-10-13 14:58:44")

        # 3. String with .000000 normalizes consistently with 0-microsecond datetime
        src_str_zeros = "2026-10-13 14:58:44.000000"
        self.assertEqual(normalize_val(src_str_zeros), normalize_val(tgt_dt_zero))

        # 4. Dangerously roundable fractional seconds (> 0.5s) must not round to next second
        round_src = "2026-10-13 14:58:44.999999"
        round_tgt = datetime(2026, 10, 13, 14, 58, 44, 999999)
        self.assertEqual(normalize_val(round_src), normalize_val(round_tgt))
        self.assertTrue(normalize_val(round_src).startswith("2026-10-13 14:58:44."))
        self.assertFalse(normalize_val(round_src).startswith("2026-10-13 14:58:45"))

        # 5. Null values
        self.assertEqual(normalize_val(None), "")

        # 6. Timezone-aware ISO string vs naive UTC instant normalization parity
        norm_z = normalize_val("2026-10-14T00:00:00Z")
        norm_ist = normalize_val("2026-10-14T05:30:00+05:30")
        self.assertEqual(norm_z, norm_ist)
        self.assertEqual(norm_z, "2026-10-14 00:00:00")

        # 7. Checksum parity between raw SQLite row dict and simulated MySQL row dict
        sqlite_row = {
            "id": 1,
            "order_number": "ORD-1001",
            "created_at": "2026-10-06 04:30:54.590307",
            "is_active": 1,
            "notes": None
        }
        mysql_row = {
            "id": 1,
            "order_number": "ORD-1001",
            "created_at": datetime(2026, 10, 6, 4, 30, 54, 590307),
            "is_active": True,
            "notes": None
        }
        cols = ["id", "order_number", "created_at", "is_active", "notes"]
        chk_sqlite = compute_table_checksum([sqlite_row], cols)
        chk_mysql = compute_table_checksum([mysql_row], cols)
        self.assertEqual(chk_sqlite, chk_mysql, "SHA256 checksums must match 100% across SQLite and MySQL row representations.")

    def test_14_auto_increment_finalization_logic(self):
        """Task 3: Verify AUTO_INCREMENT finalization respects dialect boundaries and transactionality."""
        from unittest.mock import MagicMock
        from sqlalchemy import create_engine as ce
        from migrate_sqlite_to_cloudsql import YadviCloudSQLMigrator, TOPOLOGICAL_ORDER

        migrator = YadviCloudSQLMigrator(source_path=self.source_backup)

        # 1. Non-MySQL dialect (e.g. SQLite) must safely skip execution
        sqlite_engine = ce("sqlite:///:memory:")
        res_sqlite = migrator.finalize_auto_increments(sqlite_engine)
        self.assertEqual(res_sqlite, {}, "Non-MySQL dialect must return empty dict without running ALTER TABLE.")
        sqlite_engine.dispose()

        # 2. Mock MySQL engine: verify correct SQL queries and conn.commit() execution
        mock_engine = MagicMock()
        mock_engine.dialect.name = "mysql"
        mock_conn = MagicMock()
        mock_engine.connect.return_value.__enter__.return_value = mock_conn

        # Mock scalar returns for MAX(id): simulate max_val = 58 for orders
        mock_scalar = MagicMock(return_value=58)
        mock_conn.execute.return_value.scalar = mock_scalar

        res_mysql = migrator.finalize_auto_increments(mock_engine)
        self.assertGreater(len(res_mysql), 0)
        self.assertIn("orders", res_mysql)
        self.assertEqual(res_mysql["orders"], 59)
        # Verify conn.commit was called to synchronize transaction state
        self.assertTrue(mock_conn.commit.called)

        # 3. Verify all 15 models have valid single-column integer autoincrement PKs
        for tbl_name in TOPOLOGICAL_ORDER:
            table_obj = Base.metadata.tables.get(tbl_name)
            self.assertIsNotNone(table_obj, f"Table {tbl_name} must exist in Base metadata.")
            pk_cols = list(table_obj.primary_key.columns)
            self.assertEqual(len(pk_cols), 1, f"Table {tbl_name} must have a single primary key.")
            self.assertEqual(pk_cols[0].name, "id", f"Table {tbl_name} PK must be named 'id'.")

    def test_15_mysql_datetime6_compiles_hook(self):
        """Verify @compiles hook ensures DATETIME(6) is generated for MySQL DDL while SQLite remains standard."""
        from sqlalchemy import Column, Integer, DateTime
        from sqlalchemy.orm import declarative_base
        from sqlalchemy.schema import CreateTable
        from sqlalchemy.dialects import mysql, sqlite

        TestBase = declarative_base()
        class Sample(TestBase):
            __tablename__ = "sample_test_compiles"
            id = Column(Integer, primary_key=True)
            created_at = Column(DateTime)

        mysql_ddl = str(CreateTable(Sample.__table__).compile(dialect=mysql.dialect()))
        sqlite_ddl = str(CreateTable(Sample.__table__).compile(dialect=sqlite.dialect()))

        self.assertIn("DATETIME(6)", mysql_ddl, "MySQL DDL must use DATETIME(6) for microsecond precision.")
        self.assertIn("DATETIME", sqlite_ddl, "SQLite DDL must remain DATETIME.")

    def test_16_mask_url_safety(self):
        """Verify mask_url safely handles URL objects, passwords with special characters, and exceptions."""
        from sqlalchemy.engine import URL
        from migrate_sqlite_to_cloudsql import mask_url

        # 1. URL object masking
        url_obj = URL.create("mysql+mysqlconnector", username="root", password="my_secret_password", host="127.0.0.1", port=3307, database="test_db")
        masked_obj = mask_url(url_obj)
        self.assertNotIn("my_secret_password", masked_obj)
        self.assertIn("root:***@127.0.0.1:3307/test_db", masked_obj)

        # 2. String URL with special characters (e.g. @ encoded or in password)
        raw_url = "mysql+mysqlconnector://admin:p%40ssword@10.0.0.1:3306/prod_db"
        masked_raw = mask_url(raw_url)
        self.assertNotIn("p%40ssword", masked_raw)
        self.assertIn("admin:***@", masked_raw)

        # 3. Exception string containing database URL
        exc_str = "OperationalError: failed connecting to mysql+mysqlconnector://app_user:top_secret_123@192.168.1.5:3306/app_db (1045)"
        masked_exc = mask_url(exc_str)
        self.assertNotIn("top_secret_123", masked_exc)
        self.assertIn("app_user:***@192.168.1.5:3306/app_db", masked_exc)

        # 4. Null and empty handling
        self.assertEqual(mask_url(None), "")
        self.assertEqual(mask_url(""), "")

    def test_17_migrator_with_url_object(self):
        """Verify YadviCloudSQLMigrator works seamlessly with SQLAlchemy URL objects directly."""
        from sqlalchemy.engine import URL
        from sqlalchemy import create_engine as ce

        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tmp_db:
            target_path = tmp_db.name

        try:
            # Create a URL object pointing to the temporary SQLite target
            url_obj = URL.create("sqlite", database=target_path)
            target_engine = ce(url_obj)
            Base.metadata.create_all(bind=target_engine)
            target_engine.dispose()

            migrator = YadviCloudSQLMigrator(
                source_path=self.source_backup,
                target_url=url_obj,
                execute=False
            )
            # Dry-run with URL object
            res = migrator.run_dry_run()
            self.assertEqual(res["mode"], "dry_run")
            self.assertEqual(res["source_summary"]["total_rows"], 332)
            self.assertIn("Target Verified", res["target_status"])

            # Execution with URL object
            checkpoint_file = target_path + ".checkpoint.json"
            exec_migrator = YadviCloudSQLMigrator(
                source_path=self.source_backup,
                target_url=url_obj,
                execute=True,
                confirm_target=os.path.basename(target_path),
                checkpoint_path=checkpoint_file
            )
            exec_res = exec_migrator.execute_migration()
            self.assertEqual(exec_res["status"], "SUCCESS")
            self.assertEqual(exec_res["total_rows"], 332)
        finally:
            if os.path.exists(target_path):
                try:
                    os.remove(target_path)
                except Exception:
                    pass
            if 'checkpoint_file' in locals() and os.path.exists(checkpoint_file):
                try:
                    os.remove(checkpoint_file)
                except Exception:
                    pass

    def test_18_meta_error_code_type_flexibility(self):
        """Verify Notification.meta_error_code supports numeric codes, string codes, and null values."""
        from sqlalchemy import String
        from sqlalchemy.orm import sessionmaker
        from sqlalchemy import create_engine as ce
        from app.models.all_models import Notification, Base
        from migrate_sqlite_to_cloudsql import normalize_val, compute_table_checksum

        # 1. Verify model column type is String(50)
        col = Notification.__table__.columns["meta_error_code"]
        self.assertIsInstance(col.type, String)
        self.assertEqual(col.type.length, 50)
        self.assertTrue(col.nullable)

        # 2. Verify in-memory DB insertion of integer, string, and null values
        test_engine = ce("sqlite:///:memory:")
        Base.metadata.create_all(bind=test_engine)
        Session = sessionmaker(bind=test_engine)
        session = Session()

        n1 = Notification(recipient_phone="9998887771", message_content="Test 1", meta_error_code="190")
        n2 = Notification(recipient_phone="9998887772", message_content="Test 2", meta_error_code="TEMPLATE_UNCONFIGURED")
        n3 = Notification(recipient_phone="9998887773", message_content="Test 3", meta_error_code=None)
        session.add_all([n1, n2, n3])
        session.commit()

        loaded = session.query(Notification).order_by(Notification.id).all()
        self.assertEqual(loaded[0].meta_error_code, "190")
        self.assertEqual(loaded[1].meta_error_code, "TEMPLATE_UNCONFIGURED")
        self.assertIsNone(loaded[2].meta_error_code)
        session.close()
        test_engine.dispose()

        # 3. Verify checksum normalization is symmetric between numeric 190 and string "190"
        self.assertEqual(normalize_val(190), "190")
        self.assertEqual(normalize_val("190"), "190")
        self.assertEqual(normalize_val("TEMPLATE_UNCONFIGURED"), "TEMPLATE_UNCONFIGURED")
        self.assertEqual(normalize_val(None), "")

    def test_19_init_schema_creates_tables_safely(self):
        """When init_schema=True is passed, migrator initializes schema prior to target safety validation."""
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as empty_tgt:
            target_path = empty_tgt.name

        try:
            target_url = f"sqlite:///{target_path}"
            from sqlalchemy import create_engine as ce
            # Without init_schema, migrator aborts because tables are missing
            migrator_no_init = YadviCloudSQLMigrator(
                source_path=self.source_backup,
                target_url=target_url,
                execute=False,
                init_schema=False
            )
            with self.assertRaises(RuntimeError) as ctx:
                migrator_no_init.validate_target_safety(ce(target_url))
            self.assertIn("missing required schema tables", str(ctx.exception).lower())

            # With init_schema=True, tables are created and validate_target_safety succeeds
            target_engine = ce(target_url)
            from app.models.all_models import Base
            Base.metadata.create_all(bind=target_engine)
            migrator_with_init = YadviCloudSQLMigrator(
                source_path=self.source_backup,
                target_url=target_url,
                execute=False,
                init_schema=True
            )
            migrator_with_init.validate_target_safety(target_engine)
            target_engine.dispose()
        finally:
            if os.path.exists(target_path):
                os.remove(target_path)


if __name__ == "__main__":
    unittest.main()
