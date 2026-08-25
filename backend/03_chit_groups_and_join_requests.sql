-- =================================================================
-- 🚀 Feature 3: Chit Groups & 6-Digit Join Code Workflow Schema
-- File: backend/03_chit_groups_and_join_requests.sql
-- Run in Supabase SQL Editor for Chit Group Creation & Member Requests
-- =================================================================

-- 1. Chit Groups Table (with 6-Digit Unique Join Code)
CREATE TABLE IF NOT EXISTS public.chit_groups (
    id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    total_pool_size NUMERIC NOT NULL,
    duration_months INT NOT NULL,
    monthly_contribution NUMERIC NOT NULL,
    security_deposit NUMERIC NOT NULL,
    payout_rules TEXT,
    invite_code VARCHAR(10) UNIQUE NOT NULL, -- 6-Digit Code (e.g. 849201)
    status VARCHAR(50) DEFAULT 'Active',
    current_cycle INT DEFAULT 1,
    members_count INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index on 6-digit invite_code for instant lookup
CREATE UNIQUE INDEX IF NOT EXISTS chit_groups_invite_code_idx 
ON public.chit_groups (invite_code);

-- 2. Chit Join Requests Table (Non-sensitive member info only)
CREATE TABLE IF NOT EXISTS public.chit_join_requests (
    id VARCHAR(100) PRIMARY KEY,
    group_id VARCHAR(100) REFERENCES public.chit_groups(id) ON DELETE CASCADE,
    group_name VARCHAR(255) NOT NULL,
    invite_code VARCHAR(10) NOT NULL,
    member_username VARCHAR(50) NOT NULL,
    member_name VARCHAR(255) NOT NULL,
    member_phone VARCHAR(20),
    member_email VARCHAR(255),
    member_city VARCHAR(100),
    reputation_score NUMERIC DEFAULT 100.0,
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Group Members Table (Active Members in Group)
CREATE TABLE IF NOT EXISTS public.group_members (
    id VARCHAR(100) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    group_id VARCHAR(100) REFERENCES public.chit_groups(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    default_risk_score NUMERIC DEFAULT 15.0,
    payout_position VARCHAR(100) DEFAULT 'Unpaid (Bidder)',
    payment_trend VARCHAR(100) DEFAULT 'On-Time',
    guarantor_status VARCHAR(100) DEFAULT 'Verified',
    amount_exposed NUMERIC DEFAULT 0,
    has_defaulted BOOLEAN DEFAULT FALSE,
    last_payment_date TIMESTAMPTZ DEFAULT NOW(),
    forfeited BOOLEAN DEFAULT FALSE,
    default_notice_sent BOOLEAN DEFAULT FALSE,
    default_notice_text TEXT,
    phone VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Enable Row Level Security (RLS) & Public Access Policies
ALTER TABLE public.chit_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chit_join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read chit_groups" ON public.chit_groups FOR SELECT USING (true);
CREATE POLICY "Public insert chit_groups" ON public.chit_groups FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update chit_groups" ON public.chit_groups FOR UPDATE USING (true);

CREATE POLICY "Public read chit_join_requests" ON public.chit_join_requests FOR SELECT USING (true);
CREATE POLICY "Public insert chit_join_requests" ON public.chit_join_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update chit_join_requests" ON public.chit_join_requests FOR UPDATE USING (true);

CREATE POLICY "Public read group_members" ON public.group_members FOR SELECT USING (true);
CREATE POLICY "Public insert group_members" ON public.group_members FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update group_members" ON public.group_members FOR UPDATE USING (true);
