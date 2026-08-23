-- =================================================================
-- 📢 Feature 4: Landing Page Waitlist Capture Schema
-- File: backend/04_waitlist.sql
-- Run in Supabase SQL Editor for Landing Page Waitlist Signups
-- =================================================================

CREATE TABLE IF NOT EXISTS public.waitlist (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, NOW()) NOT NULL
);

-- Enable RLS & Public Access
ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public insert to waitlist" ON public.waitlist FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public select waitlist" ON public.waitlist FOR SELECT USING (true);
