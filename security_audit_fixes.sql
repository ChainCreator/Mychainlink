-- ============================================================
-- MYCHAINLINK SECURITY AUDIT FIXES
-- Run this AFTER the main schema and profile_songs migration
-- ============================================================

-- ============================================================
-- 1. NOTIFICATIONS — Missing INSERT policy
-- Notifications are created by the app/system, not users directly
-- But we need a way for authenticated users to create them
-- ============================================================
DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
CREATE POLICY "notifications_insert" ON public.notifications 
FOR INSERT WITH CHECK (user_id = auth.uid());

-- Allow users to mark their own notifications as read
DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
CREATE POLICY "notifications_update" ON public.notifications 
FOR UPDATE USING (user_id = auth.uid());

-- Allow users to delete their own notifications
DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;
CREATE POLICY "notifications_delete" ON public.notifications 
FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- 2. CONVERSATIONS — Missing UPDATE/DELETE
-- Users should be able to update last_message_at or delete their conversations
-- ============================================================
DROP POLICY IF EXISTS "conversations_update" ON public.conversations;
CREATE POLICY "conversations_update" ON public.conversations 
FOR UPDATE USING (participant_1 = auth.uid() OR participant_2 = auth.uid());

DROP POLICY IF EXISTS "conversations_delete" ON public.conversations;
CREATE POLICY "conversations_delete" ON public.conversations 
FOR DELETE USING (participant_1 = auth.uid() OR participant_2 = auth.uid());

-- ============================================================
-- 3. MESSAGES — Missing UPDATE/DELETE
-- Users should be able to delete their own messages
-- ============================================================
DROP POLICY IF EXISTS "messages_update" ON public.messages;
CREATE POLICY "messages_update" ON public.messages 
FOR UPDATE USING (sender_id = auth.uid());

DROP POLICY IF EXISTS "messages_delete" ON public.messages;
CREATE POLICY "messages_delete" ON public.messages 
FOR DELETE USING (sender_id = auth.uid());

-- ============================================================
-- 4. SUBSCRIPTIONS — Missing UPDATE/DELETE
-- Users should be able to cancel/update their subscriptions
-- ============================================================
DROP POLICY IF EXISTS "subscriptions_update" ON public.subscriptions;
CREATE POLICY "subscriptions_update" ON public.subscriptions 
FOR UPDATE USING (subscriber_id = auth.uid() OR creator_id = auth.uid());

DROP POLICY IF EXISTS "subscriptions_delete" ON public.subscriptions;
CREATE POLICY "subscriptions_delete" ON public.subscriptions 
FOR DELETE USING (subscriber_id = auth.uid());

-- ============================================================
-- 5. MEDIA_UPLOADS — Missing UPDATE
-- ============================================================
DROP POLICY IF EXISTS "media_update" ON public.media_uploads;
CREATE POLICY "media_update" ON public.media_uploads 
FOR UPDATE USING (user_id = auth.uid());

-- ============================================================
-- 6. STORIES — Missing UPDATE
-- Users should be able to update story view counts
-- ============================================================
DROP POLICY IF EXISTS "stories_update" ON public.stories;
CREATE POLICY "stories_update" ON public.stories 
FOR UPDATE USING (user_id = auth.uid());

-- ============================================================
-- 7. REPORTS — Missing UPDATE/DELETE
-- Users should be able to update or retract their reports
-- ============================================================
DROP POLICY IF EXISTS "reports_update" ON public.reports;
CREATE POLICY "reports_update" ON public.reports 
FOR UPDATE USING (reporter_id = auth.uid());

DROP POLICY IF EXISTS "reports_delete" ON public.reports;
CREATE POLICY "reports_delete" ON public.reports 
FOR DELETE USING (reporter_id = auth.uid());

-- ============================================================
-- 8. LIKES — Missing UPDATE (not typically needed but for completeness)
-- Likes don't really get updated, only inserted/deleted
-- ============================================================
-- (Skipping — likes table has no columns that need updating)

-- ============================================================
-- 9. COMMENTS — Missing UPDATE
-- Users should be able to edit their own comments
-- ============================================================
DROP POLICY IF EXISTS "comments_update" ON public.comments;
CREATE POLICY "comments_update" ON public.comments 
FOR UPDATE USING (user_id = auth.uid());

-- ============================================================
-- 10. POSTS — Missing UPDATE for likes_count/comments_count
-- The app might want to increment these via RPC, but direct UPDATE is owner-only
-- This is already covered by posts_update policy
-- ============================================================
-- (Already fine — posts_update covers owner edits)

-- ============================================================
-- 11. STORAGE: SONGS BUCKET POLICIES
-- The songs bucket was created in migration_profile_songs.sql
-- But let's make sure policies exist
-- ============================================================
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
-- 12. USER_SONGS — Ensure all policies exist
-- (These were in migration_profile_songs.sql, but let's be safe)
-- ============================================================
DROP POLICY IF EXISTS "user_songs_select" ON public.user_songs;
DROP POLICY IF EXISTS "user_songs_insert" ON public.user_songs;
DROP POLICY IF EXISTS "user_songs_update" ON public.user_songs;
DROP POLICY IF EXISTS "user_songs_delete" ON public.user_songs;

CREATE POLICY "user_songs_select" ON public.user_songs FOR SELECT USING (true);
CREATE POLICY "user_songs_insert" ON public.user_songs FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "user_songs_update" ON public.user_songs FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "user_songs_delete" ON public.user_songs FOR DELETE USING (user_id = auth.uid());

-- ============================================================
-- SUMMARY OF FIXES APPLIED
-- ============================================================
-- notifications: +insert, +update, +delete
-- conversations: +update, +delete
-- messages: +update, +delete
-- subscriptions: +update, +delete
-- media_uploads: +update
-- stories: +update
-- reports: +update, +delete
-- comments: +update
-- storage.songs: full CRUD policies
-- user_songs: full CRUD policies (re-ensured)
-- ============================================================
