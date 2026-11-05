-- SafeChit SQL Migration 12: Security Deposits
-- Records refundable security deposits held for chit group members,
-- tracking Razorpay order & payment identifiers and lifecycle states.

CREATE TABLE IF NOT EXISTS public.security_deposits (
    id VARCHAR(100) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    group_id VARCHAR(100) REFERENCES public.chit_groups(id) ON DELETE CASCADE,
    member_id VARCHAR(100) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'held', 'refunded', 'forfeited')),
    razorpay_order_id VARCHAR(128),
    razorpay_payment_id VARCHAR(128),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Unique index: one security deposit record per member per group
CREATE UNIQUE INDEX IF NOT EXISTS idx_security_deposits_group_member 
    ON public.security_deposits(group_id, member_id);

-- Indexes for lightning-fast lookups
CREATE INDEX IF NOT EXISTS idx_security_deposits_group ON public.security_deposits(group_id);
CREATE INDEX IF NOT EXISTS idx_security_deposits_member ON public.security_deposits(member_id);
CREATE INDEX IF NOT EXISTS idx_security_deposits_status ON public.security_deposits(status);
CREATE INDEX IF NOT EXISTS idx_security_deposits_order ON public.security_deposits(razorpay_order_id);

-- Enable Row-Level Security
ALTER TABLE public.security_deposits ENABLE ROW LEVEL SECURITY;

-- Open testing policy (matching existing development tables)
CREATE POLICY "Allow public read access to security_deposits"
    ON public.security_deposits
    FOR SELECT
    USING (true);

CREATE POLICY "Allow insert and update to security_deposits"
    ON public.security_deposits
    FOR ALL
    USING (true)
    WITH CHECK (true);

