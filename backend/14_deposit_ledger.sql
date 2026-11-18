-- =================================================================
-- SafeChit SQL Migration 14: Deposit Ledger & Server-Side Functions
-- File: backend/14_deposit_ledger.sql
-- =================================================================

-- 1. Clean up legacy/test rows in security_deposits
DELETE FROM public.security_deposits
WHERE id IN (
    '5a8a44be-e573-4d50-b6d3-5da7898eec1c',
    '6ef069e2-687b-4479-8c8b-fe28f00ea08a',
    'dep_group_1792422423897_member_demo_1794979638848',
    'dep_group_1794842511418_member_demo_1794919406798'
);

-- 2. Update security_deposits schema
ALTER TABLE public.security_deposits ALTER COLUMN razorpay_order_id DROP NOT NULL;
ALTER TABLE public.security_deposits ALTER COLUMN razorpay_payment_id DROP NOT NULL;

ALTER TABLE public.security_deposits
    ADD COLUMN IF NOT EXISTS applied_amount NUMERIC(12, 2) DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'security_deposits_group_id_member_id_key'
    ) THEN
        ALTER TABLE public.security_deposits
            ADD CONSTRAINT security_deposits_group_id_member_id_key UNIQUE (group_id, member_id);
    END IF;
EXCEPTION WHEN duplicate_table OR duplicate_object THEN
    -- constraint already present
END $$;

ALTER TABLE public.security_deposits DROP CONSTRAINT IF EXISTS security_deposits_status_check;
ALTER TABLE public.security_deposits
    ADD CONSTRAINT security_deposits_status_check
    CHECK (status IN ('pending', 'held', 'refunded', 'forfeited'));

ALTER TABLE public.security_deposits ALTER COLUMN created_at SET DEFAULT NOW();
ALTER TABLE public.security_deposits ALTER COLUMN updated_at SET DEFAULT NOW();

CREATE OR REPLACE FUNCTION public.set_updated_at_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_security_deposits_updated_at ON public.security_deposits;
CREATE TRIGGER trg_security_deposits_updated_at
BEFORE UPDATE ON public.security_deposits
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at_timestamp();

-- 3. Deposit amount: single source of truth on chit_groups
ALTER TABLE public.chit_groups
    ADD COLUMN IF NOT EXISTS deposit_amount NUMERIC(12, 2);

-- Backfill deposit_amount on existing groups from security_deposit or monthly_contribution * 0.10
UPDATE public.chit_groups
SET deposit_amount = COALESCE(deposit_amount, security_deposit, ROUND(monthly_contribution * 0.10, 2))
WHERE deposit_amount IS NULL;

-- 4. Create immutable deposit_transactions table
CREATE TABLE IF NOT EXISTS public.deposit_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    deposit_id TEXT,
    group_id TEXT NOT NULL,
    member_id TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('pay', 'refund', 'forfeit')),
    amount NUMERIC(12, 2) NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('success', 'failed')),
    reference TEXT,
    failure_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Append-only trigger for deposit_transactions
CREATE OR REPLACE FUNCTION public.trg_deposit_transactions_append_only()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'deposit_transactions is an immutable append-only audit ledger. Updates and deletions are prohibited.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_deposit_transactions_mutation ON public.deposit_transactions;
CREATE TRIGGER trg_prevent_deposit_transactions_mutation
BEFORE UPDATE OR DELETE ON public.deposit_transactions
FOR EACH ROW
EXECUTE FUNCTION public.trg_deposit_transactions_append_only();

-- 5. Server-side security functions (SECURITY DEFINER, public search path)

-- Function: record_deposit_payment
CREATE OR REPLACE FUNCTION public.record_deposit_payment(
    p_group_id TEXT,
    p_member_id TEXT,
    p_outcome TEXT DEFAULT 'success'
)
RETURNS JSON AS $$
DECLARE
    v_group_deposit NUMERIC(12, 2);
    v_existing_id TEXT;
    v_existing_status TEXT;
    v_deposit_id TEXT;
    v_ref TEXT;
    v_chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    v_random_str TEXT := '';
    i INT;
BEGIN
    -- 1. Verify group exists and retrieve official deposit_amount
    SELECT COALESCE(deposit_amount, security_deposit, ROUND(monthly_contribution * 0.10, 2))
    INTO v_group_deposit
    FROM public.chit_groups
    WHERE id = p_group_id;

    IF v_group_deposit IS NULL THEN
        RAISE EXCEPTION 'Chit group "%" not found.', p_group_id;
    END IF;

    -- 2. Verify member has an approved join request or membership
    IF NOT EXISTS (
        SELECT 1 FROM public.chit_join_requests
        WHERE group_id = p_group_id
          AND LOWER(TRIM(member_username)) = LOWER(TRIM(p_member_id))
          AND status = 'approved'
    ) AND NOT EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_id = p_group_id
          AND LOWER(TRIM(name)) = LOWER(TRIM(p_member_id))
    ) THEN
        RAISE EXCEPTION 'Member "%" does not have an approved join request or membership in group "%"', p_member_id, p_group_id;
    END IF;

    -- 3. Check existing deposit record
    SELECT id, status INTO v_existing_id, v_existing_status
    FROM public.security_deposits
    WHERE group_id = p_group_id AND member_id = p_member_id;

    IF v_existing_status = 'held' THEN
        RAISE EXCEPTION 'Deposit already recorded';
    END IF;

    -- 4. Process outcome
    IF LOWER(TRIM(p_outcome)) = 'failure' THEN
        IF v_existing_id IS NULL THEN
            v_deposit_id := gen_random_uuid()::text;
            INSERT INTO public.security_deposits (id, group_id, member_id, amount, status, created_at, updated_at)
            VALUES (v_deposit_id, p_group_id, p_member_id, v_group_deposit, 'pending', NOW(), NOW());
        ELSE
            v_deposit_id := v_existing_id;
            UPDATE public.security_deposits
            SET status = 'pending', amount = v_group_deposit, updated_at = NOW()
            WHERE id = v_deposit_id;
        END IF;

        INSERT INTO public.deposit_transactions (
            deposit_id, group_id, member_id, type, amount, status, reference, failure_reason, created_at
        ) VALUES (
            v_deposit_id, p_group_id, p_member_id, 'pay', v_group_deposit, 'failed', NULL, 'Simulated bank declined', NOW()
        );

        RETURN json_build_object(
            'success', false,
            'deposit_id', v_deposit_id,
            'status', 'pending',
            'amount', v_group_deposit,
            'error', 'Simulated bank declined'
        );
    ELSE
        -- Success path: generate SIM + 10 random uppercase characters
        FOR i IN 1..10 LOOP
            v_random_str := v_random_str || substr(v_chars, floor(random() * length(v_chars) + 1)::integer, 1);
        END LOOP;
        v_ref := 'SIM' || v_random_str;

        IF v_existing_id IS NULL THEN
            v_deposit_id := gen_random_uuid()::text;
            INSERT INTO public.security_deposits (id, group_id, member_id, amount, status, created_at, updated_at)
            VALUES (v_deposit_id, p_group_id, p_member_id, v_group_deposit, 'held', NOW(), NOW());
        ELSE
            v_deposit_id := v_existing_id;
            UPDATE public.security_deposits
            SET status = 'held', amount = v_group_deposit, updated_at = NOW()
            WHERE id = v_deposit_id;
        END IF;

        INSERT INTO public.deposit_transactions (
            deposit_id, group_id, member_id, type, amount, status, reference, failure_reason, created_at
        ) VALUES (
            v_deposit_id, p_group_id, p_member_id, 'pay', v_group_deposit, 'success', v_ref, NULL, NOW()
        );

        RETURN json_build_object(
            'success', true,
            'deposit_id', v_deposit_id,
            'reference', v_ref,
            'amount', v_group_deposit,
            'status', 'held'
        );
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Function: refund_deposit
CREATE OR REPLACE FUNCTION public.refund_deposit(
    p_deposit_id TEXT
)
RETURNS JSON AS $$
DECLARE
    v_deposit RECORD;
    v_ref TEXT := 'REF' || upper(substr(md5(random()::text), 1, 10));
BEGIN
    SELECT * INTO v_deposit
    FROM public.security_deposits
    WHERE id = p_deposit_id;

    IF v_deposit IS NULL THEN
        RAISE EXCEPTION 'Security deposit "%" not found.', p_deposit_id;
    END IF;

    IF v_deposit.status != 'held' THEN
        RAISE EXCEPTION 'Only deposits with status "held" can be refunded. Current status: %', v_deposit.status;
    END IF;

    UPDATE public.security_deposits
    SET status = 'refunded', updated_at = NOW()
    WHERE id = p_deposit_id;

    INSERT INTO public.deposit_transactions (
        deposit_id, group_id, member_id, type, amount, status, reference, failure_reason, created_at
    ) VALUES (
        p_deposit_id, v_deposit.group_id, v_deposit.member_id, 'refund', v_deposit.amount, 'success', v_ref, NULL, NOW()
    );

    RETURN json_build_object(
        'success', true,
        'deposit_id', p_deposit_id,
        'reference', v_ref,
        'amount', v_deposit.amount,
        'status', 'refunded'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Function: forfeit_deposit
CREATE OR REPLACE FUNCTION public.forfeit_deposit(
    p_deposit_id TEXT,
    p_missed_amount NUMERIC DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_deposit RECORD;
    v_applied NUMERIC(12, 2);
    v_shortfall NUMERIC(12, 2) := 0;
    v_ref TEXT := 'FOR' || upper(substr(md5(random()::text), 1, 10));
BEGIN
    SELECT * INTO v_deposit
    FROM public.security_deposits
    WHERE id = p_deposit_id;

    IF v_deposit IS NULL THEN
        RAISE EXCEPTION 'Security deposit "%" not found.', p_deposit_id;
    END IF;

    IF v_deposit.status != 'held' THEN
        RAISE EXCEPTION 'Only deposits with status "held" can be forfeited. Current status: %', v_deposit.status;
    END IF;

    v_applied := LEAST(v_deposit.amount, COALESCE(p_missed_amount, v_deposit.amount));

    IF p_missed_amount IS NOT NULL THEN
        v_shortfall := GREATEST(0, p_missed_amount - v_applied);
    ELSE
        v_shortfall := 0;
    END IF;

    UPDATE public.security_deposits
    SET status = 'forfeited', applied_amount = v_applied, updated_at = NOW()
    WHERE id = p_deposit_id;

    INSERT INTO public.deposit_transactions (
        deposit_id, group_id, member_id, type, amount, status, reference, failure_reason, created_at
    ) VALUES (
        p_deposit_id, v_deposit.group_id, v_deposit.member_id, 'forfeit', v_applied, 'success', v_ref, NULL, NOW()
    );

    RETURN json_build_object(
        'success', true,
        'deposit_id', p_deposit_id,
        'status', 'forfeited',
        'applied_amount', v_applied,
        'shortfall', v_shortfall,
        'reference', v_ref
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Grant execution permissions
GRANT EXECUTE ON FUNCTION public.record_deposit_payment(TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.refund_deposit(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.forfeit_deposit(TEXT, NUMERIC) TO anon, authenticated;

-- 6. RLS: Enable RLS, remove direct client writes, keep SELECT only
ALTER TABLE public.security_deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deposit_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow insert and update to security_deposits" ON public.security_deposits;
DROP POLICY IF EXISTS "Public write security_deposits" ON public.security_deposits;
DROP POLICY IF EXISTS "Allow public read access to security_deposits" ON public.security_deposits;
CREATE POLICY "Allow public read access to security_deposits"
    ON public.security_deposits FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow public read access to deposit_transactions" ON public.deposit_transactions;
CREATE POLICY "Allow public read access to deposit_transactions"
    ON public.deposit_transactions FOR SELECT USING (true);

-- Realtime publication
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.security_deposits;
    EXCEPTION WHEN duplicate_object THEN
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.deposit_transactions;
    EXCEPTION WHEN duplicate_object THEN
    END;
END $$;
