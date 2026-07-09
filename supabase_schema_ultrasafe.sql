-- MyChainLink Schema - Ultra Safe Version (July 2026)
-- This version uses dynamic EXECUTE to catch ALL errors
-- Copy ENTIRE file, paste into Supabase SQL Editor, click Run

-- ============================================================
-- HELPER FUNCTION (returns uuid explicitly)
-- ============================================================
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS uuid AS $$
BEGIN
  RETURN (auth.uid())::uuid;
EXCEPTION WHEN OTHERS THEN
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- TABLES (safe with IF NOT EXISTS)
-- ============================================================
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

-- ============================================================
-- ENABLE RLS
-- ============================================================
ALTER TABLE IF EXISTS public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.live_streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.media_uploads ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RLS POLICIES (using dynamic EXECUTE to catch errors)
-- ============================================================

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "profiles_select" ON public.profiles';
  EXECUTE 'CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true)';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'profiles_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "profiles_update" ON public.profiles';
  EXECUTE 'CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'profiles_update: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "posts_select" ON public.posts';
  EXECUTE 'CREATE POLICY "posts_select" ON public.posts FOR SELECT USING (true)';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'posts_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "posts_insert" ON public.posts';
  EXECUTE 'CREATE POLICY "posts_insert" ON public.posts FOR INSERT WITH CHECK (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'posts_insert: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "posts_update" ON public.posts';
  EXECUTE 'CREATE POLICY "posts_update" ON public.posts FOR UPDATE USING (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'posts_update: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "posts_delete" ON public.posts';
  EXECUTE 'CREATE POLICY "posts_delete" ON public.posts FOR DELETE USING (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'posts_delete: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "likes_select" ON public.likes';
  EXECUTE 'CREATE POLICY "likes_select" ON public.likes FOR SELECT USING (true)';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'likes_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "likes_insert" ON public.likes';
  EXECUTE 'CREATE POLICY "likes_insert" ON public.likes FOR INSERT WITH CHECK (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'likes_insert: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "likes_delete" ON public.likes';
  EXECUTE 'CREATE POLICY "likes_delete" ON public.likes FOR DELETE USING (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'likes_delete: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "comments_select" ON public.comments';
  EXECUTE 'CREATE POLICY "comments_select" ON public.comments FOR SELECT USING (true)';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'comments_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "comments_insert" ON public.comments';
  EXECUTE 'CREATE POLICY "comments_insert" ON public.comments FOR INSERT WITH CHECK (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'comments_insert: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "comments_delete" ON public.comments';
  EXECUTE 'CREATE POLICY "comments_delete" ON public.comments FOR DELETE USING (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'comments_delete: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "follows_select" ON public.follows';
  EXECUTE 'CREATE POLICY "follows_select" ON public.follows FOR SELECT USING (true)';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'follows_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "follows_insert" ON public.follows';
  EXECUTE 'CREATE POLICY "follows_insert" ON public.follows FOR INSERT WITH CHECK (follower_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'follows_insert: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "follows_delete" ON public.follows';
  EXECUTE 'CREATE POLICY "follows_delete" ON public.follows FOR DELETE USING (follower_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'follows_delete: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "conversations_select" ON public.conversations';
  EXECUTE 'CREATE POLICY "conversations_select" ON public.conversations FOR SELECT USING (participant_1 = public.current_user_id() OR participant_2 = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'conversations_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "conversations_insert" ON public.conversations';
  EXECUTE 'CREATE POLICY "conversations_insert" ON public.conversations FOR INSERT WITH CHECK (participant_1 = public.current_user_id() OR participant_2 = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'conversations_insert: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "notifications_select" ON public.notifications';
  EXECUTE 'CREATE POLICY "notifications_select" ON public.notifications FOR SELECT USING (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'notifications_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "stories_select" ON public.stories';
  EXECUTE 'CREATE POLICY "stories_select" ON public.stories FOR SELECT USING (true)';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'stories_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "stories_insert" ON public.stories';
  EXECUTE 'CREATE POLICY "stories_insert" ON public.stories FOR INSERT WITH CHECK (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'stories_insert: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "stories_delete" ON public.stories';
  EXECUTE 'CREATE POLICY "stories_delete" ON public.stories FOR DELETE USING (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'stories_delete: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "reports_select" ON public.reports';
  EXECUTE 'CREATE POLICY "reports_select" ON public.reports FOR SELECT USING (reporter_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'reports_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "reports_insert" ON public.reports';
  EXECUTE 'CREATE POLICY "reports_insert" ON public.reports FOR INSERT WITH CHECK (reporter_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'reports_insert: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "blocks_select" ON public.blocks';
  EXECUTE 'CREATE POLICY "blocks_select" ON public.blocks FOR SELECT USING (blocker_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'blocks_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "blocks_insert" ON public.blocks';
  EXECUTE 'CREATE POLICY "blocks_insert" ON public.blocks FOR INSERT WITH CHECK (blocker_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'blocks_insert: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "blocks_delete" ON public.blocks';
  EXECUTE 'CREATE POLICY "blocks_delete" ON public.blocks FOR DELETE USING (blocker_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'blocks_delete: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "subscriptions_select" ON public.subscriptions';
  EXECUTE 'CREATE POLICY "subscriptions_select" ON public.subscriptions FOR SELECT USING (subscriber_id = public.current_user_id() OR creator_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'subscriptions_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "subscriptions_insert" ON public.subscriptions';
  EXECUTE 'CREATE POLICY "subscriptions_insert" ON public.subscriptions FOR INSERT WITH CHECK (subscriber_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'subscriptions_insert: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "media_select" ON public.media_uploads';
  EXECUTE 'CREATE POLICY "media_select" ON public.media_uploads FOR SELECT USING (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'media_select: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "media_insert" ON public.media_uploads';
  EXECUTE 'CREATE POLICY "media_insert" ON public.media_uploads FOR INSERT WITH CHECK (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'media_insert: %', SQLERRM; END $$;

DO $$
BEGIN
  EXECUTE 'DROP POLICY IF EXISTS "media_delete" ON public.media_uploads';
  EXECUTE 'CREATE POLICY "media_delete" ON public.media_uploads FOR DELETE USING (user_id = public.current_user_id())';
EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'media_delete: %', SQLERRM; END $$;

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
-- TRIGGERS
-- ============================================================
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
-- DONE! Check Output tab for any errors (yellow notices are OK)
-- ============================================================
