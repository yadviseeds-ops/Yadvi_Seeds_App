#!/usr/bin/env python3
"""
Yadvi Seeds — Production-Safe SQLite-to-Cloud-SQL Migration Tool
Location: backend/migrate_sqlite_to_cloudsql.py

Features:
- Dry-run by default; requires explicit --execute and --confirm-target <DB_NAME>
- Non-destructive: NEVER issues DROP TABLE, DROP DATABASE, or TRUNCATE TABLE
- Validates source SQLite backup integrity (PRAGMA integrity_check) in read-only mode
- Pre-validates source foreign-key consistency (0 orphan records required)
- Strict topological dependency-ordered loading without bypassing foreign-key checks
- Verifies target table emptiness before writing (no automatic overwriting)
- Deterministic per-table data checksum validation (SHA-256)
- Resets MySQL AUTO_INCREMENT only for tables with auto-increment primary keys as a separate finalization stage
- Masks credentials and connection secrets in all logs and outputs
- Explicit checkpointing and recovery tracking
"""

import os
import sys
import re
import json
import hashlib
import logging
import argparse
import sqlite3
from datetime import datetime, date, timezone
from typing import Dict, List, Any, Optional, Tuple, Union

from sqlalchemy import create_engine, text, inspect, DateTime, Date, Integer, Float
from sqlalchemy.engine import Engine, make_url, URL
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.dialects import mysql

# Ensure backend root is in python path
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app.models.all_models import Base

# Ensure MySQL tables generated via Base.metadata.create_all() retain full microsecond precision
@compiles(DateTime, "mysql")
def compile_datetime_mysql(type_, compiler, **kw):
    return "DATETIME(6)"

# Ensure MySQL tables generated via Base.metadata.create_all() retain full 64-bit double precision for GPS coordinates
@compiles(Float, "mysql")
def compile_float_mysql(type_, compiler, **kw):
    return "DOUBLE"


# Strict topological dependency order (parents before children)
TOPOLOGICAL_ORDER = [
    "roles",             # 1. Base RBAC
    "users",             # 2. Users (FK -> roles)
    "field_executives",  # 3. Field Force (FK -> users)
    "shop_owners",       # 4. Dealer Network (FK -> users, field_executives)
    "fcm_device_tokens", # 5. FCM Tokens (FK -> users)
    "products",          # 6. Seed Catalog (independent)
    "inventory",         # 7. Stock Lots (FK -> products)
    "orders",            # 8. Bookings (FK -> shop_owners, field_executives)
    "order_items",       # 9. Order Details (FK -> orders, products)
    "shipments",         # 10. Logistics (FK -> orders)
    "visits",            # 11. Geo-tagged Visits (FK -> field_executives, shop_owners)
    "attendance",        # 12. FE Attendance (FK -> field_executives)
    "fe_locations",      # 13. GPS Trail (FK -> field_executives)
    "eod_reports",       # 14. EOD Summaries (FK -> field_executives)
    "notifications",     # 15. Dispatches & WhatsApp Receipts (independent)
]

# Explicit foreign key rules for pre-flight source integrity validation
FOREIGN_KEY_RULES = [
    ("users", "role_id", "roles", "id"),
    ("field_executives", "user_id", "users", "id"),
    ("shop_owners", "user_id", "users", "id"),
    ("shop_owners", "assigned_executive_id", "field_executives", "id"),
    ("fcm_device_tokens", "user_id", "users", "id"),
    ("inventory", "product_id", "products", "id"),
    ("orders", "shop_id", "shop_owners", "id"),
    ("orders", "assigned_executive_id", "field_executives", "id"),
    ("order_items", "order_id", "orders", "id"),
    ("order_items", "product_id", "products", "id"),
    ("shipments", "order_id", "orders", "id"),
    ("visits", "executive_id", "field_executives", "id"),
    ("visits", "shop_id", "shop_owners", "id"),
    ("attendance", "executive_id", "field_executives", "id"),
    ("fe_locations", "executive_id", "field_executives", "id"),
    ("eod_reports", "executive_id", "field_executives", "id"),
]

logger = logging.getLogger("yadvi_migrator")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")


def mask_url(url: Any) -> str:
    """Masks credentials in database URLs for safe logging."""
    if not url:
        return ""
    if isinstance(url, URL):
        return url.render_as_string(hide_password=True)
    text_val = str(url)
    try:
        if "://" in text_val and "@" in text_val and "\n" not in text_val and " " not in text_val:
            return make_url(text_val).render_as_string(hide_password=True)
    except Exception:
        pass
    return re.sub(r"://([^:]+):([^@]+)@", r"://\1:***@", text_val)


def parse_datetime_val(v: Any) -> Optional[datetime]:
    """
    Parses a datetime representation into a Python datetime object safely.
    Handles ISO strings, SQLite strings, datetime objects, dates, and nullable values.
    Preserves full microsecond precision and normalizes timezone-aware timestamps to naive UTC.
    """
    if v is None:
        return None
    if isinstance(v, datetime):
        if v.tzinfo is not None:
            return v.astimezone(timezone.utc).replace(tzinfo=None)
        return v
    if isinstance(v, date):
        return datetime(v.year, v.month, v.day)
    if isinstance(v, str):
        cleaned = v.strip()
        if not cleaned:
            return None
        if cleaned.endswith("Z"):
            cleaned = cleaned[:-1] + "+00:00"
        try:
            dt = datetime.fromisoformat(cleaned)
            if dt.tzinfo is not None:
                dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
            return dt
        except ValueError:
            pass
        for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
            try:
                dt = datetime.strptime(cleaned, fmt)
                return dt
            except ValueError:
                pass
        return v
    return v


def normalize_val(v: Any) -> str:
    """
    Normalizes database values into canonical strings for deterministic hashing.
    Ensures symmetric, deterministic comparison between SQLite strings/types and MySQL types:
    - None -> ""
    - Booleans -> "1" / "0"
    - Integers / Floats -> canonical string
    - Datetimes -> ISO representation with microsecond (%Y-%m-%d %H:%M:%S.%f) if microsecond > 0,
      else second precision (%Y-%m-%d %H:%M:%S).
    """
    if v is None:
        return ""
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (datetime, date)):
        dt = v if isinstance(v, datetime) else datetime(v.year, v.month, v.day)
        if isinstance(dt, datetime) and dt.tzinfo is not None:
            dt = dt.astimezone(timezone.utc).replace(tzinfo=None)
        return dt.strftime("%Y-%m-%d %H:%M:%S.%f") if dt.microsecond else dt.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(v, str):
        parsed = parse_datetime_val(v)
        if isinstance(parsed, datetime):
            return parsed.strftime("%Y-%m-%d %H:%M:%S.%f") if parsed.microsecond else parsed.strftime("%Y-%m-%d %H:%M:%S")
        return v
    return str(v)


def compute_table_checksum(row_dicts: List[Dict[str, Any]], cols: List[str]) -> str:
    """Computes a deterministic SHA-256 checksum across rows and columns sorted alphabetically."""
    sorted_cols = sorted(cols)
    h = hashlib.sha256()
    for r in row_dicts:
        parts = [normalize_val(r.get(c)) for c in sorted_cols]
        h.update("|".join(parts).encode("utf-8"))
        h.update(b"\n")
    return h.hexdigest()


class YadviCloudSQLMigrator:
    def __init__(
        self,
        source_path: str,
        target_url: Optional[Union[str, URL]] = None,
        execute: bool = False,
        confirm_target: Optional[str] = None,
        checkpoint_path: Optional[str] = None,
        init_schema: bool = False
    ):
        self.source_path = os.path.abspath(source_path)
        self.target_url = target_url
        self.execute = execute
        self.confirm_target = confirm_target
        self.checkpoint_path = checkpoint_path or os.path.join(BACKEND_DIR, "migration_checkpoint.json")
        self.init_schema = init_schema
        self.source_counts: Dict[str, int] = {}
        self.source_checksums: Dict[str, str] = {}
        self.target_counts: Dict[str, int] = {}
        self.target_checksums: Dict[str, str] = {}
        self.checkpoint_data: Dict[str, Any] = {}

    def _save_checkpoint(self, stage: str, details: Dict[str, Any]):
        """Persists migration progress to a checkpoint file."""
        self.checkpoint_data = {
            "stage": stage,
            "timestamp": datetime.utcnow().isoformat(),
            "source_path": self.source_path,
            "details": details
        }
        try:
            with open(self.checkpoint_path, "w", encoding="utf-8") as f:
                json.dump(self.checkpoint_data, f, indent=2)
            logger.info(f"Checkpoint saved: Stage='{stage}' -> {self.checkpoint_path}")
        except Exception as e:
            logger.warning(f"Unable to write checkpoint file: {e}")

    def validate_source(self) -> Dict[str, Any]:
        """Validates source backup file existence, SQLite integrity, and FK relationships."""
        if not os.path.exists(self.source_path):
            raise FileNotFoundError(f"Source database backup not found: {self.source_path}")

        src_conn = sqlite3.connect(f"file:{self.source_path}?mode=ro", uri=True)
        cur = src_conn.cursor()

        # 1. PRAGMA integrity_check
        cur.execute("PRAGMA integrity_check;")
        res = cur.fetchall()
        if not res or res[0][0] != "ok":
            src_conn.close()
            raise ValueError(f"Source SQLite backup failed integrity check: {res}")
        logger.info(f"Source backup integrity verified: 'ok'")

        # 2. Check table presence and row counts
        cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
        existing_tables = set(r[0] for r in cur.fetchall())
        missing_tables = [t for t in TOPOLOGICAL_ORDER if t not in existing_tables]
        if missing_tables:
            src_conn.close()
            raise ValueError(f"Source database is missing required tables: {missing_tables}")

        total_rows = 0
        for table in TOPOLOGICAL_ORDER:
            cur.execute(f"PRAGMA table_info([{table}])")
            cols = [c[1] for c in cur.fetchall()]

            # Sort deterministically by primary key or first column
            cur.execute(f"SELECT * FROM [{table}] ORDER BY [{cols[0]}] ASC")
            raw_rows = cur.fetchall()
            row_dicts = [dict(zip(cols, r)) for r in raw_rows]
            cnt = len(row_dicts)
            chk = compute_table_checksum(row_dicts, cols)
            self.source_counts[table] = cnt
            self.source_checksums[table] = chk
            total_rows += cnt

        # 3. Explicit Foreign-Key Consistency Checks
        cur.execute("PRAGMA foreign_key_check;")
        builtin_fk_errors = cur.fetchall()
        if builtin_fk_errors:
            src_conn.close()
            raise ValueError(f"Source SQLite foreign key check failed: {builtin_fk_errors}")

        for child_tbl, child_col, parent_tbl, parent_col in FOREIGN_KEY_RULES:
            cur.execute(f"""
                SELECT count(*) FROM [{child_tbl}]
                WHERE [{child_col}] IS NOT NULL
                  AND [{child_col}] NOT IN (SELECT [{parent_col}] FROM [{parent_tbl}])
            """)
            orphan_count = cur.fetchone()[0]
            if orphan_count > 0:
                src_conn.close()
                raise ValueError(
                    f"Foreign key violation in source data: {orphan_count} orphan records in "
                    f"{child_tbl}.{child_col} referencing {parent_tbl}.{parent_col}."
                )

        src_conn.close()
        logger.info(f"Source pre-flight check passed: 15 tables, {total_rows} rows, 0 foreign key violations.")
        return {
            "status": "VALID",
            "total_rows": total_rows,
            "counts": self.source_counts,
            "checksums": self.source_checksums
        }

    def validate_target_safety(self, engine: Engine):
        """Ensures target database exists, has correct tables, and is completely empty."""
        inspector = inspect(engine)
        target_tables = set(inspector.get_table_names())

        missing_tables = [t for t in TOPOLOGICAL_ORDER if t not in target_tables]
        if missing_tables:
            raise RuntimeError(
                f"Target database is missing required schema tables: {missing_tables}. "
                "Initialize the target schema using Base.metadata.create_all() or Alembic prior to data migration."
            )

        # Verify that all source columns exist in target tables
        src_conn = sqlite3.connect(f"file:{self.source_path}?mode=ro", uri=True)
        try:
            src_cur = src_conn.cursor()
            for table in TOPOLOGICAL_ORDER:
                src_cur.execute(f"PRAGMA table_info([{table}])")
                src_cols = set(c[1] for c in src_cur.fetchall())
                tgt_cols = set(c["name"] for c in inspector.get_columns(table))
                missing_cols = src_cols - tgt_cols
                if missing_cols:
                    raise RuntimeError(
                        f"Target schema mismatch: Table '{table}' in target database is missing columns: {missing_cols}"
                    )
        finally:
            src_conn.close()

        # Verify target datetime column precision when connected to MySQL
        if engine.dialect.name == "mysql":
            for table in TOPOLOGICAL_ORDER:
                for col_info in inspector.get_columns(table):
                    col_type = col_info.get("type")
                    if isinstance(col_type, mysql.DATETIME):
                        fsp = getattr(col_type, "fsp", None)
                        if fsp is None or fsp < 6:
                            logger.warning(
                                f"TARGET PRECISION ALERT: Table '{table}' column '{col_info['name']}' has precision "
                                f"DATETIME({fsp or 0}). Source database contains microsecond timestamps. "
                                f"Full microsecond fidelity requires DATETIME(6)."
                            )

        # Check for pre-existing records (Strict Non-Destructive Guard)
        populated_tables = {}
        with engine.connect() as conn:
            for table in TOPOLOGICAL_ORDER:
                cnt = conn.execute(text(f"SELECT count(*) FROM `{table}`")).scalar()
                if cnt > 0:
                    populated_tables[table] = cnt

        if populated_tables:
            raise RuntimeError(
                f"ABORTED: Target database is not clean. The following tables already contain records: "
                f"{populated_tables}. To prevent accidental overwrites or primary key collisions, "
                f"the migration tool refuses to write to a populated database."
            )
        logger.info("Target database schema verified and confirmed completely empty.")

    def run_dry_run(self) -> Dict[str, Any]:
        """Executes full read-only pre-flight inspection and outputs the planned operations."""
        logger.info("=== STARTING DRY-RUN INSPECTION (DEFAULT SAFE MODE) ===")
        source_summary = self.validate_source()

        target_status = "Not Connected"
        if self.target_url:
            masked = mask_url(self.target_url)
            logger.info(f"Connecting to target database for schema inspection: {masked}")
            target_engine = None
            try:
                target_engine = create_engine(self.target_url, pool_pre_ping=True)
                self.validate_target_safety(target_engine)
                target_status = "Target Verified (Clean & Compatible)"
            except Exception as e:
                safe_err = mask_url(str(e))
                logger.warning(f"Target pre-check warning: {safe_err}")
                target_status = f"Target Check Failed: {safe_err}"
            finally:
                if target_engine is not None:
                    target_engine.dispose()

        logger.info("=== DRY-RUN SUMMARY REPORT ===")
        for tbl in TOPOLOGICAL_ORDER:
            cnt = self.source_counts[tbl]
            chk = self.source_checksums[tbl][:12]
            logger.info(f"  Plan: '{tbl:<20}' -> {cnt:>4} records | SHA256: {chk}...")

        logger.info(f"Total Rows Planned: {source_summary['total_rows']}")
        logger.info(f"Target Status: {target_status}")
        logger.info("DRY-RUN COMPLETE: Zero writes executed. No databases or tables were modified.")
        return {
            "mode": "dry_run",
            "source_summary": source_summary,
            "target_status": target_status
        }

    def finalize_auto_increments(self, target_engine: Engine) -> Dict[str, int]:
        """
        Finalizes MySQL AUTO_INCREMENT sequence counters for all tables with integer primary keys.

        CRITICAL ARCHITECTURAL NOTE ON MYSQL DDL TRANSACTIONALITY:
        In MySQL InnoDB, 'ALTER TABLE ... AUTO_INCREMENT = ...' is a DDL statement that causes
        an immediate IMPLICIT COMMIT in the MySQL engine. It CANNOT be rolled back.
        Therefore, this operation is strictly isolated as Stage 4, executing only after
        Stage 2 (transactional DML data insertion) and Stage 3 (full parity & checksum verification)
        have completed successfully.
        """
        dialect_name = target_engine.dialect.name
        auto_inc_resets: Dict[str, int] = {}

        if dialect_name == "mysql":
            with target_engine.connect() as conn:
                for table_name in TOPOLOGICAL_ORDER:
                    table_obj = Base.metadata.tables.get(table_name)
                    if table_obj is not None:
                        pk_cols = list(table_obj.primary_key.columns)
                        if len(pk_cols) == 1 and isinstance(pk_cols[0].type, Integer) and pk_cols[0].autoincrement in (True, "auto"):
                            pk_name = pk_cols[0].name
                            max_val = conn.execute(text(f"SELECT COALESCE(MAX(`{pk_name}`), 0) FROM `{table_name}`")).scalar()
                            next_val = (max_val or 0) + 1
                            conn.execute(text(f"ALTER TABLE `{table_name}` AUTO_INCREMENT = {next_val};"))
                            conn.commit()  # Synchronize SQLAlchemy 2.0 connection transaction state
                            auto_inc_resets[table_name] = next_val
                            logger.info(f"  Auto-Increment Reset: '{table_name}' set to {next_val}.")
        else:
            logger.info(f"Dialect '{dialect_name}' detected. Skipping MySQL-specific ALTER TABLE AUTO_INCREMENT.")

        return auto_inc_resets

    def execute_migration(self) -> Dict[str, Any]:
        """
        Executes the verified data migration:
        Stage 1: Pre-flight source & target validation
        Stage 2: DML data load wrapped in a single atomic transaction
        Stage 3: Post-insert row count and deterministic SHA-256 checksum validation
        Stage 4: Auto-increment sequence finalization
        """
        if not self.execute:
            return self.run_dry_run()

        if not self.target_url:
            raise ValueError("Target database URL (--target-url) is required for execution.")

        # Confirmation Gate Verification
        masked_target = mask_url(self.target_url)
        url_obj = make_url(self.target_url)
        raw_db = url_obj.database or ""
        parsed_db = os.path.basename(raw_db) if raw_db else ""
        confirmed = self.confirm_target.strip() if self.confirm_target else ""

        if not confirmed or (confirmed != parsed_db and confirmed != raw_db):
            raise ValueError(
                f"SAFETY INTERVENTION: Target confirmation mismatch. "
                f"Target URL points to database '{parsed_db}', but --confirm-target received '{confirmed}'. "
                f"Execution blocked to prevent unintended database writes."
            )

        logger.info(f"=== INITIATING LIVE MIGRATION WRITE: Target='{parsed_db}' ===")
        logger.info(f"Target URI: {masked_target}")

        # Stage 1: Pre-flight validation
        self.validate_source()
        target_engine = create_engine(self.target_url, pool_pre_ping=True)
        try:
            if self.init_schema:
                logger.info("Initializing target database schema via Base.metadata.create_all()...")
                Base.metadata.create_all(bind=target_engine)
                logger.info("Target database schema initialized successfully.")

            self.validate_target_safety(target_engine)
            self._save_checkpoint("PRE_FLIGHT_PASSED", {"target_db": parsed_db})

            # Stage 2: Transactional Data Insertion
            logger.info("Stage 2: Executing transactional data insertion in topological order...")
            src_conn = sqlite3.connect(f"file:{self.source_path}?mode=ro", uri=True)
            src_cur = src_conn.cursor()

            try:
                with target_engine.begin() as conn:
                    for table in TOPOLOGICAL_ORDER:
                        table_obj = Base.metadata.tables.get(table)
                        src_cur.execute(f"PRAGMA table_info([{table}])")
                        cols = [c[1] for c in src_cur.fetchall()]

                        src_cur.execute(f"SELECT * FROM [{table}] ORDER BY [{cols[0]}] ASC")
                        rows = src_cur.fetchall()

                        if not rows:
                            logger.info(f"  Table '{table}': 0 rows (skipped).")
                            continue

                        # Discover all DateTime columns from SQLAlchemy model metadata by type
                        dt_cols = set()
                        if table_obj is not None:
                            for col_name in cols:
                                col_obj = table_obj.columns.get(col_name)
                                if col_obj is not None and isinstance(col_obj.type, (DateTime, Date)):
                                    dt_cols.add(col_name)

                        cols_clause = ", ".join([f"`{c}`" for c in cols])
                        params_clause = ", ".join([f":{c}" for c in cols])
                        stmt = text(f"INSERT INTO `{table}` ({cols_clause}) VALUES ({params_clause})")

                        batch = []
                        for row in rows:
                            row_dict = {}
                            for idx, col in enumerate(cols):
                                val = row[idx]
                                # Correctly parse datetime values using metadata discovery
                                if col in dt_cols and val is not None:
                                    val = parse_datetime_val(val)
                                row_dict[col] = val
                            batch.append(row_dict)

                        conn.execute(stmt, batch)
                        logger.info(f"  Table '{table}': {len(batch)} rows inserted successfully.")

                logger.info("Stage 2 Complete: Transaction committed successfully.")
                self._save_checkpoint("DML_COMMITTED", {"status": "SUCCESS"})

            except Exception as exc:
                safe_err = mask_url(str(exc))
                logger.critical(f"FATAL: Migration failed during Stage 2 insertion: {safe_err}. Transaction rolled back.")
                self._save_checkpoint("DML_FAILED", {"error": safe_err})
                raise RuntimeError(f"Migration insertion failed and was rolled back cleanly: {safe_err}") from exc
            finally:
                src_conn.close()

            # Stage 3: Post-Insert Parity & Checksum Validation
            logger.info("Stage 3: Validating post-insert parity and deterministic checksums...")
            parity_failures = []
            with target_engine.connect() as conn:
                for table in TOPOLOGICAL_ORDER:
                    # Query target rows
                    inspector = inspect(target_engine)
                    pk_cols = inspector.get_pk_constraint(table).get("constrained_columns", [])
                    order_col = pk_cols[0] if pk_cols else "id"

                    tgt_cols = [c["name"] for c in inspector.get_columns(table)]
                    tgt_result = conn.execute(text(f"SELECT * FROM `{table}` ORDER BY `{order_col}` ASC"))
                    tgt_rows = [dict(r._mapping) for r in tgt_result]
                    tgt_cnt = len(tgt_rows)
                    tgt_chk = compute_table_checksum(tgt_rows, tgt_cols)

                    self.target_counts[table] = tgt_cnt
                    self.target_checksums[table] = tgt_chk

                    src_cnt = self.source_counts[table]
                    src_chk = self.source_checksums[table]

                    count_match = (src_cnt == tgt_cnt)
                    chk_match = (src_chk == tgt_chk)

                    if not count_match or not chk_match:
                        parity_failures.append(table)
                        logger.error(
                            f"PARITY MISMATCH: '{table}' | Count: {src_cnt} vs {tgt_cnt} | "
                            f"Checksum: {src_chk[:8]} vs {tgt_chk[:8]}"
                        )
                    else:
                        logger.info(f"  Parity OK: '{table:<20}' | Rows: {tgt_cnt:>4} | SHA256: {tgt_chk[:12]}...")

            if parity_failures:
                self._save_checkpoint("VALIDATION_FAILED", {"failed_tables": parity_failures})
                raise RuntimeError(f"POST-INSERT VALIDATION FAILED: Data parity check failed on tables: {parity_failures}")

            logger.info("Stage 3 Complete: All 15 tables matched 100% of rows and SHA-256 checksums.")
            self._save_checkpoint("CHECKSUM_VERIFIED", {"status": "SUCCESS"})

            # Stage 4: Auto-Increment Finalization (MySQL Only)
            logger.info("Stage 4: Finalizing auto-increment sequences...")
            auto_inc_resets = self.finalize_auto_increments(target_engine)
            self._save_checkpoint("FINALIZED", {"auto_increments": auto_inc_resets})
            logger.info("=== MIGRATION COMPLETED SUCCESSFULLY WITH 100% VERIFICATION ===")

            return {
                "status": "SUCCESS",
                "tables_migrated": len(TOPOLOGICAL_ORDER),
                "total_rows": sum(self.target_counts.values()),
                "auto_increments": auto_inc_resets
            }
        finally:
            target_engine.dispose()


def parse_args():
    parser = argparse.ArgumentParser(
        description="Yadvi Seeds Production-Safe SQLite to Cloud SQL Migration Tool"
    )
    default_backup = os.path.join(BACKEND_DIR, "backups", "yadvi_seeds_backup_20261013_223421.db")
    parser.add_argument(
        "--source",
        default=default_backup,
        help=f"Path to verified source SQLite backup (default: {default_backup})"
    )
    parser.add_argument(
        "--target-url",
        default=os.getenv("TARGET_DATABASE_URL", None),
        help="Target database SQLAlchemy connection URL (can also be set via TARGET_DATABASE_URL env var)"
    )
    parser.add_argument(
        "--execute",
        action="store_true",
        default=False,
        help="Execute the live migration write (defaults to False / Dry-Run)"
    )
    parser.add_argument(
        "--confirm-target",
        default=None,
        help="Mandatory target database name confirmation required when --execute is specified"
    )
    parser.add_argument(
        "--checkpoint-file",
        default=None,
        help="Optional path for migration progress checkpoint JSON file"
    )
    parser.add_argument(
        "--init-schema",
        action="store_true",
        default=False,
        help="Initialize target schema tables via Base.metadata.create_all() prior to validation/insertion"
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    migrator = YadviCloudSQLMigrator(
        source_path=args.source,
        target_url=args.target_url,
        execute=args.execute,
        confirm_target=args.confirm_target,
        checkpoint_path=args.checkpoint_file,
        init_schema=args.init_schema
    )

    try:
        if args.execute:
            migrator.execute_migration()
        else:
            migrator.run_dry_run()
    except Exception as e:
        logger.error(f"Migration process halted: {e}")
        sys.exit(1)
