-- SafeChit SQL Schema: Chit Payments & Installment Ledger
-- Handles zero-fee P2P UPI payments, YouPI session tracking, and Foreman cash confirmations

CREATE TABLE IF NOT EXISTS public.chit_payments (
    id VARCHAR(64) PRIMARY KEY,
    group_id VARCHAR(64) NOT NULL,
    group_name VARCHAR(128) NOT NULL,
    cycle INT NOT NULL DEFAULT 1,
    member_username VARCHAR(64) NOT NULL,
    member_name VARCHAR(128) NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    amount_paise BIGINT NOT NULL,
    payment_method VARCHAR(32) NOT NULL DEFAULT 'UPI', -- 'UPI', 'CASH_COUNTER', 'CARD_COUNTER'
    status VARCHAR(32) NOT NULL DEFAULT 'INITIATED',   -- 'INITIATED', 'ACTIVE', 'QUEUED', 'PAID', 'FAILED', 'EXPIRED'
    utr VARCHAR(64),                                   -- 12-digit bank reference number
    payment_session_id VARCHAR(64),                    -- YouPI PG session UUID
    payee_vpa VARCHAR(128) NOT NULL,                   -- Foreman receiving UPI ID
    payee_name VARCHAR(128) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    notes TEXT
);

-- Indexes for lightning-fast lookups
CREATE INDEX IF NOT EXISTS idx_chit_payments_group ON public.chit_payments(group_id);
CREATE INDEX IF NOT EXISTS idx_chit_payments_member ON public.chit_payments(member_username);
CREATE INDEX IF NOT EXISTS idx_chit_payments_status ON public.chit_payments(status);
CREATE INDEX IF NOT EXISTS idx_chit_payments_created ON public.chit_payments(created_at DESC);

-- Enable Row-Level Security
ALTER TABLE public.chit_payments ENABLE ROW LEVEL SECURITY;

-- Allow read access for authenticated subscribers and foremen
CREATE POLICY "Allow public read access to chit_payments"
    ON public.chit_payments
    FOR SELECT
    USING (true);

-- Allow insert/update access for payment recording and foreman confirmations
CREATE POLICY "Allow insert and update to chit_payments"
    ON public.chit_payments
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Baseline Seed Payment
INSERT INTO public.chit_payments (
    id, group_id, group_name, cycle, member_username, member_name, 
    amount, amount_paise, payment_method, status, utr, payment_session_id, 
    payee_vpa, payee_name, created_at, completed_at, notes
) VALUES (
    'pay_demo_seed_001',
    'group_1',
    'Indiranagar Traders Chit',
    1,
    'member_demo',
    'Demo Member',
    5000.00,
    500000,
    'UPI',
    'PAID',
    '429182749102',
    'youpi_sess_seed_001',
    'safechit.foreman@oksbi',
    'Rajesh Kumar (Foreman Escrow)',
    NOW() - INTERVAL '2 days',
    NOW() - INTERVAL '2 days' + INTERVAL '2 minutes',
    'Cycle 1 Verified UPI Installment'
) ON CONFLICT (id) DO NOTHING;
