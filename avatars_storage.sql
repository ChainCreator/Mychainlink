-- Create the avatars storage bucket for profile photos
-- Run this in your Supabase SQL Editor

-- 1. Create the bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Allow authenticated users to upload their own avatars
CREATE POLICY "Allow authenticated uploads" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 3. Allow users to update their own avatars
CREATE POLICY "Allow own avatar updates" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 4. Allow public read access to all avatars
CREATE POLICY "Allow public avatar read" ON storage.objects
FOR SELECT TO anon, authenticated
USING (bucket_id = 'avatars');

-- 5. Allow users to delete their own avatars
CREATE POLICY "Allow own avatar delete" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);
