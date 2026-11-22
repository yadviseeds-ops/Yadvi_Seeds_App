-- Migration: Create whatsapp_outbox Table for Durable Outbox Messaging
-- Target Database: Google Cloud SQL MySQL 8.0 (InnoDB) / Compatible with SQLite
-- Date: 2026-11-23
-- Baseline Commit: 1b9b813
-- Model Reference: backend/app/models/all_models.py (WhatsAppOutbox)
-- Description:
--   Creates the durable database-backed transactional outbox table for
--   asynchronous, reliable Gupshup WhatsApp notification dispatch.
--   Enforces a strict 1:1 relationship with orders (unique order_id constraint)
--   and provides targeted indexes for worker candidate selection, retry scheduling,
--   and crash/stale-lock recovery.

CREATE TABLE IF NOT EXISTS whatsapp_outbox (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    order_number VARCHAR(50) NOT NULL,
    recipient_phone VARCHAR(20) NOT NULL,
    template_id VARCHAR(100) NULL,
    template_name VARCHAR(100) NOT NULL,
    payload_json LONGTEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Pending',
    retry_count INT NOT NULL DEFAULT 0,
    max_retries INT NOT NULL DEFAULT 3,
    next_retry_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    locked_at DATETIME(6) NULL,
    last_error TEXT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),

    -- Unique 1:1 order constraint (serves as the primary index for foreign key & order lookups)
    CONSTRAINT uq_whatsapp_outbox_order_id UNIQUE (order_id),

    -- Foreign Key constraint referencing orders.id with cascading delete
    CONSTRAINT fk_whatsapp_outbox_orders FOREIGN KEY (order_id)
        REFERENCES orders (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    -- Lookup index for order number
    INDEX idx_whatsapp_outbox_order_number (order_number),

    -- Composite index for atomic worker candidate claiming (status IN ('Pending', 'Retry') AND next_retry_at <= now)
    INDEX idx_whatsapp_outbox_worker_schedule (status, next_retry_at),

    -- Composite index for worker stale-lock recovery (status = 'Processing' AND locked_at <= stale_threshold)
    INDEX idx_whatsapp_outbox_stale_lock (status, locked_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Rollback Procedure:
-- To safely roll back this migration, execute:
--   DROP TABLE IF EXISTS whatsapp_outbox;
