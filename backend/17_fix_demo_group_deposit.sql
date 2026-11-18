-- =================================================================
-- SafeChit SQL Migration 17: Set 10% Security Deposit Default
-- File: backend/17_fix_demo_group_deposit.sql
-- =================================================================

-- 1. Backfill chit_groups so deposit_amount is exactly 10% of monthly installment
-- (Ensures test groups and pitch slides align at 10% collateral)
UPDATE public.chit_groups
SET 
    deposit_amount = ROUND(monthly_contribution * 0.10, 2),
    security_deposit = ROUND(monthly_contribution * 0.10, 2);

-- 2. Update record_deposit_payment to strictly pull 10% of monthly contribution
-- if deposit_amount is not explicitly set
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
    -- 1. Retrieve official deposit_amount (defaulting to 10% of monthly installment)
    SELECT COALESCE(deposit_amount, ROUND(monthly_contribution * 0.10, 2))
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
          AND (
              LOWER(TRIM(COALESCE(member_username, ''))) = LOWER(TRIM(p_member_id))
              OR LOWER(TRIM(name)) = LOWER(TRIM(p_member_id))
          )
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
