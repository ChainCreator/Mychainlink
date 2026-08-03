-- ============================================================
-- MYCHAINLINK PROFILE SONGS MIGRATION
-- Run this in your Supabase SQL Editor to add cross-device song sync
-- ============================================================

-- 1. USER_SONGS TABLE (stores profile songs for all users)
CREATE TABLE IF NOT EXISTS public.user_songs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title text NOT NULL DEFAULT 'Untitled',
    artist text NOT NULL DEFAULT 'Unknown artist',
    song_url text NOT NULL DEFAULT '',
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    UNIQUE(user_id)
);

-- 2. ENABLE RLS
ALTER TABLE public.user_songs ENABLE ROW LEVEL SECURITY;

-- 3. RLS POLICIES
DROP POLICY IF EXISTS "user_songs_select" ON public.user_songs;
DROP POLICY IF EXISTS "user_songs_insert" ON public.user_songs;
DROP POLICY IF EXISTS "user_songs_update" ON public.user_songs;
DROP POLICY IF EXISTS "user_songs_delete" ON public.user_songs;

CREATE POLICY "user_songs_select" ON public.user_songs FOR SELECT USING (true);
CREATE POLICY "user_songs_insert" ON public.user_songs FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "user_songs_update" ON public.user_songs FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "user_songs_delete" ON public.user_songs FOR DELETE USING (user_id = auth.uid());

-- 4. INDEX
CREATE INDEX IF NOT EXISTS idx_user_songs_user_id ON public.user_songs(user_id);

-- 5. STORAGE BUCKET FOR SONGS
INSERT INTO storage.buckets (id, name, public)
VALUES ('songs', 'songs', true)
ON CONFLICT (id) DO NOTHING;

-- 6. STORAGE POLICIES FOR SONGS
DROP POLICY IF EXISTS "songs_upload" ON storage.objects;
DROP POLICY IF EXISTS "songs_update" ON storage.objects;
DROP POLICY IF EXISTS "songs_read" ON storage.objects;
DROP POLICY IF EXISTS "songs_delete" ON storage.objects;

CREATE POLICY "songs_upload" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'songs');

CREATE POLICY "songs_update" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'songs');

CREATE POLICY "songs_read" ON storage.objects
FOR SELECT TO anon, authenticated
USING (bucket_id = 'songs');

CREATE POLICY "songs_delete" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'songs');

-- ============================================================
-- DONE! Profile songs now sync across all devices
-- ============================================================
