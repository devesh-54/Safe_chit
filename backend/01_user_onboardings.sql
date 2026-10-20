-- =================================================================
-- 📌 Feature 1: User Onboarding & Identity Schema
-- File: backend/01_user_onboardings.sql
-- Run in Supabase SQL Editor for User Sign-Up & Credentials setup
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

-- Case-insensitive unique index on username
CREATE UNIQUE INDEX IF NOT EXISTS user_onboardings_username_lower_idx 
ON public.user_onboardings (LOWER(username));

-- Enable Row Level Security (RLS) & Public Policies
ALTER TABLE public.user_onboardings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read user_onboardings" ON public.user_onboardings FOR SELECT USING (true);
CREATE POLICY "Public insert user_onboardings" ON public.user_onboardings FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update user_onboardings" ON public.user_onboardings FOR UPDATE USING (true);
