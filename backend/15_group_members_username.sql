-- =================================================================
-- SafeChit SQL Migration 15: Add member_username to group_members
-- File: backend/15_group_members_username.sql
-- =================================================================

-- 1. Add member_username column to group_members
ALTER TABLE public.group_members
    ADD COLUMN IF NOT EXISTS member_username VARCHAR(100);

-- 2. Backfill existing rows
-- 2a. Host members: their name holds their username
UPDATE public.group_members
SET member_username = LOWER(TRIM(name))
WHERE (is_host_member = true OR LOWER(name) LIKE '%foreman%')
  AND member_username IS NULL;

-- 2b. Regular members: match with chit_join_requests by group_id and member_name
UPDATE public.group_members gm
SET member_username = cjr.member_username
FROM public.chit_join_requests cjr
WHERE gm.group_id = cjr.group_id
  AND LOWER(TRIM(gm.name)) = LOWER(TRIM(cjr.member_name))
  AND gm.member_username IS NULL;

-- 2c. Fallback for any remaining unassigned rows
UPDATE public.group_members
SET member_username = LOWER(REPLACE(TRIM(name), ' ', '_'))
WHERE member_username IS NULL;

-- 3. Create index for fast lookups
CREATE INDEX IF NOT EXISTS idx_group_members_username
    ON public.group_members(group_id, member_username);

-- 4. Update Trigger 1: check_guarantor_not_group_member
CREATE OR REPLACE FUNCTION public.check_guarantor_not_group_member()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if guarantor is already in group_members by username OR name
    IF EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_id = NEW.group_id
        AND (
            LOWER(TRIM(COALESCE(member_username, ''))) = LOWER(TRIM(NEW.guarantor_id))
            OR LOWER(TRIM(name)) = LOWER(TRIM(NEW.guarantor_id))
        )
    ) THEN
        RAISE EXCEPTION 'Guarantor "%" is already an active member of chit group "%". Dual participation is disallowed to prevent dual-default risk.',
            NEW.guarantor_id, NEW.group_id;
    END IF;

    -- Check if guarantor already has an approved join request for this group
    IF EXISTS (
        SELECT 1 FROM public.chit_join_requests
        WHERE group_id = NEW.group_id
        AND LOWER(TRIM(member_username)) = LOWER(TRIM(NEW.guarantor_id))
        AND status = 'approved'
    ) THEN
        RAISE EXCEPTION 'Guarantor "%" is already an approved member of chit group "%".',
            NEW.guarantor_id, NEW.group_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Update Trigger 2: check_member_not_group_guarantor
CREATE OR REPLACE FUNCTION public.check_member_not_group_guarantor()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if prospective member has an active or pending guarantee in this group
    IF EXISTS (
        SELECT 1 FROM public.guarantee_requests
        WHERE group_id = NEW.group_id
        AND (
            LOWER(TRIM(guarantor_id)) = LOWER(TRIM(COALESCE(NEW.member_username, '')))
            OR LOWER(TRIM(guarantor_id)) = LOWER(TRIM(NEW.name))
        )
        AND status IN ('accepted', 'pending')
    ) THEN
        RAISE EXCEPTION 'User "%" is already acting as a guarantor for a member in chit group "%". A guarantor cannot join the same chit group.',
            COALESCE(NEW.member_username, NEW.name), NEW.group_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 6. Update Trigger 3: check_join_request_mutual_exclusion
CREATE OR REPLACE FUNCTION public.check_join_request_mutual_exclusion()
RETURNS TRIGGER AS $$
BEGIN
    -- Applicant cannot already be an active or pending guarantor in this group
    IF EXISTS (
        SELECT 1 FROM public.guarantee_requests
        WHERE group_id = NEW.group_id
        AND LOWER(TRIM(guarantor_id)) = LOWER(TRIM(NEW.member_username))
        AND status IN ('accepted', 'pending')
    ) THEN
        RAISE EXCEPTION 'User "%" is already a guarantor in chit group "%". A guarantor cannot join the same chit group as a member.',
            NEW.member_username, NEW.group_id;
    END IF;

    -- Nominated guarantor cannot already be an active or approved member in this group
    IF NEW.guarantor_username IS NOT NULL AND TRIM(NEW.guarantor_username) != '' THEN
        IF LOWER(TRIM(NEW.guarantor_username)) = LOWER(TRIM(NEW.member_username)) THEN
            RAISE EXCEPTION 'Applicant cannot nominate themselves as guarantor.';
        END IF;

        IF EXISTS (
            SELECT 1 FROM public.group_members
            WHERE group_id = NEW.group_id
            AND (
                LOWER(TRIM(COALESCE(member_username, ''))) = LOWER(TRIM(NEW.guarantor_username))
                OR LOWER(TRIM(name)) = LOWER(TRIM(NEW.guarantor_username))
            )
        ) OR EXISTS (
            SELECT 1 FROM public.chit_join_requests
            WHERE group_id = NEW.group_id
            AND LOWER(TRIM(member_username)) = LOWER(TRIM(NEW.guarantor_username))
            AND status = 'approved'
        ) THEN
            RAISE EXCEPTION 'Guarantor "%" is already a member of chit group "%". Mutual exclusion violation.',
                NEW.guarantor_username, NEW.group_id;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 7. Update record_deposit_payment function to check member_username
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

    -- 2. Verify member has an approved join request or membership (checks member_username and name)
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
