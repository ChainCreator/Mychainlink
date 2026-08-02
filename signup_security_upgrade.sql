-- ============================================================
-- Sign-up security upgrade
-- Birthday + two hashed security questions on every new profile
-- Run this in the Supabase SQL Editor. Safe to run more than once.
-- ============================================================

-- 1. Columns the new sign-up form writes to.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS birth_date          date DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS security_question_1 text DEFAULT '',
  ADD COLUMN IF NOT EXISTS security_answer_1   text DEFAULT '',
  ADD COLUMN IF NOT EXISTS security_question_2 text DEFAULT '',
  ADD COLUMN IF NOT EXISTS security_answer_2   text DEFAULT '';

COMMENT ON COLUMN public.profiles.birth_date IS
  'Date of birth. Used to enforce the 13+ minimum and to show a birthday badge. Only day and month are ever exposed to other users.';
COMMENT ON COLUMN public.profiles.security_answer_1 IS
  'SHA-256 of the normalised answer, stored as "sha256:<hex>". Never a plaintext answer for accounts created after this migration.';
COMMENT ON COLUMN public.profiles.security_answer_2 IS
  'SHA-256 of the normalised answer, stored as "sha256:<hex>". Never a plaintext answer for accounts created after this migration.';

-- 2. Nobody should be able to read another account's security answers.
--    (Answers are already hashed client-side; this keeps the hashes private too.)
REVOKE SELECT (security_answer_1, security_answer_2) ON public.profiles FROM anon, authenticated;

-- 3. Carry the new sign-up metadata through to the profile row.
--    NULLIF guards the date cast: an empty string would raise instead of
--    falling back to NULL.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (
    id, display_name, handle, email, location, bio, avatar_url,
    birth_date, gender, website, interests,
    security_question_1, security_answer_1,
    security_question_2, security_answer_2,
    created_at, updated_at
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'handle', '@user' || substr(NEW.id::text, 1, 6)),
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'location', ''),
    COALESCE(NEW.raw_user_meta_data->>'bio', ''),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', NEW.raw_user_meta_data->>'avatar', ''),
    NULLIF(NEW.raw_user_meta_data->>'birth_date', '')::date,
    COALESCE(NEW.raw_user_meta_data->>'gender', ''),
    COALESCE(NEW.raw_user_meta_data->>'website', ''),
    COALESCE(ARRAY(SELECT jsonb_array_elements_text(NEW.raw_user_meta_data->'interests')), '{}'),
    COALESCE(NEW.raw_user_meta_data->>'security_question_1', ''),
    COALESCE(NEW.raw_user_meta_data->>'security_answer_1', ''),
    COALESCE(NEW.raw_user_meta_data->>'security_question_2', ''),
    COALESCE(NEW.raw_user_meta_data->>'security_answer_2', ''),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Make sure the trigger itself is attached.
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
