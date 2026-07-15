const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3001;

// Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
);

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Auth middleware
const authMiddleware = async (req, res, next) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) return res.status(401).json({ error: 'No token' });

  const { data: { user }, error } = await supabase.auth.getUser(token);
  if (error || !user) return res.status(401).json({ error: 'Invalid token' });

  req.user = user;
  next();
};

// ============================================================
// STATIC FILES (frontend)
// ============================================================
app.use(express.static(path.join(__dirname)));

// ============================================================
// API ROUTES
// ============================================================
app.get('/api/profiles/:handle', async (req, res) => {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('handle', req.params.handle)
    .single();

  if (error) return res.status(404).json({ error: 'Profile not found' });
  res.json(data);
});

app.get('/api/search', async (req, res) => {
  const q = req.query.q;
  if (!q) return res.json([]);

  const { data, error } = await supabase
    .from('profiles')
    .select('id, display_name, handle, avatar_url, bio, is_creator')
    .or(`display_name.ilike.%${q}%,handle.ilike.%${q}%`)
    .limit(20);

  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.put('/api/profiles/:id', authMiddleware, async (req, res) => {
  if (req.params.id !== req.user.id) return res.status(403).json({ error: 'Not allowed' });

  const { display_name, bio, avatar_url, location, paypal_email, birth_date, gender, website, interests } = req.body;
  const updateData = { updated_at: new Date() };
  if (display_name !== undefined) updateData.display_name = display_name;
  if (bio !== undefined) updateData.bio = bio;
  if (avatar_url !== undefined) updateData.avatar_url = avatar_url;
  if (location !== undefined) updateData.location = location;
  if (paypal_email !== undefined) updateData.paypal_email = paypal_email;
  if (birth_date !== undefined) updateData.birth_date = birth_date;
  if (gender !== undefined) updateData.gender = gender;
  if (website !== undefined) updateData.website = website;
  if (interests !== undefined) updateData.interests = interests;

  const { data, error } = await supabase
    .from('profiles')
    .update(updateData)
    .eq('id', req.params.id)
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.delete('/api/users/:id', authMiddleware, async (req, res) => {
  if (req.params.id !== req.user.id) return res.status(403).json({ error: 'Not allowed' });

  const { error } = await supabase.auth.admin.deleteUser(req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ============================================================
// POSTS
// ============================================================
app.get('/api/posts', async (req, res) => {
  const { data, error } = await supabase
    .from('posts')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.get('/api/feed', authMiddleware, async (req, res) => {
  // Get posts from people the user follows
  const { data: follows } = await supabase
    .from('follows')
    .select('following_id')
    .eq('follower_id', req.user.id);

  const followingIds = (follows || []).map(f => f.following_id);
  followingIds.push(req.user.id); // Include own posts

  const { data, error } = await supabase
    .from('posts')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .in('user_id', followingIds)
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.get('/api/posts/:id', async (req, res) => {
  const { data, error } = await supabase
    .from('posts')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .eq('id', req.params.id)
    .single();

  if (error) return res.status(404).json({ error: 'Post not found' });
  res.json(data);
});

app.post('/api/posts', authMiddleware, async (req, res) => {
  const { content, media_url, media_type, tags, location, font, is_premium_only, price } = req.body;

  const { data, error } = await supabase
    .from('posts')
    .insert({
      user_id: req.user.id,
      content: content || '',
      media_url: media_url || '',
      media_type: media_type || 'none',
      tags: tags || [],
      location: location || '',
      font: font || 'default',
      is_premium_only: is_premium_only || false,
      price: price || 0
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.delete('/api/posts/:id', authMiddleware, async (req, res) => {
  const { error } = await supabase
    .from('posts')
    .delete()
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ============================================================
// LIKES
// ============================================================
app.post('/api/posts/:id/like', authMiddleware, async (req, res) => {
  const postId = req.params.id;

  const { data: existing } = await supabase
    .from('likes')
    .select('*')
    .eq('post_id', postId)
    .eq('user_id', req.user.id)
    .single();

  if (existing) {
    // Unlike
    await supabase.from('likes').delete().eq('post_id', postId).eq('user_id', req.user.id);
    await supabase.rpc('decrement_likes', { post_id: postId });
    return res.json({ liked: false });
  }

  // Like
  const { error } = await supabase
    .from('likes')
    .insert({ post_id: postId, user_id: req.user.id });

  if (error) return res.status(500).json({ error: error.message });

  await supabase.rpc('increment_likes', { post_id: postId });

  // Create notification
  const { data: post } = await supabase.from('posts').select('user_id').eq('id', postId).single();
  if (post && post.user_id !== req.user.id) {
    await supabase.from('notifications').insert({
      user_id: post.user_id,
      type: 'like',
      actor_id: req.user.id,
      reference_id: postId,
      reference_type: 'post'
    });
  }

  res.json({ liked: true });
});

app.get('/api/posts/:id/likes', async (req, res) => {
  const { data, error } = await supabase
    .from('likes')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .eq('post_id', req.params.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

// ============================================================
// COMMENTS
// ============================================================
app.get('/api/posts/:id/comments', async (req, res) => {
  const { data, error } = await supabase
    .from('comments')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .eq('post_id', req.params.id)
    .order('created_at', { ascending: true });

  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/posts/:id/comments', authMiddleware, async (req, res) => {
  const { content } = req.body;
  if (!content) return res.status(400).json({ error: 'Content required' });

  const { data, error } = await supabase
    .from('comments')
    .insert({ post_id: req.params.id, user_id: req.user.id, content })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });

  // Update comments count
  await supabase.rpc('increment_comments', { post_id: req.params.id });

  // Notify post owner
  const { data: post } = await supabase.from('posts').select('user_id').eq('id', req.params.id).single();
  if (post && post.user_id !== req.user.id) {
    await supabase.from('notifications').insert({
      user_id: post.user_id,
      type: 'comment',
      actor_id: req.user.id,
      reference_id: req.params.id,
      reference_type: 'post'
    });
  }

  res.json(data);
});

app.delete('/api/comments/:id', authMiddleware, async (req, res) => {
  const { data: comment } = await supabase.from('comments').select('post_id').eq('id', req.params.id).single();
  const { error } = await supabase
    .from('comments')
    .delete()
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) return res.status(500).json({ error: error.message });
  if (comment) await supabase.rpc('decrement_comments', { post_id: comment.post_id });
  res.json({ success: true });
});

// ============================================================
// FOLLOWS (CONNECT/DISCONNECT)
// ============================================================
app.post('/api/follows', authMiddleware, async (req, res) => {
  const { following_id, subscribed } = req.body;

  const { data, error } = await supabase
    .from('follows')
    .insert({
      follower_id: req.user.id,
      following_id,
      subscribed: subscribed || false
    })
    .select()
    .single();

  if (error) {
    if (error.code === '23505') return res.status(400).json({ error: 'Already following' });
    return res.status(500).json({ error: error.message });
  }

  // Notify the person being followed
  await supabase.from('notifications').insert({
    user_id: following_id,
    type: 'follow',
    actor_id: req.user.id,
    reference_type: 'follow'
  });

  res.json(data);
});

app.delete('/api/follows/:id', authMiddleware, async (req, res) => {
  const { error } = await supabase
    .from('follows')
    .delete()
    .eq('follower_id', req.user.id)
    .eq('following_id', req.params.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

app.get('/api/follows/:userId', async (req, res) => {
  const { data: followers, error: f1 } = await supabase
    .from('follows')
    .select('follower_id, profiles:follower_id(display_name, handle, avatar_url)')
    .eq('following_id', req.params.userId);

  const { data: following, error: f2 } = await supabase
    .from('follows')
    .select('following_id, profiles:following_id(display_name, handle, avatar_url)')
    .eq('follower_id', req.params.userId);

  if (f1 || f2) return res.status(500).json({ error: (f1 || f2).message });
  res.json({ followers: followers || [], following: following || [] });
});

// ============================================================
// MESSAGES / CONVERSATIONS
// ============================================================
app.get('/api/conversations', authMiddleware, async (req, res) => {
  const { data, error } = await supabase
    .from('conversations')
    .select('*, profiles1:participant_1(display_name, handle, avatar_url), profiles2:participant_2(display_name, handle, avatar_url)')
    .or(`participant_1.eq.${req.user.id},participant_2.eq.${req.user.id}`)
    .order('last_message_at', { ascending: false });

  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/conversations', authMiddleware, async (req, res) => {
  const { participant_id } = req.body;

  const { data: existing } = await supabase
    .from('conversations')
    .select('*')
    .or(`and(participant_1.eq.${req.user.id},participant_2.eq.${participant_id}),and(participant_1.eq.${participant_id},participant_2.eq.${req.user.id})`)
    .single();

  if (existing) return res.json(existing);

  const { data, error } = await supabase
    .from('conversations')
    .insert({ participant_1: req.user.id, participant_2: participant_id })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.get('/api/messages/:conversationId', authMiddleware, async (req, res) => {
  const { data, error } = await supabase
    .from('messages')
    .select('*, profiles:sender_id(display_name, handle, avatar_url)')
    .eq('conversation_id', req.params.conversationId)
    .order('created_at', { ascending: true })
    .limit(100);

  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/messages', authMiddleware, async (req, res) => {
  const { conversation_id, content, media_url, media_type } = req.body;

  const { data, error } = await supabase
    .from('messages')
    .insert({
      conversation_id,
      sender_id: req.user.id,
      content: content || '',
      media_url: media_url || '',
      media_type: media_type || 'text'
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });

  // Notify recipient
  const { data: convo } = await supabase.from('conversations').select('participant_1, participant_2').eq('id', conversation_id).single();
  if (convo) {
    const recipientId = convo.participant_1 === req.user.id ? convo.participant_2 : convo.participant_1;
    await supabase.from('notifications').insert({
      user_id: recipientId,
      type: 'message',
      actor_id: req.user.id,
      reference_id: conversation_id,
      reference_type: 'conversation'
    });
  }

  res.json(data);
});

// ============================================================
// NOTIFICATIONS
// ============================================================
app.get('/api/notifications', authMiddleware, async (req, res) => {
  const { data, error } = await supabase
    .from('notifications')
    .select('*, profiles:actor_id(display_name, handle, avatar_url)')
    .eq('user_id', req.user.id)
    .order('created_at', { ascending: false })
    .limit(50);

  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.patch('/api/notifications/:id/read', authMiddleware, async (req, res) => {
  const { error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

app.patch('/api/notifications/read-all', authMiddleware, async (req, res) => {
  const { error } = await supabase
    .from('notifications')
    .update({ is_read: true })
    .eq('user_id', req.user.id)
    .eq('is_read', false);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ============================================================
// STORIES (24h Ephemeral)
// ============================================================
app.get('/api/stories', authMiddleware, async (req, res) => {
  const { data: follows } = await supabase
    .from('follows')
    .select('following_id')
    .eq('follower_id', req.user.id);

  const followingIds = (follows || []).map(f => f.following_id);
  followingIds.push(req.user.id);

  const { data, error } = await supabase
    .from('stories')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .in('user_id', followingIds)
    .gt('expires_at', new Date().toISOString())
    .order('created_at', { ascending: false });

  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/stories', authMiddleware, async (req, res) => {
  const { media_url, media_type, caption } = req.body;

  const { data, error } = await supabase
    .from('stories')
    .insert({
      user_id: req.user.id,
      media_url: media_url || '',
      media_type: media_type || 'image',
      caption: caption || ''
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.post('/api/stories/:id/view', authMiddleware, async (req, res) => {
  const { data: story } = await supabase.from('stories').select('viewed_by').eq('id', req.params.id).single();
  if (!story) return res.status(404).json({ error: 'Story not found' });

  const viewedBy = story.viewed_by || [];
  if (!viewedBy.includes(req.user.id)) {
    viewedBy.push(req.user.id);
    await supabase.from('stories').update({ viewed_by: viewedBy }).eq('id', req.params.id);
  }

  res.json({ success: true });
});

// ============================================================
// SUBSCRIPTIONS (Premium)
// ============================================================
app.get('/api/subscriptions/:creatorId', authMiddleware, async (req, res) => {
  const { data, error } = await supabase
    .from('subscriptions')
    .select('*')
    .eq('subscriber_id', req.user.id)
    .eq('creator_id', req.params.creatorId)
    .single();

  if (error && error.code !== 'PGRST116') return res.status(500).json({ error: error.message });
  res.json(data || { subscribed: false });
});

app.post('/api/subscriptions', authMiddleware, async (req, res) => {
  const { creator_id, amount, payment_method } = req.body;

  const { data, error } = await supabase
    .from('subscriptions')
    .insert({
      subscriber_id: req.user.id,
      creator_id,
      amount: amount || 0,
      payment_method: payment_method || 'paypal',
      status: 'active'
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });

  // Update follow to subscribed
  await supabase.from('follows')
    .update({ subscribed: true })
    .eq('follower_id', req.user.id)
    .eq('following_id', creator_id);

  res.json(data);
});

app.delete('/api/subscriptions/:creatorId', authMiddleware, async (req, res) => {
  const { error } = await supabase
    .from('subscriptions')
    .delete()
    .eq('subscriber_id', req.user.id)
    .eq('creator_id', req.params.creatorId);

  if (error) return res.status(500).json({ error: error.message });

  await supabase.from('follows')
    .update({ subscribed: false })
    .eq('follower_id', req.user.id)
    .eq('following_id', req.params.creatorId);

  res.json({ success: true });
});

// ============================================================
// BLOCKS
// ============================================================
app.get('/api/blocks', authMiddleware, async (req, res) => {
  const { data, error } = await supabase
    .from('blocks')
    .select('*, profiles:blocked_id(display_name, handle, avatar_url)')
    .eq('blocker_id', req.user.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/blocks', authMiddleware, async (req, res) => {
  const { blocked_id } = req.body;

  const { data, error } = await supabase
    .from('blocks')
    .insert({ blocker_id: req.user.id, blocked_id })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.delete('/api/blocks/:id', authMiddleware, async (req, res) => {
  const { error } = await supabase
    .from('blocks')
    .delete()
    .eq('blocker_id', req.user.id)
    .eq('blocked_id', req.params.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ============================================================
// REPORTS
// ============================================================
app.post('/api/reports', authMiddleware, async (req, res) => {
  const { reported_id, report_type, reason } = req.body;

  const { data, error } = await supabase
    .from('reports')
    .insert({
      reporter_id: req.user.id,
      reported_id,
      report_type: report_type || 'user',
      reason: reason || ''
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ============================================================
// MEDIA UPLOADS
// ============================================================
app.post('/api/upload', authMiddleware, async (req, res) => {
  const { file_path, file_type, file_size, url } = req.body;

  const { data, error } = await supabase
    .from('media_uploads')
    .insert({
      user_id: req.user.id,
      file_path: file_path || '',
      file_type: file_type || 'image',
      file_size: file_size || 0,
      url: url || ''
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

// ============================================================
// LIVE STREAMS
// ============================================================
app.post('/api/streams', authMiddleware, async (req, res) => {
  const { title, room_id } = req.body;

  const { data, error } = await supabase
    .from('live_streams')
    .insert({
      user_id: req.user.id,
      title: title || 'Live Stream',
      room_id: room_id || '',
      is_active: true
    })
    .select()
    .single();

  if (error) return res.status(500).json({ error: error.message });
  res.json(data);
});

app.get('/api/streams/active', async (req, res) => {
  const { data, error } = await supabase
    .from('live_streams')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .eq('is_active', true)
    .order('started_at', { ascending: false });

  if (error) return res.status(500).json({ error: error.message });
  res.json(data || []);
});

app.post('/api/streams/:id/end', authMiddleware, async (req, res) => {
  const { error } = await supabase
    .from('live_streams')
    .update({ is_active: false, ended_at: new Date() })
    .eq('id', req.params.id)
    .eq('user_id', req.user.id);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ success: true });
});

// ============================================================
// STATS
// ============================================================
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

// ============================================================
// HEALTH CHECK
// ============================================================
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// ============================================================
// ROOT
// ============================================================
app.get('/', (req, res) => {
  res.json({
    name: 'MyChainLink API',
    version: '1.0.0',
    status: 'running',
    endpoints: [
      '/api/health',
      '/api/posts',
      '/api/feed',
      '/api/search',
      '/api/profiles/:handle',
      '/api/follows',
      '/api/conversations',
      '/api/messages',
      '/api/notifications',
      '/api/stories',
      '/api/streams',
      '/api/stats/:userId'
    ]
  });
});

// Serve index.html for any non-API route (SPA fallback)
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`MyChainLink running on port ${PORT}`);
});

module.exports = app;
