-- MyChainLink Complete Schema (Updated July 2026)
-- Paste into Supabase SQL Editor and click Run
-- Safe to run multiple times -- uses IF NOT EXISTS everywhere

-- ============================================================
-- 1. PROFILES
-- ============================================================
DO $$
BEGIN
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
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'profiles table may already exist: %', SQLERRM;
END $$;

-- Add missing columns to existing profiles
DO $$
BEGIN
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text DEFAULT '';
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS location text DEFAULT '';
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'columns may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 2. POSTS
-- ============================================================
DO $$
BEGIN
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
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'posts table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 3. LIKES
-- ============================================================
DO $$
BEGIN
  CREATE TABLE IF NOT EXISTS public.likes (
      id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
      post_id uuid NOT NULL,
      user_id uuid NOT NULL,
      created_at timestamptz DEFAULT now(),
      UNIQUE(post_id, user_id)
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'likes table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 4. COMMENTS
-- ============================================================
DO $$
BEGIN
  CREATE TABLE IF NOT EXISTS public.comments (
      id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
      post_id uuid NOT NULL,
      user_id uuid NOT NULL,
      content text NOT NULL DEFAULT '',
      created_at timestamptz DEFAULT now()
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'comments table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 5. FOLLOWS (Connects)
-- ============================================================
DO $$
BEGIN
  CREATE TABLE IF NOT EXISTS public.follows (
      id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
      follower_id uuid NOT NULL,
      following_id uuid NOT NULL,
      subscribed boolean DEFAULT false,
      subscription_expires_at timestamptz DEFAULT NULL,
      created_at timestamptz DEFAULT now(),
      UNIQUE(follower_id, following_id)
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'follows table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 6. CONVERSATIONS (DMs)
-- ============================================================
DO $$
BEGIN
  CREATE TABLE IF NOT EXISTS public.conversations (
      id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
      participant_1 uuid NOT NULL,
      participant_2 uuid NOT NULL,
      last_message_at timestamptz DEFAULT now(),
      created_at timestamptz DEFAULT now(),
      UNIQUE(participant_1, participant_2)
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'conversations table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 7. MESSAGES
-- ============================================================
DO $$
BEGIN
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
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'messages table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 8. NOTIFICATIONS
-- ============================================================
DO $$
BEGIN
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
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'notifications table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 9. LIVE STREAMS
-- ============================================================
DO $$
BEGIN
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
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'live_streams table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 10. STORIES (24h Ephemeral)
-- ============================================================
DO $$
BEGIN
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
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'stories table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 11. REPORTS (Moderation)
-- ============================================================
DO $$
BEGIN
  CREATE TABLE IF NOT EXISTS public.reports (
      id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
      reporter_id uuid NOT NULL,
      reported_id uuid NOT NULL,
      report_type text NOT NULL DEFAULT 'user',
      reason text NOT NULL DEFAULT '',
      status text DEFAULT 'pending',
      created_at timestamptz DEFAULT now()
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'reports table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 12. BLOCKS
-- ============================================================
DO $$
BEGIN
  CREATE TABLE IF NOT EXISTS public.blocks (
      id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
      blocker_id uuid NOT NULL,
      blocked_id uuid NOT NULL,
      created_at timestamptz DEFAULT now(),
      UNIQUE(blocker_id, blocked_id)
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'blocks table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 13. SUBSCRIPTIONS (Premium Payments)
-- ============================================================
DO $$
BEGIN
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
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'subscriptions table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- 14. MEDIA_UPLOADS (Track files in Storage)
-- ============================================================
DO $$
BEGIN
  CREATE TABLE IF NOT EXISTS public.media_uploads (
      id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
      user_id uuid NOT NULL,
      file_path text NOT NULL DEFAULT '',
      file_type text DEFAULT 'image',
      file_size integer DEFAULT 0,
      url text DEFAULT '',
      created_at timestamptz DEFAULT now()
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'media_uploads table may already exist: %', SQLERRM;
END $$;

-- ============================================================
-- ENABLE ROW LEVEL SECURITY (RLS) ON ALL TABLES
-- ============================================================
DO $$ BEGIN ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'profiles RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'posts RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'likes RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'comments RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'follows RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'conversations RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'messages RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'notifications RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.live_streams ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'live_streams RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.stories ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'stories RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'reports RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'blocks RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.subscriptions ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'subscriptions RLS: %', SQLERRM; END $$;
DO $$ BEGIN ALTER TABLE public.media_uploads ENABLE ROW LEVEL SECURITY;
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'media_uploads RLS: %', SQLERRM; END $$;

-- ============================================================
-- RLS POLICIES
-- ============================================================

-- PROFILES: Anyone can view, only self can update
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (id = auth.uid()::uuid);

-- POSTS: Anyone can view, only self can edit/delete
DROP POLICY IF EXISTS "posts_select" ON public.posts;
DROP POLICY IF EXISTS "posts_insert" ON public.posts;
DROP POLICY IF EXISTS "posts_update" ON public.posts;
DROP POLICY IF EXISTS "posts_delete" ON public.posts;
CREATE POLICY "posts_select" ON public.posts FOR SELECT USING (true);
CREATE POLICY "posts_insert" ON public.posts FOR INSERT WITH CHECK (user_id = auth.uid()::uuid);
CREATE POLICY "posts_update" ON public.posts FOR UPDATE USING (user_id = auth.uid()::uuid);
CREATE POLICY "posts_delete" ON public.posts FOR DELETE USING (user_id = auth.uid()::uuid);

-- LIKES: Anyone can view, only self can add/remove
DROP POLICY IF EXISTS "likes_select" ON public.likes;
DROP POLICY IF EXISTS "likes_insert" ON public.likes;
DROP POLICY IF EXISTS "likes_delete" ON public.likes;
CREATE POLICY "likes_select" ON public.likes FOR SELECT USING (true);
CREATE POLICY "likes_insert" ON public.likes FOR INSERT WITH CHECK (user_id = auth.uid()::uuid);
CREATE POLICY "likes_delete" ON public.likes FOR DELETE USING (user_id = auth.uid()::uuid);

-- COMMENTS: Anyone can view, only self can post/delete
DROP POLICY IF EXISTS "comments_select" ON public.comments;
DROP POLICY IF EXISTS "comments_insert" ON public.comments;
DROP POLICY IF EXISTS "comments_delete" ON public.comments;
CREATE POLICY "comments_select" ON public.comments FOR SELECT USING (true);
CREATE POLICY "comments_insert" ON public.comments FOR INSERT WITH CHECK (user_id = auth.uid()::uuid);
CREATE POLICY "comments_delete" ON public.comments FOR DELETE USING (user_id = auth.uid()::uuid);

-- FOLLOWS: Anyone can view, only self can follow/unfollow
DROP POLICY IF EXISTS "follows_select" ON public.follows;
DROP POLICY IF EXISTS "follows_insert" ON public.follows;
DROP POLICY IF EXISTS "follows_delete" ON public.follows;
CREATE POLICY "follows_select" ON public.follows FOR SELECT USING (true);
CREATE POLICY "follows_insert" ON public.follows FOR INSERT WITH CHECK (follower_id = auth.uid()::uuid);
CREATE POLICY "follows_delete" ON public.follows FOR DELETE USING (follower_id = auth.uid()::uuid);

-- CONVERSATIONS: Only participants can see
DROP POLICY IF EXISTS "conversations_select" ON public.conversations;
DROP POLICY IF EXISTS "conversations_insert" ON public.conversations;
CREATE POLICY "conversations_select" ON public.conversations FOR SELECT USING (
  participant_1 = auth.uid()::uuid OR participant_2 = auth.uid()::uuid
);
CREATE POLICY "conversations_insert" ON public.conversations FOR INSERT WITH CHECK (
  participant_1 = auth.uid()::uuid OR participant_2 = auth.uid()::uuid
);

-- MESSAGES: Only conversation participants
DROP POLICY IF EXISTS "messages_select" ON public.messages;
DROP POLICY IF EXISTS "messages_insert" ON public.messages;
CREATE POLICY "messages_select" ON public.messages FOR SELECT USING (
  sender_id = auth.uid()::uuid OR
  EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id
    AND (c.participant_1 = auth.uid()::uuid OR c.participant_2 = auth.uid()::uuid)
  )
);
CREATE POLICY "messages_insert" ON public.messages FOR INSERT WITH CHECK (
  sender_id = auth.uid()::uuid AND
  EXISTS (
    SELECT 1 FROM public.conversations c
    WHERE c.id = messages.conversation_id
    AND (c.participant_1 = auth.uid()::uuid OR c.participant_2 = auth.uid()::uuid)
  )
);

-- NOTIFICATIONS: Only recipient
DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
CREATE POLICY "notifications_select" ON public.notifications FOR SELECT USING (user_id = auth.uid()::uuid);

-- LIVE STREAMS: Active streams public, manage own
DROP POLICY IF EXISTS "streams_select" ON public.live_streams;
DROP POLICY IF EXISTS "streams_all" ON public.live_streams;
CREATE POLICY "streams_select" ON public.live_streams FOR SELECT USING (is_active = true);
CREATE POLICY "streams_all" ON public.live_streams FOR ALL USING (user_id = auth.uid()::uuid);

-- STORIES: Viewable, only self can create/delete
DROP POLICY IF EXISTS "stories_select" ON public.stories;
DROP POLICY IF EXISTS "stories_insert" ON public.stories;
DROP POLICY IF EXISTS "stories_delete" ON public.stories;
CREATE POLICY "stories_select" ON public.stories FOR SELECT USING (true);
CREATE POLICY "stories_insert" ON public.stories FOR INSERT WITH CHECK (user_id = auth.uid()::uuid);
CREATE POLICY "stories_delete" ON public.stories FOR DELETE USING (user_id = auth.uid()::uuid);

-- REPORTS: Only reporter can view their own
DROP POLICY IF EXISTS "reports_select" ON public.reports;
DROP POLICY IF EXISTS "reports_insert" ON public.reports;
CREATE POLICY "reports_select" ON public.reports FOR SELECT USING (reporter_id = auth.uid()::uuid);
CREATE POLICY "reports_insert" ON public.reports FOR INSERT WITH CHECK (reporter_id = auth.uid()::uuid);

-- BLOCKS: Only blocker can view/manage
DROP POLICY IF EXISTS "blocks_select" ON public.blocks;
DROP POLICY IF EXISTS "blocks_insert" ON public.blocks;
DROP POLICY IF EXISTS "blocks_delete" ON public.blocks;
CREATE POLICY "blocks_select" ON public.blocks FOR SELECT USING (blocker_id = auth.uid()::uuid);
CREATE POLICY "blocks_insert" ON public.blocks FOR INSERT WITH CHECK (blocker_id = auth.uid()::uuid);
CREATE POLICY "blocks_delete" ON public.blocks FOR DELETE USING (blocker_id = auth.uid()::uuid);

-- SUBSCRIPTIONS: Subscriber and creator can view
DROP POLICY IF EXISTS "subscriptions_select" ON public.subscriptions;
DROP POLICY IF EXISTS "subscriptions_insert" ON public.subscriptions;
CREATE POLICY "subscriptions_select" ON public.subscriptions FOR SELECT USING (
  subscriber_id = auth.uid()::uuid OR creator_id = auth.uid()::uuid
);
CREATE POLICY "subscriptions_insert" ON public.subscriptions FOR INSERT WITH CHECK (subscriber_id = auth.uid()::uuid);

-- MEDIA_UPLOADS: Only owner can view/manage
DROP POLICY IF EXISTS "media_select" ON public.media_uploads;
DROP POLICY IF EXISTS "media_insert" ON public.media_uploads;
DROP POLICY IF EXISTS "media_delete" ON public.media_uploads;
CREATE POLICY "media_select" ON public.media_uploads FOR SELECT USING (user_id = auth.uid()::uuid);
CREATE POLICY "media_insert" ON public.media_uploads FOR INSERT WITH CHECK (user_id = auth.uid()::uuid);
CREATE POLICY "media_delete" ON public.media_uploads FOR DELETE USING (user_id = auth.uid()::uuid);

-- ============================================================
-- INDEXES (Speed up queries)
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
-- TRIGGERS
-- ============================================================

-- Auto-update conversation last_message_at when new message arrives
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

-- Auto-delete expired stories (runs every insert)
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

-- Auto-create profile on signup
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

-- ============================================================
-- DONE! Check the Output tab for any notices (yellow warnings are OK)
-- ============================================================
