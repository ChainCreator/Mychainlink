-- Enable RLS on follows table (if not already enabled)
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;

-- Allow users to see follows where they are the follower or being followed
CREATE POLICY "follows_select" ON follows
  FOR SELECT USING (auth.uid() = follower_id OR auth.uid() = following_id);

-- Allow users to insert their own follows
CREATE POLICY "follows_insert" ON follows
  FOR INSERT WITH CHECK (auth.uid() = follower_id);

-- Allow users to delete their own follows
CREATE POLICY "follows_delete" ON follows
  FOR DELETE USING (auth.uid() = follower_id);

-- Allow users to update their own follows (for subscription toggle)
CREATE POLICY "follows_update" ON follows
  FOR UPDATE USING (auth.uid() = follower_id);