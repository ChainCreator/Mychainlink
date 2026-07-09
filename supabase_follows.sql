-- =========================================================
-- MYCHAINLINK: FOLLOWS TABLE
-- Run this in Supabase SQL Editor (https://app.supabase.com)
-- =========================================================

-- 1. Create the follows table
CREATE TABLE IF NOT EXISTS public.follows (
    id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    follower_id uuid NOT NULL,
    following_id uuid NOT NULL,
    subscribed  boolean DEFAULT false,
    created_at  timestamptz DEFAULT now(),

    -- Prevent duplicate follows (same person can't follow same person twice)
    UNIQUE (follower_id, following_id)
);

-- 2. Enable Row Level Security (RLS)
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

-- 3. Allow anyone to read all follows (required for follower/following counts)
DROP POLICY IF EXISTS "Anyone can view follows" ON public.follows;
CREATE POLICY "Anyone can view follows"
    ON public.follows FOR SELECT
    TO anon, authenticated
    USING (true);

-- 4. Only the follower can insert (connect) their own follows
DROP POLICY IF EXISTS "Users can follow" ON public.follows;
CREATE POLICY "Users can follow"
    ON public.follows FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = follower_id);

-- 5. Only the follower can delete (disconnect) their own follows
DROP POLICY IF EXISTS "Users can unfollow" ON public.follows;
CREATE POLICY "Users can unfollow"
    ON public.follows FOR DELETE
    TO authenticated
    USING (auth.uid() = follower_id);

-- 6. Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON public.follows (follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id ON public.follows (following_id);

-- =========================================================
-- Done. Hit "Run" in the SQL Editor. No errors = good to go.
-- =========================================================
