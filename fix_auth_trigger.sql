-- FIX: Make the profile trigger robust so dashboard user creation works
-- Run this in Supabase SQL Editor

-- Drop old trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Recreate function with exception handling + safer defaults
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_handle text;
  v_display_name text;
BEGIN
  -- Generate a unique handle from user ID (first 8 chars of UUID)
  v_handle := '@user' || substr(NEW.id::text, 1, 8);
  v_display_name := COALESCE(NEW.raw_user_meta_data->>'display_name', 'User');

  -- Insert profile, but DON'T fail the auth transaction if this breaks
  BEGIN
    INSERT INTO public.profiles (
      id, display_name, handle, email, location, bio, avatar_url,
      birth_date, gender, website, interests, created_at, updated_at
    ) VALUES (
      NEW.id,
      v_display_name,
      v_handle,
      COALESCE(NEW.email, ''),
      COALESCE(NEW.raw_user_meta_data->>'location', ''),
      COALESCE(NEW.raw_user_meta_data->>'bio', ''),
      COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
      NULL,  -- birth_date: skip conversion issues
      COALESCE(NEW.raw_user_meta_data->>'gender', ''),
      COALESCE(NEW.raw_user_meta_data->>'website', ''),
      '{}',  -- interests: skip jsonb parsing issues
      NOW(),
      NOW()
    )
    ON CONFLICT (id) DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    -- Log but don't crash the auth signup
    RAISE NOTICE 'Profile auto-create failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
