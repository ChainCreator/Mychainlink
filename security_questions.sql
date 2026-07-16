-- Security Questions Schema Update
-- Add columns to profiles table for security questions

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS security_question_1 text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS security_answer_1 text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS security_question_2 text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS security_answer_2 text DEFAULT '';

-- Update the updated_at trigger to include these columns (if not already present)
-- No RLS changes needed - profiles_select and profiles_update already cover this
