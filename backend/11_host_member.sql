-- =================================================================
-- 🏢 Feature 11: Host as Member & Cycle 2 Payout Schema
-- File: backend/11_host_member.sql
-- Run this in your Supabase Dashboard -> SQL Editor
-- =================================================================

-- 1. Add is_host_member flag to group_members table
ALTER TABLE public.group_members 
ADD COLUMN IF NOT EXISTS is_host_member BOOLEAN DEFAULT FALSE;

-- 2. Performance index on is_host_member for fast roster & bidding filtering
CREATE INDEX IF NOT EXISTS idx_group_members_host_member 
ON public.group_members(group_id, is_host_member);

-- 3. Idempotent check / verification
DO $$
BEGIN
    RAISE NOTICE 'group_members.is_host_member column verified successfully.';
END $$;

