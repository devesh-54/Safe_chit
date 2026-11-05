-- =================================================================
-- 🎖️ Feature 10: Reputation Events Schema & Dual-Role Performance
-- File: backend/10_reputation_events.sql
-- Run this in your Supabase Dashboard -> SQL Editor
-- =================================================================

-- 1. Create reputation_events table
CREATE TABLE IF NOT EXISTS public.reputation_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('member', 'foreman')),
    event_type VARCHAR(100) NOT NULL, -- 'on_time_payment', 'group_completed', 'clean_guarantee', 'default', 'group_hosted', 'escrow_disbursed', 'zero_dispute'
    score_delta NUMERIC DEFAULT 0,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Performance indexes
CREATE INDEX IF NOT EXISTS idx_reputation_events_user_role 
ON public.reputation_events(LOWER(username), role);

CREATE INDEX IF NOT EXISTS idx_reputation_events_created 
ON public.reputation_events(created_at DESC);

-- 3. Enable Row Level Security (RLS) & Policies
ALTER TABLE public.reputation_events ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename = 'reputation_events' 
          AND policyname = 'Public read reputation_events'
    ) THEN
        CREATE POLICY "Public read reputation_events" 
        ON public.reputation_events FOR SELECT USING (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename = 'reputation_events' 
          AND policyname = 'Public insert reputation_events'
    ) THEN
        CREATE POLICY "Public insert reputation_events" 
        ON public.reputation_events FOR INSERT WITH CHECK (true);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename = 'reputation_events' 
          AND policyname = 'Public update reputation_events'
    ) THEN
        CREATE POLICY "Public update reputation_events" 
        ON public.reputation_events FOR UPDATE USING (true);
    END IF;
END $$;

-- 4. Seed Initial Reputation Events for Demo Accounts (Idempotent: Safe to re-run)
INSERT INTO public.reputation_events (username, role, event_type, score_delta, description, created_at)
SELECT 'member_demo', 'member', 'on_time_payment', 5.0, 'On-time installment for Bengaluru Techies Chit', NOW() - INTERVAL '3 days'
WHERE NOT EXISTS (SELECT 1 FROM public.reputation_events WHERE LOWER(username) = 'member_demo' AND role = 'member' AND event_type = 'on_time_payment');

INSERT INTO public.reputation_events (username, role, event_type, score_delta, description, created_at)
SELECT 'member_demo', 'member', 'group_completed', 10.0, 'Completed Koramangala 5-Month Chit cycle with 0 defaults', NOW() - INTERVAL '15 days'
WHERE NOT EXISTS (SELECT 1 FROM public.reputation_events WHERE LOWER(username) = 'member_demo' AND role = 'member' AND event_type = 'group_completed');

INSERT INTO public.reputation_events (username, role, event_type, score_delta, description, created_at)
SELECT 'member_demo', 'member', 'clean_guarantee', 5.0, 'Acted as guarantor for group participant with 0 defaults', NOW() - INTERVAL '30 days'
WHERE NOT EXISTS (SELECT 1 FROM public.reputation_events WHERE LOWER(username) = 'member_demo' AND role = 'member' AND event_type = 'clean_guarantee');

INSERT INTO public.reputation_events (username, role, event_type, score_delta, description, created_at)
SELECT 'member_test2', 'member', 'on_time_payment', 5.0, 'On-time installment collection verified', NOW() - INTERVAL '2 days'
WHERE NOT EXISTS (SELECT 1 FROM public.reputation_events WHERE LOWER(username) = 'member_test2' AND role = 'member' AND event_type = 'on_time_payment');

INSERT INTO public.reputation_events (username, role, event_type, score_delta, description, created_at)
SELECT 'member_test2', 'member', 'clean_guarantee', 5.0, 'Guarantee nomination accepted & active', NOW() - INTERVAL '5 days'
WHERE NOT EXISTS (SELECT 1 FROM public.reputation_events WHERE LOWER(username) = 'member_test2' AND role = 'member' AND event_type = 'clean_guarantee');

INSERT INTO public.reputation_events (username, role, event_type, score_delta, description, created_at)
SELECT 'foreman_admin', 'foreman', 'group_hosted', 15.0, 'Successfully hosted and closed Koramangala Professional Chit', NOW() - INTERVAL '10 days'
WHERE NOT EXISTS (SELECT 1 FROM public.reputation_events WHERE LOWER(username) = 'foreman_admin' AND role = 'foreman' AND event_type = 'group_hosted');

INSERT INTO public.reputation_events (username, role, event_type, score_delta, description, created_at)
SELECT 'foreman_admin', 'foreman', 'escrow_disbursed', 10.0, 'Escrow payout released on schedule to winning bidder', NOW() - INTERVAL '20 days'
WHERE NOT EXISTS (SELECT 1 FROM public.reputation_events WHERE LOWER(username) = 'foreman_admin' AND role = 'foreman' AND event_type = 'escrow_disbursed');

INSERT INTO public.reputation_events (username, role, event_type, score_delta, description, created_at)
SELECT 'foreman_admin', 'foreman', 'zero_dispute', 5.0, '100% on-time disbursement streak maintained', NOW() - INTERVAL '40 days'
WHERE NOT EXISTS (SELECT 1 FROM public.reputation_events WHERE LOWER(username) = 'foreman_admin' AND role = 'foreman' AND event_type = 'zero_dispute');

INSERT INTO public.reputation_events (username, role, event_type, score_delta, description, created_at)
SELECT 'suresh raina', 'member', 'on_time_payment', 5.0, 'On-time installment for Bengaluru Techies Chit', NOW() - INTERVAL '3 days'
WHERE NOT EXISTS (SELECT 1 FROM public.reputation_events WHERE LOWER(username) = 'suresh raina' AND role = 'member' AND event_type = 'on_time_payment');
