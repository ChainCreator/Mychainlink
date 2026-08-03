-- Fix: Sync auth.users.email to public.profiles.email
-- This migration backfills existing emails and updates the trigger

-- 1. Backfill existing user emails from auth.users to profiles
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id
  AND (p.email IS NULL OR p.email = '');

-- 2. Update the trigger function to include email on new signups
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, handle, avatar_url, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'handle', '@user'),
    COALESCE(NEW.raw_user_meta_data->>'avatar', ''),
    NEW.email
  )
  ON CONFLICT (id) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    handle = EXCLUDED.handle,
    avatar_url = EXCLUDED.avatar_url,
    email = EXCLUDED.email;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Also create a function to search profiles by email (for future use)
CREATE OR REPLACE FUNCTION public.search_profiles(search_term text)
RETURNS TABLE(id uuid, display_name text, handle text, avatar_url text, email text) AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.display_name, p.handle, p.avatar_url, p.email
  FROM public.profiles p
  WHERE 
    p.display_name ILIKE '%' || search_term || '%'
    OR p.handle ILIKE '%' || search_term || '%'
    OR p.email ILIKE '%' || search_term || '%';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
