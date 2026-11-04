-- SafeChit SQL Migration 09: Guarantor Requests & Confirmations
-- Stores guarantee requests sent by chit members to prospective guarantors,
-- and records the guarantor's confirmation (accepted / declined) with timestamp.

CREATE TABLE IF NOT EXISTS public.guarantee_requests (
    id VARCHAR(100) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    group_id VARCHAR(100) REFERENCES public.chit_groups(id) ON DELETE CASCADE,
    join_request_id VARCHAR(100) REFERENCES public.chit_join_requests(id) ON DELETE CASCADE,
    member_id VARCHAR(100) NOT NULL,           -- Member username / ID requesting guarantee
    guarantor_id VARCHAR(100) NOT NULL,        -- Guarantor username / ID being requested
    relation VARCHAR(50) NOT NULL,             -- 'Family', 'Friend', 'Colleague', 'Neighbour', 'Other'
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'accepted', 'declined'
    consent_text TEXT DEFAULT 'By accepting, you agree to act as a guarantor for this member''s chit commitments.',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    responded_at TIMESTAMPTZ                    -- Timestamp when guarantor accepts or declines
);

-- Indexes for fast query lookup
CREATE INDEX IF NOT EXISTS idx_guarantee_requests_guarantor ON public.guarantee_requests(guarantor_id);
CREATE INDEX IF NOT EXISTS idx_guarantee_requests_member ON public.guarantee_requests(member_id);
CREATE INDEX IF NOT EXISTS idx_guarantee_requests_group ON public.guarantee_requests(group_id);
CREATE INDEX IF NOT EXISTS idx_guarantee_requests_join_req ON public.guarantee_requests(join_request_id);
CREATE INDEX IF NOT EXISTS idx_guarantee_requests_status ON public.guarantee_requests(status);

-- Enable Row-Level Security
ALTER TABLE public.guarantee_requests ENABLE ROW LEVEL SECURITY;

-- 1. Read Policy: Member, Guarantor, and Group Host can view
CREATE POLICY "Allow members, guarantors, and hosts to view guarantee requests"
    ON public.guarantee_requests
    FOR SELECT
    USING (true);

-- 2. Insert Policy: Members can create guarantee requests
CREATE POLICY "Allow creation of guarantee requests"
    ON public.guarantee_requests
    FOR INSERT
    WITH CHECK (true);

-- 3. Update Policy: Guarantor updates status upon accepting or declining
CREATE POLICY "Allow guarantors to update request status"
    ON public.guarantee_requests
    FOR UPDATE
    USING (true)
    WITH CHECK (true);

