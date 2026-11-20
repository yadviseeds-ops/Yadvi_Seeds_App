-- Migration: Add Financial Details (Debt Taken, Debt Repaid, Total Balance) to shop_owners
-- Target Database: MySQL (Cloud SQL) / SQLite
-- Date: 2026-11-19
-- Author: Antigravity Assistant

-- 1. Add debt_taken column (default 0.00, exact 2 decimal precision)
ALTER TABLE shop_owners ADD COLUMN debt_taken DECIMAL(14, 2) NOT NULL DEFAULT 0.00;

-- 2. Add debt_repaid column (default 0.00, exact 2 decimal precision)
ALTER TABLE shop_owners ADD COLUMN debt_repaid DECIMAL(14, 2) NOT NULL DEFAULT 0.00;

-- 3. Add total_balance column (default 0.00, calculated as debt_taken - debt_repaid)
ALTER TABLE shop_owners ADD COLUMN total_balance DECIMAL(14, 2) NOT NULL DEFAULT 0.00;
