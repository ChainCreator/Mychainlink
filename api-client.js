/**
 * MyChainLink - Production-Ready Frontend API Client
 * Connects to Supabase backend for real user data
 */

// ==================== CONFIG ====================
const API_BASE = window.location.hostname === 'localhost' 
  ? 'http://localhost:3001/api' 
  : 'https://your-api-domain.com/api';

// ==================== AUTH API ====================
async function apiLogin(email, password) {
  const { data, error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

async function apiSignup(userData) {
  const { data, error } = await sb.auth.signUp({
    email: userData.email,
    password: userData.password,
    options: {
      data: {
        display_name: userData.name,
        handle: userData.handle
      }
    }
  });
  if (error) throw error;
  return data;
}

async function apiLogout() {
  await sb.auth.signOut();
  localStorage.clear();
}

// ==================== POSTS API ====================
async function apiGetPosts() {
  const { data, error } = await sb
    .from('posts')
    .select('*, profiles:user_id(display_name, handle, avatar_url)')
    .order('created_at', { ascending: false })
    .limit(50);
  
  if (error) throw error;
  return data;
}

async function apiCreatePost(postData) {
  const { data, error } = await sb
    .from('posts')
    .insert({
      user_id: cu.id,
      content: postData.content,
      media_url: postData.media_url || '',
      media_type: postData.media_type || 'none',
      tags: postData.tags || [],
      location: postData.location || '',
      has_comments: postData.has_comments !== false
    })
    .select()
    .single();
  
  if (error) throw error;
  return data;
}

async function apiDeletePost(postId) {
  const { error } = await sb
    .from('posts')
    .delete()
    .eq('id', postId)
    .eq('user_id', cu.id);
  
  if (error) throw error;
  return true;
}

// ==================== FOLLOWS API (Connect/Disconnect) ====================
async function apiConnect(userId) {
  const { data, error } = await sb
    .from('follows')
    .insert({
      follower_id: cu.id,
      following_id: userId
    })
    .select()
    .single();
  
  if (error) {
    if (error.code === '23505') return { alreadyConnected: true };
    throw error;
  }
  return data;
}

async function apiDisconnect(userId) {
  const { error } = await sb
    .from('follows')
    .delete()
    .eq('follower_id', cu.id)
    .eq('following_id', userId);
  
  if (error) throw error;
  return true;
}

async function apiGetFollowers(userId) {
  const { data, error } = await sb
    .from('follows')
    .select('follower_id, profiles:follower_id(display_name, handle, avatar_url)')
    .eq('following_id', userId);
  
  if (error) throw error;
  return data;
}

async function apiGetFollowing(userId) {
  const { data, error } = await sb
    .from('follows')
    .select('following_id, profiles:following_id(display_name, handle, avatar_url)')
    .eq('follower_id', userId);
  
  if (error) throw error;
  return data;
}

// ==================== MESSAGES API ====================
async function apiGetConversations() {
  const { data, error } = await sb
    .from('conversations')
    .select('*, participant1:participant_1(display_name, handle, avatar_url), participant2:participant_2(display_name, handle, avatar_url)')
    .or(`participant_1.eq.${cu.id},participant_2.eq.${cu.id}`)
    .order('last_message_at', { ascending: false });
  
  if (error) throw error;
  return data;
}

async function apiCreateConversation(participantId) {
  // Check if exists
  const { data: existing } = await sb
    .from('conversations')
    .select('*')
    .or(`and(participant_1.eq.${cu.id},participant_2.eq.${participantId}),and(participant_1.eq.${participantId},participant_2.eq.${cu.id})`)
    .single();
  
  if (existing) return existing;
  
  const { data, error } = await sb
    .from('conversations')
    .insert({
      participant_1: cu.id,
      participant_2: participantId
    })
    .select()
    .single();
  
  if (error) throw error;
  return data;
}

async function apiGetMessages(conversationId) {
  const { data, error } = await sb
    .from('messages')
    .select('*, profiles:sender_id(display_name, handle, avatar_url)')
    .eq('conversation_id', conversationId)
    .order('created_at', { ascending: true })
    .limit(100);
  
  if (error) throw error;
  return data;
}

async function apiSendMessage(conversationId, content, mediaUrl = '', mediaType = 'text') {
  const { data, error } = await sb
    .from('messages')
    .insert({
      conversation_id: conversationId,
      sender_id: cu.id,
      content,
      media_url: mediaUrl,
      media_type: mediaType
    })
    .select()
    .single();
  
  if (error) throw error;
  return data;
}

// ==================== REALTIME SUBSCRIPTIONS ====================
function subscribeToMessages(conversationId, callback) {
  return sb
    .channel(`messages:${conversationId}`)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'messages',
      filter: `conversation_id=eq.${conversationId}`
    }, (payload) => {
      callback(payload.new);
    })
    .subscribe();
}

function subscribeToNotifications(callback) {
  return sb
    .channel(`notifications:${cu.id}`)
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'notifications',
      filter: `user_id=eq.${cu.id}`
    }, (payload) => {
      callback(payload.new);
    })
    .subscribe();
}

function subscribeToNewPosts(callback) {
  return sb
    .channel('new_posts')
    .on('postgres_changes', {
      event: 'INSERT',
      schema: 'public',
      table: 'posts'
    }, (payload) => {
      callback(payload.new);
    })
    .subscribe();
}

// ==================== STORAGE (Media Upload) ====================
async function uploadMedia(file, bucket = 'media') {
  const fileExt = file.name.split('.').pop();
  const fileName = `${Date.now()}_${Math.random().toString(36).substr(2, 9)}.${fileExt}`;
  const filePath = `${cu.id}/${fileName}`;
  
  const { data, error } = await sb.storage
    .from(bucket)
    .upload(filePath, file, {
      cacheControl: '3600',
      upsert: false
    });
  
  if (error) throw error;
  
  // Get public URL
  const { data: { publicUrl } } = sb.storage
    .from(bucket)
    .getPublicUrl(filePath);
  
  return publicUrl;
}

// ==================== COMMON PITFALLS ====================

/**
 * 1. RLS ERRORS: If you get "new row violates row-level security policy",
 *    check that the user is authenticated and the RLS policy allows the operation.
 *    Common fix: Ensure `auth.uid()` matches the `user_id` field in the table.
 * 
 * 2. REALTIME SUBSCRIPTIONS: If you don't receive real-time updates,
 *    check that the table has replication enabled in Supabase Dashboard:
 *    Database -> Replication -> tables -> enable for your table.
 * 
 * 3. STORAGE PERMISSIONS: If uploads fail, check Storage bucket permissions.
 *    Public buckets need `authenticated` insert policy.
 * 
 * 4. CORS: If API calls fail from browser, enable CORS in your backend
 *    or use Supabase client directly (which handles CORS).
 */

// ==================== EXPORT ====================
window.api = {
  login: apiLogin,
  signup: apiSignup,
  logout: apiLogout,
  getPosts: apiGetPosts,
  createPost: apiCreatePost,
  deletePost: apiDeletePost,
  connect: apiConnect,
  disconnect: apiDisconnect,
  getFollowers: apiGetFollowers,
  getFollowing: apiGetFollowing,
  getConversations: apiGetConversations,
  createConversation: apiCreateConversation,
  getMessages: apiGetMessages,
  sendMessage: apiSendMessage,
  subscribeToMessages,
  subscribeToNotifications,
  subscribeToNewPosts,
  uploadMedia
};
