-- =================================================================
-- 🛡️ ChitGuard Supabase Database Schema & Setup
-- Location: /supabase_setup.sql
-- =================================================================

-- =================================================================
-- PART 1: FRESH DATABASE SCHEMA SETUP
-- Run this if you are setting up a fresh Supabase database.
-- =================================================================

-- 1. Create custom enum for the Member vs. Host roles
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('member', 'host');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. Create the unified 'user_onboardings' table
CREATE TABLE IF NOT EXISTS public.user_onboardings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE, -- Added via Migration
    role user_role, -- Will be set during role selection
    
    -- Account Setup
    mobile_number VARCHAR(15),
    is_mobile_verified BOOLEAN DEFAULT FALSE NOT NULL,
    email VARCHAR(255),
    is_email_verified BOOLEAN DEFAULT FALSE NOT NULL,
    
    -- Personal Details
    full_name VARCHAR(255),
    date_of_birth DATE,
    gender VARCHAR(50),
    
    -- Government ID
    pan_number VARCHAR(10),
    aadhaar_number VARCHAR(12),
    id_document_url TEXT, -- Path to scanned ID in private 'identity_documents' bucket
    is_gov_id_verified BOOLEAN DEFAULT FALSE NOT NULL,
    
    -- Address Details
    perm_address TEXT,
    perm_city VARCHAR(100),
    perm_state VARCHAR(100),
    perm_pin_code VARCHAR(6),
    is_current_same_as_permanent BOOLEAN DEFAULT TRUE NOT NULL,
    curr_address TEXT,
    curr_city VARCHAR(100),
    curr_state VARCHAR(100),
    curr_pin_code VARCHAR(6),
    
    -- Bank Account
    bank_account_number VARCHAR(30),
    bank_ifsc VARCHAR(11),
    bank_name VARCHAR(255),
    bank_branch VARCHAR(255),
    is_bank_verified BOOLEAN DEFAULT FALSE NOT NULL,
    
    -- KYC Consent
    has_consented BOOLEAN DEFAULT FALSE NOT NULL,
    consent_timestamp TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);

-- 3. Create case-insensitive unique index on the username column
CREATE UNIQUE INDEX IF NOT EXISTS user_onboardings_username_lower_idx 
ON public.user_onboardings (LOWER(username));

-- 4. Enable Row Level Security (RLS) on user_onboardings
ALTER TABLE public.user_onboardings ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies: Allow public/anonymous inserts, selects, updates for onboarding flow
CREATE POLICY "Allow public insert access for onboarding"
ON public.user_onboardings FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public read access for onboarding check"
ON public.user_onboardings FOR SELECT USING (true);

CREATE POLICY "Allow public update access for onboarding"
ON public.user_onboardings FOR UPDATE USING (true) WITH CHECK (true);

-- 6. Helper function for fast, secure public username availability checks
CREATE OR REPLACE FUNCTION public.check_username_available(input_username TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN NOT EXISTS (
        SELECT 1 FROM public.user_onboardings
        WHERE LOWER(username) = LOWER(input_username)
    );
END;
$$;

-- 7. Create 'waitlist' table for landing page capture entries
CREATE TABLE IF NOT EXISTS public.waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, NOW()) NOT NULL
);

-- 8. Enable RLS on waitlist table
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public insert to waitlist"
ON public.waitlist FOR INSERT WITH CHECK (true);

-- 9. Trigger function to automatically maintain the 'updated_at' timestamp
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_onboarding_modtime
    BEFORE UPDATE ON public.user_onboardings
    FOR EACH ROW
    EXECUTE FUNCTION update_modified_column();


-- =================================================================
-- PART 2: RUN HISTORY (MIGRATION LOG)
-- The following query was successfully executed on August 20, 2026.
-- =================================================================

/*
-- 1. Add the new 'username' column to your existing user_onboardings table
ALTER TABLE public.user_onboardings 
ADD COLUMN IF NOT EXISTS username VARCHAR(50) UNIQUE;

-- 2. Create a case-insensitive unique index on the username column
CREATE UNIQUE INDEX IF NOT EXISTS user_onboardings_username_lower_idx 
ON public.user_onboardings (LOWER(username));

-- 3. Create a helper function for fast, secure public username availability checks
CREATE OR REPLACE FUNCTION public.check_username_available(input_username TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN NOT EXISTS (
        SELECT 1 FROM public.user_onboardings
        WHERE LOWER(username) = LOWER(input_username)
    );
END;
$$;

-- 4. Create an optional 'waitlist' table for landing page capture entries
CREATE TABLE IF NOT EXISTS public.waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, NOW()) NOT NULL
);

-- Enable RLS on waitlist table
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public insert to waitlist"
ON public.waitlist
FOR INSERT
WITH CHECK (true);
*/
