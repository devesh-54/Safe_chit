-- =================================================================
-- 🛡️ ChitGuard Supabase Complete Schema Setup Script
-- Paste and run this script in your Supabase Dashboard -> SQL Editor
-- =================================================================

-- 1. User Role Enum
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('member', 'host');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. User Onboardings Table
CREATE TABLE IF NOT EXISTS public.user_onboardings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255),
    role user_role DEFAULT 'member',
    mobile_number VARCHAR(15),
    is_mobile_verified BOOLEAN DEFAULT FALSE,
    email VARCHAR(255),
    is_email_verified BOOLEAN DEFAULT FALSE,
    full_name VARCHAR(255),
    date_of_birth DATE,
    gender VARCHAR(50),
    pan_number VARCHAR(10),
    aadhaar_number VARCHAR(12),
    id_document_url TEXT,
    is_gov_id_verified BOOLEAN DEFAULT FALSE,
    perm_address TEXT,
    perm_city VARCHAR(100),
    perm_state VARCHAR(100),
    perm_pin_code VARCHAR(6),
    is_current_same_as_permanent BOOLEAN DEFAULT TRUE,
    curr_address TEXT,
    curr_city VARCHAR(100),
    curr_state VARCHAR(100),
    curr_pin_code VARCHAR(6),
    bank_account_number VARCHAR(30),
    bank_ifsc VARCHAR(11),
    bank_name VARCHAR(255),
    bank_branch VARCHAR(255),
    is_bank_verified BOOLEAN DEFAULT FALSE,
    has_consented BOOLEAN DEFAULT FALSE,
    consent_timestamp TIMESTAMPTZ DEFAULT NOW(),
    signature_document_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Case-insensitive index for username
CREATE UNIQUE INDEX IF NOT EXISTS user_onboardings_username_lower_idx 
ON public.user_onboardings (LOWER(username));

-- 3. Chit Groups Table (with 6-Digit Unique Join Code & Filter/Discovery fields)
CREATE TABLE IF NOT EXISTS public.chit_groups (
    id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    total_pool_size NUMERIC NOT NULL,
    duration_months INT NOT NULL,
    monthly_contribution NUMERIC NOT NULL,
    security_deposit NUMERIC NOT NULL,
    payout_rules TEXT,
    invite_code VARCHAR(10) UNIQUE NOT NULL, -- 6-Digit Unique Join Code (e.g. 849201)
    status VARCHAR(50) DEFAULT 'Active',
    current_cycle INT DEFAULT 1,
    members_count INT DEFAULT 1,
    scheme_type VARCHAR(50) DEFAULT 'Bidding', -- 'Bidding' or 'Random Picking'
    is_public BOOLEAN DEFAULT TRUE,
    city VARCHAR(100) DEFAULT 'Bengaluru',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index on 6-digit invite_code for instant lookup
CREATE UNIQUE INDEX IF NOT EXISTS chit_groups_invite_code_idx 
ON public.chit_groups (invite_code);

-- Index on is_public and scheme_type for fast discovery queries
CREATE INDEX IF NOT EXISTS chit_groups_public_discovery_idx 
ON public.chit_groups (is_public, scheme_type);

-- 4. Chit Join Requests Table (Non-sensitive member info only)
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

-- 5. Group Members Table (Active Members in Group with Credit/Risk Profile)
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

-- 6. Digital Agreements Table (Chit Funds Act 1982 Compliant)
CREATE TABLE IF NOT EXISTS public.digital_agreements (
    id VARCHAR(100) PRIMARY KEY,
    group_id VARCHAR(100) REFERENCES public.chit_groups(id) ON DELETE CASCADE,
    group_name VARCHAR(255) NOT NULL,
    foreman_username VARCHAR(50) NOT NULL,
    foreman_name VARCHAR(255) NOT NULL,
    member_username VARCHAR(50) NOT NULL,
    member_name VARCHAR(255) NOT NULL,
    pool_amount NUMERIC NOT NULL,
    duration_months INT NOT NULL,
    monthly_contribution NUMERIC NOT NULL,
    scheme_type VARCHAR(50) DEFAULT 'Bidding',
    agreement_text TEXT NOT NULL,
    foreman_signed BOOLEAN DEFAULT FALSE,
    foreman_signature_url TEXT,
    foreman_signed_at TIMESTAMPTZ,
    member_signed BOOLEAN DEFAULT FALSE,
    member_signature_url TEXT,
    member_signed_at TIMESTAMPTZ,
    status VARCHAR(50) DEFAULT 'pending_signatures', -- 'pending_signatures', 'fully_executed'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Landing Page Waitlist Table
CREATE TABLE IF NOT EXISTS public.waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, NOW()) NOT NULL
);

-- =================================================================
-- RLS & Access Control Policies
-- =================================================================
ALTER TABLE public.user_onboardings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chit_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chit_join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.digital_agreements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read user_onboardings" ON public.user_onboardings FOR SELECT USING (true);
CREATE POLICY "Public insert user_onboardings" ON public.user_onboardings FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update user_onboardings" ON public.user_onboardings FOR UPDATE USING (true);

CREATE POLICY "Public read chit_groups" ON public.chit_groups FOR SELECT USING (true);
CREATE POLICY "Public insert chit_groups" ON public.chit_groups FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update chit_groups" ON public.chit_groups FOR UPDATE USING (true);

CREATE POLICY "Public read chit_join_requests" ON public.chit_join_requests FOR SELECT USING (true);
CREATE POLICY "Public insert chit_join_requests" ON public.chit_join_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update chit_join_requests" ON public.chit_join_requests FOR UPDATE USING (true);

CREATE POLICY "Public read group_members" ON public.group_members FOR SELECT USING (true);
CREATE POLICY "Public insert group_members" ON public.group_members FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update group_members" ON public.group_members FOR UPDATE USING (true);

CREATE POLICY "Public read digital_agreements" ON public.digital_agreements FOR SELECT USING (true);
CREATE POLICY "Public insert digital_agreements" ON public.digital_agreements FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update digital_agreements" ON public.digital_agreements FOR UPDATE USING (true);

CREATE POLICY "Allow public insert to waitlist" ON public.waitlist FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public select waitlist" ON public.waitlist FOR SELECT USING (true);
