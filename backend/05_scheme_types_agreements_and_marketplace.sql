-- =================================================================
-- 📜 Feature 5: Scheme Types, Digital Agreements & Marketplace Schema
-- File: backend/05_scheme_types_agreements_and_marketplace.sql
-- Run in Supabase SQL Editor for Bidding/Random schemes & Legal Agreements
-- =================================================================

-- 1. Alter chit_groups table to support Scheme Type, Public Flag, and City
ALTER TABLE public.chit_groups 
ADD COLUMN IF NOT EXISTS scheme_type VARCHAR(50) DEFAULT 'Bidding',
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT TRUE,
ADD COLUMN IF NOT EXISTS city VARCHAR(100) DEFAULT 'Bengaluru';

-- Index on is_public and scheme_type for fast discovery queries
CREATE INDEX IF NOT EXISTS chit_groups_public_discovery_idx 
ON public.chit_groups (is_public, scheme_type);

-- 2. Digital Agreements Table (Chit Funds Act 1982 Compliant)
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

-- 3. Enable Row Level Security (RLS) & Public Access Policies
ALTER TABLE public.digital_agreements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read digital_agreements" ON public.digital_agreements FOR SELECT USING (true);
CREATE POLICY "Public insert digital_agreements" ON public.digital_agreements FOR INSERT WITH CHECK (true);
CREATE POLICY "Public update digital_agreements" ON public.digital_agreements FOR UPDATE USING (true);
