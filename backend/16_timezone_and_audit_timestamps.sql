-- =================================================================
-- SafeChit SQL Migration 16: Timezone & Audit Timestamps (UTC Single Source of Truth)
-- File: backend/16_timezone_and_audit_timestamps.sql
-- =================================================================

-- 1. Table: chit_payments
-- Ensure timestamps are stored with timezone (UTC) and created_at defaults to server NOW()
ALTER TABLE public.chit_payments 
    ALTER COLUMN created_at TYPE TIMESTAMPTZ,
    ALTER COLUMN created_at SET DEFAULT NOW();

ALTER TABLE public.chit_payments 
    ALTER COLUMN completed_at TYPE TIMESTAMPTZ;

-- 2. Table: digital_agreements
ALTER TABLE public.digital_agreements 
    ALTER COLUMN created_at TYPE TIMESTAMPTZ,
    ALTER COLUMN created_at SET DEFAULT NOW();

ALTER TABLE public.digital_agreements 
    ALTER COLUMN foreman_signed_at TYPE TIMESTAMPTZ;

ALTER TABLE public.digital_agreements 
    ALTER COLUMN member_signed_at TYPE TIMESTAMPTZ;

-- 3. Table: guarantee_requests
ALTER TABLE public.guarantee_requests 
    ALTER COLUMN created_at TYPE TIMESTAMPTZ,
    ALTER COLUMN created_at SET DEFAULT NOW();

ALTER TABLE public.guarantee_requests 
    ALTER COLUMN responded_at TYPE TIMESTAMPTZ;

-- 4. Table: chit_join_requests
ALTER TABLE public.chit_join_requests 
    ALTER COLUMN created_at TYPE TIMESTAMPTZ,
    ALTER COLUMN created_at SET DEFAULT NOW();

-- 5. Table: security_deposits
ALTER TABLE public.security_deposits 
    ALTER COLUMN created_at TYPE TIMESTAMPTZ,
    ALTER COLUMN created_at SET DEFAULT NOW();

ALTER TABLE public.security_deposits 
    ALTER COLUMN updated_at TYPE TIMESTAMPTZ,
    ALTER COLUMN updated_at SET DEFAULT NOW();

-- 6. Table: deposit_transactions
ALTER TABLE public.deposit_transactions 
    ALTER COLUMN created_at TYPE TIMESTAMPTZ,
    ALTER COLUMN created_at SET DEFAULT NOW();

-- 7. Add joined_at to group_members if missing for accurate member tenure auditing
ALTER TABLE public.group_members 
    ADD COLUMN IF NOT EXISTS joined_at TIMESTAMPTZ DEFAULT NOW();
