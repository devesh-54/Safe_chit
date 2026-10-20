-- =================================================================
-- 🚀 Feature 8: Foreman UPI ID Support for Chit Groups
-- File: backend/08_chit_groups_foreman_upi.sql
-- Run this in Supabase Dashboard -> SQL Editor
-- =================================================================

-- 1. Add foreman_upi_id column to public.chit_groups table
ALTER TABLE public.chit_groups 
ADD COLUMN IF NOT EXISTS foreman_upi_id VARCHAR(128) DEFAULT 'devesh1@oksbi';

-- 2. Update existing rows if any have null foreman_upi_id
UPDATE public.chit_groups 
SET foreman_upi_id = 'devesh1@oksbi' 
WHERE foreman_upi_id IS NULL;

-- 3. Ensure RLS Policy allows updates on chit_groups
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename = 'chit_groups' 
          AND policyname = 'Public update chit_groups'
    ) THEN
        CREATE POLICY "Public update chit_groups" 
        ON public.chit_groups FOR UPDATE USING (true) WITH CHECK (true);
    END IF;
END $$;
