-- SafeChit SQL Migration 13: Member-Guarantor Mutual Exclusion
-- Prevents dual-default risk by ensuring a member and their guarantor
-- cannot belong to the same chit group simultaneously.

-- 1. Trigger Function: Prevent nominating or accepting a guarantor who is already a member
CREATE OR REPLACE FUNCTION check_guarantor_not_group_member()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the guarantor is already in group_members
    IF EXISTS (
        SELECT 1 FROM public.group_members
        WHERE group_id = NEW.group_id
        AND LOWER(TRIM(name)) = LOWER(TRIM(NEW.guarantor_id))
    ) THEN
        RAISE EXCEPTION 'Guarantor "%" is already an active member of chit group "%". Dual participation is disallowed to prevent dual-default risk.',
            NEW.guarantor_id, NEW.group_id;
    END IF;

    -- Check if the guarantor already has an approved join request for this group
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

DROP TRIGGER IF EXISTS trg_check_guarantor_not_member ON public.guarantee_requests;
CREATE TRIGGER trg_check_guarantor_not_member
BEFORE INSERT OR UPDATE ON public.guarantee_requests
FOR EACH ROW
EXECUTE FUNCTION check_guarantor_not_group_member();

-- 2. Trigger Function: Prevent an existing guarantor from joining the same group as a member
CREATE OR REPLACE FUNCTION check_member_not_group_guarantor()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if prospective member has an active or pending guarantee in this group
    IF EXISTS (
        SELECT 1 FROM public.guarantee_requests
        WHERE group_id = NEW.group_id
        AND LOWER(TRIM(guarantor_id)) = LOWER(TRIM(NEW.name))
        AND status IN ('accepted', 'pending')
    ) THEN
        RAISE EXCEPTION 'User "%" is already acting as a guarantor for a member in chit group "%". A guarantor cannot join the same chit group.',
            NEW.name, NEW.group_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_member_not_guarantor ON public.group_members;
CREATE TRIGGER trg_check_member_not_guarantor
BEFORE INSERT OR UPDATE ON public.group_members
FOR EACH ROW
EXECUTE FUNCTION check_member_not_group_guarantor();

-- 3. Trigger Function: Prevent join request if applicant is a guarantor or nominated guarantor is a member
CREATE OR REPLACE FUNCTION check_join_request_mutual_exclusion()
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
            AND LOWER(TRIM(name)) = LOWER(TRIM(NEW.guarantor_username))
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

DROP TRIGGER IF EXISTS trg_check_join_request_mutual_exclusion ON public.chit_join_requests;
CREATE TRIGGER trg_check_join_request_mutual_exclusion
BEFORE INSERT OR UPDATE ON public.chit_join_requests
FOR EACH ROW
EXECUTE FUNCTION check_join_request_mutual_exclusion();
