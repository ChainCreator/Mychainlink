-- ============================================================
-- MYCHAINLINK COMPLETE SCHEMA — PASTE INTO SUPABASE SQL EDITOR
-- Run this AFTER creating the project.
-- ============================================================

-- ============================================================
-- 1. PROFILES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name text NOT NULL DEFAULT 'User',
    handle text UNIQUE,
    email text DEFAULT '',
    bio text DEFAULT '',
    avatar_url text DEFAULT '',
    location text DEFAULT '',
    birth_date date DEFAULT NULL,
    gender text DEFAULT '',
    website text DEFAULT '',
    interests text[] DEFAULT '{}',
    is_premium boolean DEFAULT false,
    is_creator boolean DEFAULT false,
    paypal_email text DEFAULT '',
    stripe_account_id text DEFAULT '',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Add missing columns if table already existed
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS location text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS birth_date date DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS gender text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS website text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS interests text[] DEFAULT '{}';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_premium boolean DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_creator boolean DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS paypal_email text DEFAULT '';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS stripe_account_id text DEFAULT '';

-- Make handle nullable (in case it was created NOT NULL before)
ALTER TABLE public.profiles ALTER COLUMN handle DROP NOT NULL;

-- ============================================================
-- 2. POSTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.posts (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
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

-- ============================================================
-- 3. LIKES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.likes (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now(),
    UNIQUE(post_id, user_id)
);

-- ============================================================
-- 4. COMMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.comments (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    post_id uuid NOT NULL,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content text NOT NULL DEFAULT '',
    created_at timestamptz DEFAULT now()
);

-- ============================================================
-- 5. FOLLOWS (Connects)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.follows (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    follower_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    following_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscribed boolean DEFAULT false,
    subscription_expires_at timestamptz DEFAULT NULL,
    created_at timestamptz DEFAULT now(),
    UNIQUE(follower_id, following_id)
);

-- ============================================================
-- 6. CONVERSATIONS (DMs)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.conversations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    participant_1 uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    participant_2 uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    last_message_at timestamptz DEFAULT now(),
    created_at timestamptz DEFAULT now(),
    UNIQUE(participant_1, participant_2)
);

-- ============================================================
-- 7. MESSAGES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content text NOT NULL DEFAULT '',
    media_url text DEFAULT '',
    media_type text DEFAULT 'text',
    is_read boolean DEFAULT false,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- ============================================================
-- 8. NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type text NOT NULL,
    actor_id uuid NOT NULL,
    reference_id uuid DEFAULT NULL,
    reference_type text DEFAULT '',
    is_read boolean DEFAULT false,
    created_at timestamptz DEFAULT now()
);

-- ============================================================
-- 9. LIVE STREAMS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.live_streams (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title text DEFAULT 'Live Stream',
    is_active boolean DEFAULT true,
    viewer_count integer DEFAULT 0,
    room_id text DEFAULT '',
    started_at timestamptz DEFAULT now(),
    ended_at timestamptz DEFAULT NULL
);

-- ============================================================
-- 10. STORIES (24h Ephemeral)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.stories (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    media_url text NOT NULL DEFAULT '',
    media_type text DEFAULT 'image',
    caption text DEFAULT '',
    viewed_by uuid[] DEFAULT '{}',
    created_at timestamptz DEFAULT now(),
    expires_at timestamptz DEFAULT (now() + interval '24 hours')
);

-- ============================================================
-- 11. REPORTS (Moderation)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reported_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    report_type text NOT NULL DEFAULT 'user',
    reason text NOT NULL DEFAULT '',
    status text DEFAULT 'pending',
    created_at timestamptz DEFAULT now()
);

-- ============================================================
-- 12. BLOCKS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.blocks (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now(),
    UNIQUE(blocker_id, blocked_id)
);

-- ============================================================
-- 13. SUBSCRIPTIONS (Premium Payments)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    subscriber_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    creator_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status text DEFAULT 'active',
    amount decimal(10,2) DEFAULT 0,
    payment_method text DEFAULT 'paypal',
    started_at timestamptz DEFAULT now(),
    expires_at timestamptz DEFAULT (now() + interval '30 days'),
    UNIQUE(subscriber_id, creator_id)
);

-- ============================================================
-- 14. MEDIA_UPLOADS (Track files in Storage)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.media_uploads (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    file_path text NOT NULL DEFAULT '',
    file_type text DEFAULT 'image',
    file_size integer DEFAULT 0,
    url text DEFAULT '',
    created_at timestamptz DEFAULT now()
);

-- ============================================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_uploads ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RLS POLICIES
-- ============================================================

-- PROFILES
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (id = auth.uid());

-- POSTS
DROP POLICY IF EXISTS "posts_select" ON public.posts;
DROP POLICY IF EXISTS "posts_insert" ON public.posts;
DROP POLICY IF EXISTS "posts_update" ON public.posts;
DROP POLICY IF EXISTS "posts_delete" ON public.posts;
CREATE POLICY "posts_select" ON public.posts FOR SELECT USING (true);
CREATE POLICY "posts_insert" ON public.posts FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "posts_update" ON public.posts FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "posts_delete" ON public.posts FOR DELETE USING (user_id = auth.uid());

-- LIKES
DROP POLICY IF EXISTS "likes_select" ON public.likes;
DROP POLICY IF EXISTS "likes_insert" ON public.likes;
DROP POLICY IF EXISTS "likes_delete" ON public.likes;
CREATE POLICY "likes_select" ON public.likes FOR SELECT USING (true);
CREATE POLICY "likes_insert" ON public.likes FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "likes_delete" ON public.likes FOR DELETE USING (user_id = auth.uid());

-- COMMENTS
DROP POLICY IF EXISTS "comments_select" ON public.comments;
DROP POLICY IF EXISTS "comments_insert" ON public.comments;
DROP POLICY IF EXISTS "comments_update" ON public.comments;
DROP POLICY IF EXISTS "comments_delete" ON public.comments;
CREATE POLICY "comments_select" ON public.comments FOR SELECT USING (true);
CREATE POLICY "comments_insert" ON public.comments FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "comments_update" ON public.comments FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "comments_delete" ON public.comments FOR DELETE USING (user_id = auth.uid());

-- FOLLOWS
DROP POLICY IF EXISTS "follows_select" ON public.follows;
DROP POLICY IF EXISTS "follows_insert" ON public.follows;
DROP POLICY IF EXISTS "follows_delete" ON public.follows;
CREATE POLICY "follows_select" ON public.follows FOR SELECT USING (true);
CREATE POLICY "follows_insert" ON public.follows FOR INSERT WITH CHECK (follower_id = auth.uid());
CREATE POLICY "follows_delete" ON public.follows FOR DELETE USING (follower_id = auth.uid());

-- CONVERSATIONS
DROP POLICY IF EXISTS "conversations_select" ON public.conversations;
DROP POLICY IF EXISTS "conversations_insert" ON public.conversations;
DROP POLICY IF EXISTS "conversations_update" ON public.conversations;
DROP POLICY IF EXISTS "conversations_delete" ON public.conversations;
CREATE POLICY "conversations_select" ON public.conversations FOR SELECT USING (
  participant_1 = auth.uid() OR participant_2 = auth.uid()
);
CREATE POLICY "conversations_insert" ON public.conversations FOR INSERT WITH CHECK (
  participant_1 = auth.uid() OR participant_2 = auth.uid()
);
CREATE POLICY "conversations_update" ON public.conversations FOR UPDATE USING (
  participant_1 = auth.uid() OR participant_2 = auth.uid()
);
CREATE POLICY "conversations_delete" ON public.conversations FOR DELETE USING (
  participant_1 = auth.uid() OR participant_2 = auth.uid()
);

-- MESSAGES
DROP POLICY IF EXISTS "messages_select" ON public.messages;
DROP POLICY IF EXISTS "messages_insert" ON public.messages;
DROP POLICY IF EXISTS "messages_update" ON public.messages;
DROP POLICY IF EXISTS "messages_delete" ON public.messages;
CREATE POLICY "messages_select" ON public.messages FOR SELECT USING (
  sender_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id
    AND (c.participant_1 = auth.uid() OR c.participant_2 = auth.uid())
  )
);
CREATE POLICY "messages_insert" ON public.messages FOR INSERT WITH CHECK (
  sender_id = auth.uid() AND
  EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id
    AND (c.participant_1 = auth.uid() OR c.participant_2 = auth.uid())
  )
);
CREATE POLICY "messages_update" ON public.messages FOR UPDATE USING (sender_id = auth.uid());
CREATE POLICY "messages_delete" ON public.messages FOR DELETE USING (sender_id = auth.uid());

-- NOTIFICATIONS
DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;
CREATE POLICY "notifications_select" ON public.notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "notifications_insert" ON public.notifications FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "notifications_update" ON public.notifications FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "notifications_delete" ON public.notifications FOR DELETE USING (user_id = auth.uid());

-- LIVE STREAMS
DROP POLICY IF EXISTS "streams_select" ON public.live_streams;
DROP POLICY IF EXISTS "streams_all" ON public.live_streams;
CREATE POLICY "streams_select" ON public.live_streams FOR SELECT USING (is_active = true);
CREATE POLICY "streams_all" ON public.live_streams FOR ALL USING (user_id = auth.uid());

-- STORIES
DROP POLICY IF EXISTS "stories_select" ON public.stories;
DROP POLICY IF EXISTS "stories_insert" ON public.stories;
DROP POLICY IF EXISTS "stories_update" ON public.stories;
DROP POLICY IF EXISTS "stories_delete" ON public.stories;
CREATE POLICY "stories_select" ON public.stories FOR SELECT USING (true);
CREATE POLICY "stories_insert" ON public.stories FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "stories_update" ON public.stories FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "stories_delete" ON public.stories FOR DELETE USING (user_id = auth.uid());

-- REPORTS
DROP POLICY IF EXISTS "reports_select" ON public.reports;
DROP POLICY IF EXISTS "reports_insert" ON public.reports;
DROP POLICY IF EXISTS "reports_update" ON public.reports;
DROP POLICY IF EXISTS "reports_delete" ON public.reports;
CREATE POLICY "reports_select" ON public.reports FOR SELECT USING (reporter_id = auth.uid());
CREATE POLICY "reports_insert" ON public.reports FOR INSERT WITH CHECK (reporter_id = auth.uid());
CREATE POLICY "reports_update" ON public.reports FOR UPDATE USING (reporter_id = auth.uid());
CREATE POLICY "reports_delete" ON public.reports FOR DELETE USING (reporter_id = auth.uid());

-- BLOCKS
DROP POLICY IF EXISTS "blocks_select" ON public.blocks;
DROP POLICY IF EXISTS "blocks_insert" ON public.blocks;
DROP POLICY IF EXISTS "blocks_delete" ON public.blocks;
CREATE POLICY "blocks_select" ON public.blocks FOR SELECT USING (blocker_id = auth.uid());
CREATE POLICY "blocks_insert" ON public.blocks FOR INSERT WITH CHECK (blocker_id = auth.uid());
CREATE POLICY "blocks_delete" ON public.blocks FOR DELETE USING (blocker_id = auth.uid());

-- SUBSCRIPTIONS
DROP POLICY IF EXISTS "subscriptions_select" ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions_insert" ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions_update" ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions_delete" ON public.subscriptions;
CREATE POLICY "subscriptions_select" ON public.subscriptions FOR SELECT USING (
  subscriber_id = auth.uid() OR creator_id = auth.uid()
);
CREATE POLICY "subscriptions_insert" ON public.subscriptions FOR INSERT WITH CHECK (subscriber_id = auth.uid());
CREATE POLICY "subscriptions_update" ON public.subscriptions FOR UPDATE USING (
  subscriber_id = auth.uid() OR creator_id = auth.uid()
);
CREATE POLICY "subscriptions_delete" ON public.subscriptions FOR DELETE USING (subscriber_id = auth.uid());

-- MEDIA_UPLOADS
DROP POLICY IF EXISTS "media_select" ON public.media_uploads;
DROP POLICY IF EXISTS "media_insert" ON public.media_uploads;
DROP POLICY IF EXISTS "media_update" ON public.media_uploads;
DROP POLICY IF EXISTS "media_delete" ON public.media_uploads;
CREATE POLICY "media_select" ON public.media_uploads FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "media_insert" ON public.media_uploads FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "media_update" ON public.media_uploads FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "media_delete" ON public.media_uploads FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_likes_post_id ON public.likes(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_post_id ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_follows_follower ON public.follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON public.follows(following_id);
CREATE INDEX IF NOT EXISTS idx_messages_convo ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversations_last ON public.conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_user ON public.stories(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_expires ON public.stories(expires_at);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);
CREATE INDEX IF NOT EXISTS idx_blocks_blocker ON public.blocks(blocker_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_subscriber ON public.subscriptions(subscriber_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_creator ON public.subscriptions(creator_id);
CREATE INDEX IF NOT EXISTS idx_media_user ON public.media_uploads(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_handle ON public.profiles(handle);

-- ============================================================
-- STORAGE: AVATARS BUCKET
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies
DROP POLICY IF EXISTS "avatars_upload" ON storage.objects;
DROP POLICY IF EXISTS "avatars_update" ON storage.objects;
DROP POLICY IF EXISTS "avatars_read" ON storage.objects;
DROP POLICY IF EXISTS "avatars_delete" ON storage.objects;

CREATE POLICY "avatars_upload" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars');

CREATE POLICY "avatars_update" ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id = 'avatars');

CREATE POLICY "avatars_read" ON storage.objects
FOR SELECT TO anon, authenticated
USING (bucket_id = 'avatars');

CREATE POLICY "avatars_delete" ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id = 'avatars');

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Auto-update conversation last_message_at
CREATE OR REPLACE FUNCTION public.update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.conversations SET last_message_at = NEW.created_at WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS on_message_inserted ON public.messages;
CREATE TRIGGER on_message_inserted
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.update_conversation_last_message();

-- Auto-delete expired stories
CREATE OR REPLACE FUNCTION public.delete_expired_stories()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM public.stories WHERE expires_at < now();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS on_story_inserted ON public.stories;
CREATE TRIGGER on_story_inserted
    AFTER INSERT ON public.stories
    FOR EACH STATEMENT
    EXECUTE FUNCTION public.delete_expired_stories();

-- Auto-create profile on signup (ROBUST VERSION)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  v_handle text;
BEGIN
  v_handle := '@user' || substr(NEW.id::text, 1, 8);

  INSERT INTO public.profiles (
    id, display_name, handle, email, location, bio, avatar_url,
    birth_date, gender, website, interests, created_at, updated_at
  ) VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', 'User'),
    v_handle,
    COALESCE(NEW.email, ''),
    COALESCE(NEW.raw_user_meta_data->>'location', ''),
    COALESCE(NEW.raw_user_meta_data->>'bio', ''),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', ''),
    NULL,
    COALESCE(NEW.raw_user_meta_data->>'gender', ''),
    COALESCE(NEW.raw_user_meta_data->>'website', ''),
    COALESCE(ARRAY(SELECT jsonb_array_elements_text(NEW.raw_user_meta_data->'interests')), '{}'),
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

-- ============================================================
-- DONE!
-- ============================================================
