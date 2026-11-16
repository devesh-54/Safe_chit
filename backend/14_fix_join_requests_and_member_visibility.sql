-- SafeChit SQL Migration 14: Fix Join Requests, Add Missing Columns & Guarantee Member Visibility
-- 1. Ensure chit_join_requests has columns for guarantor tracking
ALTER TABLE public.chit_join_requests
ADD COLUMN IF NOT EXISTS guarantor_username VARCHAR(50),
ADD COLUMN IF NOT EXISTS guarantor_relation VARCHAR(50),
ADD COLUMN IF NOT EXISTS guarantor_status VARCHAR(50) DEFAULT 'pending';

-- 2. Open RLS Policies for chit_join_requests for frictionless testing
ALTER TABLE public.chit_join_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read chit_join_requests" ON public.chit_join_requests;
CREATE POLICY "Public read chit_join_requests" ON public.chit_join_requests FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public insert chit_join_requests" ON public.chit_join_requests;
CREATE POLICY "Public insert chit_join_requests" ON public.chit_join_requests FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Public update chit_join_requests" ON public.chit_join_requests;
CREATE POLICY "Public update chit_join_requests" ON public.chit_join_requests FOR UPDATE USING (true);

-- 3. Open RLS Policies for group_members
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public read group_members" ON public.group_members;
CREATE POLICY "Public read group_members" ON public.group_members FOR SELECT USING (true);

DROP POLICY IF EXISTS "Public insert group_members" ON public.group_members;
CREATE POLICY "Public insert group_members" ON public.group_members FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Public update group_members" ON public.group_members;
CREATE POLICY "Public update group_members" ON public.group_members FOR UPDATE USING (true);

-- 4. Enable Supabase Realtime publication for live member updates
DO $$
BEGIN
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.chit_join_requests;
    EXCEPTION WHEN duplicate_object THEN
        -- already added
    END;
    BEGIN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.group_members;
    EXCEPTION WHEN duplicate_object THEN
        -- already added
    END;
END $$;
