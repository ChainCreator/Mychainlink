-- MINIMAL SCHEMA - No RLS policies, no auth.uid() comparisons
-- Run this FIRST to fix the database. Then we add policies after.

-- Tables only (no policies, no RLS enabled)
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY,
    display_name text NOT NULL DEFAULT 'User',
    handle text UNIQUE NOT NULL DEFAULT '@user',
    email text DEFAULT '',
    bio text DEFAULT '',
    avatar_url text DEFAULT '',
    location text DEFAULT '',
    is_premium boolean DEFAULT false,
    is_creator boolean DEFAULT false,
    paypal_email text DEFAULT '',
    stripe_account_id text DEFAULT '',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS location text DEFAULT '';

CREATE TABLE IF NOT EXISTS public.posts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    content text NOT NULL DEFAULT '',
    media_url text DEFAULT '',
    media_type text DEFAULT 'none',
    is_camera_only boolean DEFAULT true,
    has_comments boolean DEFAULT true,
    is_premium_only boolean DEFAULT false,
    price decimal(10,2) DEFAULT 0,
    tags text[] DEFAULT '{}',
    location text DEFAULT '',
    font text DEFAULT 'default',
    likes_count integer DEFAULT 0,
    comments_count integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.likes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamptz DEFAULT now(),
    UNIQUE(post_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.comments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id uuid NOT NULL,
    user_id uuid NOT NULL,
    content text NOT NULL DEFAULT '',
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.follows (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    follower_id uuid NOT NULL,
    following_id uuid NOT NULL,
    subscribed boolean DEFAULT false,
    subscription_expires_at timestamptz DEFAULT NULL,
    created_at timestamptz DEFAULT now(),
    UNIQUE(follower_id, following_id)
);

CREATE TABLE IF NOT EXISTS public.conversations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    participant_1 uuid NOT NULL,
    participant_2 uuid NOT NULL,
    last_message_at timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now(),
    UNIQUE(participant_1, participant_2)
);

CREATE TABLE IF NOT EXISTS public.messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    content text NOT NULL DEFAULT '',
    media_url text DEFAULT '',
    media_type text DEFAULT 'text',
    is_read boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    type text NOT NULL,
    actor_id uuid NOT NULL,
    reference_id uuid DEFAULT NULL,
    reference_type text DEFAULT '',
    is_read boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.live_streams (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    title text DEFAULT 'Live Stream',
    is_active boolean DEFAULT true,
    viewer_count integer DEFAULT 0,
    room_id text DEFAULT '',
    started_at timestamptz DEFAULT now(),
    ended_at timestamptz DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS public.stories (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    media_url text NOT NULL DEFAULT '',
    media_type text DEFAULT 'image',
    caption text DEFAULT '',
    viewed_by uuid[] DEFAULT '{}',
    created_at timestamptz DEFAULT now(),
    expires_at timestamptz DEFAULT (now() + interval '24 hours')
);

CREATE TABLE IF NOT EXISTS public.reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id uuid NOT NULL,
    reported_id uuid NOT NULL,
    report_type text NOT NULL DEFAULT 'user',
    reason text NOT NULL DEFAULT '',
    status text DEFAULT 'pending',
    created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.blocks (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    blocker_id uuid NOT NULL,
    blocked_id uuid NOT NULL,
    created_at timestamptz DEFAULT now(),
    UNIQUE(blocker_id, blocked_id)
);

CREATE TABLE IF NOT EXISTS public.subscriptions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    subscriber_id uuid NOT NULL,
    creator_id uuid NOT NULL,
    status text DEFAULT 'active',
    amount decimal(10,2) DEFAULT 0,
    payment_method text DEFAULT 'paypal',
    started_at timestamptz DEFAULT now(),
    expires_at timestamptz DEFAULT (now() + interval '30 days'),
    UNIQUE(subscriber_id, creator_id)
);

CREATE TABLE IF NOT EXISTS public.media_uploads (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL,
    file_path text NOT NULL DEFAULT '',
    file_type text DEFAULT 'image',
    file_size integer DEFAULT 0,
    url text DEFAULT '',
    created_at timestamptz DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, handle, email, location, bio, avatar_url, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'handle', '@user' || substr(NEW.id::text, 1, 6)),
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'location', ''),
    COALESCE(NEW.raw_user_meta_data->>'bio', ''),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
