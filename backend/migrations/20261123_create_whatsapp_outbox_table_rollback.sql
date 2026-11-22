-- Rollback Migration: Drop whatsapp_outbox Table
-- Target Database: Google Cloud SQL MySQL 8.0 (InnoDB) / SQLite
-- Date: 2026-11-23
-- Corresponding Forward Migration: 20261123_create_whatsapp_outbox_table.sql
-- Description:
--   Safely drops the whatsapp_outbox table. Existing orders and notification records
--   in the `orders` and `notifications` tables remain completely unaffected and preserved.

DROP TABLE IF EXISTS whatsapp_outbox;
