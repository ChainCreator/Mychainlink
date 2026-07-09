#!/bin/bash
# MyChainLink API Setup Script
# Run this in your Chromebook Linux terminal

set -e

echo "=== MyChainLink API Setup ==="

# Create project folder
mkdir -p ~/mychainlink-api
cd ~/mychainlink-api

# Create package.json
cat > package.json << 'EOF'
{
  "name": "mychainlink-api",
  "version": "1.0.0",
  "description": "MyChainLink backend API",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "@supabase/supabase-js": "^2.39.0",
    "dotenv": "^16.3.1"
  }
}
EOF

echo "Created package.json"

# Create .env
cat > .env << 'EOF'
SUPABASE_URL=https://vjaevzohcnejkaduvtno.supabase.co
SUPABASE_SERVICE_KEY=sbp_2ab97e36d36535ba6c753515d82d67b3dc2a18d0
PORT=3001
EOF

echo "Created .env"

# Create server.js (split into parts due to size)
echo "Creating server.js..."

cat > server.js << 'ENDOFFILE'
const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

app.use(cors());
app.use(express.json({ limit: '10mb' }));

const authMiddleware = async (req, res, next) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token' });
  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) return res.status(401).json({ error: 'Invalid token' });
  req.user = user;
  next();
};

// ========== PROFILES ==========
app.get('/api/profiles/:handle', async (req, res) => {
  const { data, error } = await supabase
    .from('profiles').select('*').eq('handle', req.params.handle).single();
  if (error) return res.status(404).json({ error: 'Profile not found' });
  res.json(data);
});

app.get('/api/search', async (req, res) => {
  const q = req.query.q;
  if (!q) return res.json([]);
  const { data, error } = await supabase
    .from('profiles')
    .select('id, display_name, handle, avatar_url, bio, is_creator')
    .or(\`display_name.ilike.%\${q}%,handle.ilike.%\${q}%\`)
    .limit(20);
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.put('/api/profiles/:id', authMiddleware, async (req, res) => {
  if (req.params.id !== req.user.id) return res.status(403).json({ error: 'Not allowed' });
  const { display_name, bio, avatar_url, location, paypal_email } = req.body;
  const { data, error } = await supabase
    .from('profiles')
    .update({ display_name, bio, avatar_url, location, paypal_email, updated_at: new Date() })
    .eq('id', req.params.id).select().single();
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ========== POSTS ==========
app.get('/api/posts', async (req, res) => {
  const { data, error } = await supabase
    .from('posts')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .order('created_at', { ascending: false }).limit(50);
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.get('/api/feed', authMiddleware, async (req, res) => {
  const { data: follows } = await supabase.from('follows').select('following_id').eq('follower_id', req.user.id);
  const followingIds = (follows || []).map(f => f.following_id);
  followingIds.push(req.user.id);
  const { data, error } = await supabase
    .from('posts')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .in('user_id', followingIds)
    .order('created_at', { ascending: false }).limit(50);
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.post('/api/posts', authMiddleware, async (req, res) => {
  const { content, media_url, media_type, tags, location, font, is_premium_only, price } = req.body;
  const { data, error } = await supabase.from('posts').insert({
    user_id: req.user.id,
    content: content || '',
    media_url: media_url || '',
    media_type: media_type || 'none',
    tags: tags || [],
    location: location || '',
    font: font || 'default',
    is_premium_only: is_premium_only || false,
    price: price || 0
  }).select().single();
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.delete('/api/posts/:id', authMiddleware, async (req, res) => {
  const { error } = await supabase.from('posts').delete().eq('id', req.params.id).eq('user_id', req.user.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ========== LIKES ==========
app.post('/api/posts/:id/like', authMiddleware, async (req, res) => {
  const postId = req.params.id;
  const { data: existing } = await supabase.from('likes').select('*').eq('post_id', postId).eq('user_id', req.user.id).single();
  if (existing) {
    await supabase.from('likes').delete().eq('post_id', postId).eq('user_id', req.user.id);
    await supabase.rpc('decrement_likes', { post_id: postId });
    return res.json({ liked: false });
  }
  const { error } = await supabase.from('likes').insert({ post_id: postId, user_id: req.user.id });
  if (error) return res.status(500).json({ error: error.message });
  await supabase.rpc('increment_likes', { post_id: postId });
  const { data: post } = await supabase.from('posts').select('user_id').eq('id', postId).single();
  if (post && post.user_id !== req.user.id) {
    await supabase.from('notifications').insert({
      user_id: post.user_id, type: 'like', actor_id: req.user.id,
      reference_id: postId, reference_type: 'post'
    });
  }
  res.json({ liked: true });
});

// ========== COMMENTS ==========
app.get('/api/posts/:id/comments', async (req, res) => {
  const { data, error } = await supabase
    .from('comments').select('*, profiles:user_id(display_name, handle, avatar_url)')
    .eq('post_id', req.params.id).order('created_at', { ascending: true });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/posts/:id/comments', authMiddleware, async (req, res) => {
  const { content } = req.body;
  if (!content) return res.status(400).json({ error: 'Content required' });
  const { data, error } = await supabase.from('comments')
    .insert({ post_id: req.params.id, user_id: req.user.id, content }).select().single();
  if (error) return res.status(500).json({ error: error.message });
  await supabase.rpc('increment_comments', { post_id: req.params.id });
  res.json(data);
});

// ========== FOLLOWS ==========
app.post('/api/follows', authMiddleware, async (req, res) => {
  const { following_id, subscribed } = req.body;
  const { data, error } = await supabase.from('follows').insert({
    follower_id: req.user.id, following_id, subscribed: subscribed || false
  }).select().single();
  if (error) {
    if (error.code === '23505') return res.status(400).json({ error: 'Already following' });
    return res.status(500).json({ error: error.message });
  }
  await supabase.from('notifications').insert({
    user_id: following_id, type: 'follow', actor_id: req.user.id, reference_type: 'follow'
  });
  res.json(data);
});

app.delete('/api/follows/:id', authMiddleware, async (req, res) => {
  const { error } = await supabase.from('follows').delete()
    .eq('follower_id', req.user.id).eq('following_id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

app.get('/api/follows/:userId', async (req, res) => {
  const [{ data: followers }, { data: following }] = await Promise.all([
    supabase.from('follows').select('follower_id, profiles:follower_id(display_name, handle, avatar_url)')
      .eq('following_id', req.params.userId),
    supabase.from('follows').select('following_id, profiles:following_id(display_name, handle, avatar_url)')
      .eq('follower_id', req.params.userId)
  ]);
  res.json({ followers: followers || [], following: following || [] });
});

// ========== MESSAGES ==========
app.get('/api/conversations', authMiddleware, async (req, res) => {
  const { data, error } = await supabase.from('conversations')
    .select('*, p1:participant_1(display_name, handle, avatar_url), p2:participant_2(display_name, handle, avatar_url)')
    .or(\`participant_1.eq.\${req.user.id},participant_2.eq.\${req.user.id}\`)
    .order('last_message_at', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/conversations', authMiddleware, async (req, res) => {
  const { participant_id } = req.body;
  const { data: existing } = await supabase.from('conversations').select('*')
    .or(\`and(participant_1.eq.\${req.user.id},participant_2.eq.\${participant_id}),and(participant_1.eq.\${participant_id},participant_2.eq.\${req.user.id})\`)
    .single();
  if (existing) return res.json(existing);
  const { data, error } = await supabase.from('conversations')
    .insert({ participant_1: req.user.id, participant_2: participant_id }).select().single();
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.get('/api/messages/:conversationId', authMiddleware, async (req, res) => {
  const { data, error } = await supabase.from('messages')
    .select('*, profiles:sender_id(display_name, handle, avatar_url)')
    .eq('conversation_id', req.params.conversationId)
    .order('created_at', { ascending: true }).limit(100);
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/messages', authMiddleware, async (req, res) => {
  const { conversation_id, content, media_url, media_type } = req.body;
  const { data, error } = await supabase.from('messages').insert({
    conversation_id, sender_id: req.user.id,
    content: content || '', media_url: media_url || '', media_type: media_type || 'text'
  }).select().single();
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ========== NOTIFICATIONS ==========
app.get('/api/notifications', authMiddleware, async (req, res) => {
  const { data, error } = await supabase.from('notifications')
    .select('*, profiles:actor_id(display_name, handle, avatar_url)')
    .eq('user_id', req.user.id).order('created_at', { ascending: false }).limit(50);
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.patch('/api/notifications/:id/read', authMiddleware, async (req, res) => {
  const { error } = await supabase.from('notifications')
    .update({ is_read: true }).eq('id', req.params.id).eq('user_id', req.user.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ========== STORIES ==========
app.get('/api/stories', authMiddleware, async (req, res) => {
  const { data: follows } = await supabase.from('follows').select('following_id').eq('follower_id', req.user.id);
  const followingIds = (follows || []).map(f => f.following_id);
  followingIds.push(req.user.id);
  const { data, error } = await supabase.from('stories')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .in('user_id', followingIds)
    .gt('expires_at', new Date().toISOString())
    .order('created_at', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/stories', authMiddleware, async (req, res) => {
  const { media_url, media_type, caption } = req.body;
  const { data, error } = await supabase.from('stories').insert({
    user_id: req.user.id, media_url: media_url || '', media_type: media_type || 'image', caption: caption || ''
  }).select().single();
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ========== LIVE STREAMS ==========
app.post('/api/streams', authMiddleware, async (req, res) => {
  const { title, room_id } = req.body;
  const { data, error } = await supabase.from('live_streams').insert({
    user_id: req.user.id, title: title || 'Live Stream', room_id: room_id || '', is_active: true
  }).select().single();
  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.get('/api/streams/active', async (req, res) => {
  const { data, error } = await supabase.from('live_streams')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .eq('is_active', true).order('started_at', { ascending: false });
  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/streams/:id/end', authMiddleware, async (req, res) => {
  const { error } = await supabase.from('live_streams')
    .update({ is_active: false, ended_at: new Date() })
    .eq('id', req.params.id).eq('user_id', req.user.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ========== STATS ==========
app.get('/api/stats/:userId', async (req, res) => {
  const userId = req.params.userId;
  const [postsCount, followersCount, followingCount] = await Promise.all([
    supabase.from('posts').select('*', { count: 'exact' }).eq('user_id', userId),
    supabase.from('follows').select('*', { count: 'exact' }).eq('following_id', userId),
    supabase.from('follows').select('*', { count: 'exact' }).eq('follower_id', userId)
  ]);
  res.json({
    posts: postsCount.count || 0,
    followers: followersCount.count || 0,
    following: followingCount.count || 0
  });
});

// ========== HEALTH / ROOT ==========
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/', (req, res) => {
  res.json({ name: 'MyChainLink API', version: '1.0.0', status: 'running' });
});

app.listen(PORT, () => {
  console.log(\`MyChainLink API running on port \${PORT}\`);
});

module.exports = app;
ENDOFFILE

echo "Created server.js"

# Install dependencies
echo "Installing dependencies..."
npm install

echo ""
echo "=== Setup Complete ==="
echo "To start the server, run:"
echo "  cd ~/mychainlink-api"
echo "  npm start"
echo ""
echo "API will be at: http://localhost:3001"
