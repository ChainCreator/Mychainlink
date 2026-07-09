const express=require('express'),cors=require('cors'),{createClient}=require('@supabase/supabase-js');require('dotenv').config();
const app=express(),PORT=process.env.PORT||3001;
const sb=createClient(process.env.SUPABASE_URL,process.env.SUPABASE_SERVICE_KEY);
app.use(cors());app.use(express.json({limit:'10mb'}));
const auth=async(req,res,next)=>{const t=req.headers.authorization?.replace('Bearer ','');if(!t)return res.status(401).json({error:'No token'});const{data:{user},error}=await sb.auth.getUser(t);if(error||!user)return res.status(401).json({error:'Invalid token'});req.user=user;next();};

// PROFILES
app.get('/api/profiles/:handle',async(req,res)=>{const{data,e}=await sb.from('profiles').select('*').eq('handle',req.params.handle).single();if(e)return res.status(404).json({error:'Not found'});res.json(data);});
app.get('/api/search',async(req,res)=>{const q=req.query.q;if(!q)return res.json([]);const{data,e}=await sb.from('profiles').select('id,display_name,handle,avatar_url,bio,is_creator').or(`display_name.ilike.%${q}%,handle.ilike.%${q}%`).limit(20);res.json(data||[]);});
app.put('/api/profiles/:id',auth,async(req,res)=>{if(req.params.id!==req.user.id)return res.status(403).json({error:'Nope'});const{data,e}=await sb.from('profiles').update({...req.body,updated_at:new Date()}).eq('id',req.params.id).select().single();if(e)return res.status(500).json({error:e.message});res.json(data);});

// POSTS
app.get('/api/posts',async(req,res)=>{const{data,e}=await sb.from('posts').select('*,profiles:user_id(display_name,handle,avatar_url)').order('created_at',{ascending:false}).limit(50);res.json(data||[]);});
app.get('/api/feed',auth,async(req,res)=>{const{data:f}=await sb.from('follows').select('following_id').eq('follower_id',req.user.id);const ids=(f||[]).map(x=>x.following_id);ids.push(req.user.id);const{data,e}=await sb.from('posts').select('*,profiles:user_id(display_name,handle,avatar_url)').in('user_id',ids).order('created_at',{ascending:false}).limit(50);res.json(data||[]);});
app.post('/api/posts',auth,async(req,res)=>{const{data,e}=await sb.from('posts').insert({user_id:req.user.id,...req.body}).select().single();if(e)return res.status(500).json({error:e.message});res.json(data);});
app.delete('/api/posts/:id',auth,async(req,res)=>{await sb.from('posts').delete().eq('id',req.params.id).eq('user_id',req.user.id);res.json({ok:true});});

// LIKES
app.post('/api/posts/:id/like',auth,async(req,res)=>{const pid=req.params.id;const{data:ex}=await sb.from('likes').select('*').eq('post_id',pid).eq('user_id',req.user.id).single();if(ex){await sb.from('likes').delete().eq('post_id',pid).eq('user_id',req.user.id);return res.json({liked:false});}await sb.from('likes').insert({post_id:pid,user_id:req.user.id});res.json({liked:true});});

// COMMENTS
app.get('/api/posts/:id/comments',async(req,res)=>{const{data,e}=await sb.from('comments').select('*,profiles:user_id(display_name,handle,avatar_url)').eq('post_id',req.params.id).order('created_at',{ascending:true});res.json(data||[]);});
app.post('/api/posts/:id/comments',auth,async(req,res)=>{const{data,e}=await sb.from('comments').insert({post_id:req.params.id,user_id:req.user.id,content:req.body.content}).select().single();res.json(data);});

// FOLLOWS
app.post('/api/follows',auth,async(req,res)=>{const{data,e}=await sb.from('follows').insert({follower_id:req.user.id,...req.body}).select().single();if(e&&e.code==='23505')return res.status(400).json({error:'Already following'});res.json(data);});
app.delete('/api/follows/:id',auth,async(req,res)=>{await sb.from('follows').delete().eq('follower_id',req.user.id).eq('following_id',req.params.id);res.json({ok:true});});
app.get('/api/follows/:userId',async(req,res)=>{const[{data:followers},{data:following}]=await Promise.all([sb.from('follows').select('*,profiles:follower_id(display_name,handle,avatar_url)').eq('following_id',req.params.userId),sb.from('follows').select('*,profiles:following_id(display_name,handle,avatar_url)').eq('follower_id',req.params.userId)]);res.json({followers:followers||[],following:following||[]});});

// CONVERSATIONS & MESSAGES
app.get('/api/conversations',auth,async(req,res)=>{const{data,e}=await sb.from('conversations').select('*,p1:participant_1(display_name,handle,avatar_url),p2:participant_2(display_name,handle,avatar_url)').or(`participant_1.eq.${req.user.id},participant_2.eq.${req.user.id}`).order('last_message_at',{ascending:false});res.json(data||[]);});
app.post('/api/conversations',auth,async(req,res)=>{const{data:ex}=await sb.from('conversations').select('*').or(`and(participant_1.eq.${req.user.id},participant_2.eq.${req.body.participant_id}),and(participant_1.eq.${req.body.participant_id},participant_2.eq.${req.user.id})`).single();if(ex)return res.json(ex);const{data,e}=await sb.from('conversations').insert({participant_1:req.user.id,participant_2:req.body.participant_id}).select().single();res.json(data);});
app.get('/api/messages/:cid',auth,async(req,res)=>{const{data,e}=await sb.from('messages').select('*,profiles:sender_id(display_name,handle,avatar_url)').eq('conversation_id',req.params.cid).order('created_at',{ascending:true}).limit(100);res.json(data||[]);});
app.post('/api/messages',auth,async(req,res)=>{const{data,e}=await sb.from('messages').insert({sender_id:req.user.id,...req.body}).select().single();res.json(data);});

// NOTIFICATIONS
app.get('/api/notifications',auth,async(req,res)=>{const{data,e}=await sb.from('notifications').select('*,profiles:actor_id(display_name,handle,avatar_url)').eq('user_id',req.user.id).order('created_at',{ascending:false}).limit(50);res.json(data||[]);});
app.patch('/api/notifications/:id/read',auth,async(req,res)=>{await sb.from('notifications').update({is_read:true}).eq('id',req.params.id).eq('user_id',req.user.id);res.json({ok:true});});

// STORIES
app.get('/api/stories',auth,async(req,res)=>{const{data:f}=await sb.from('follows').select('following_id').eq('follower_id',req.user.id);const ids=(f||[]).map(x=>x.following_id);ids.push(req.user.id);const{data,e}=await sb.from('stories').select('*,profiles:user_id(display_name,handle,avatar_url)').in('user_id',ids).gt('expires_at',new Date().toISOString()).order('created_at',{ascending:false});res.json(data||[]);});
app.post('/api/stories',auth,async(req,res)=>{const{data,e}=await sb.from('stories').insert({user_id:req.user.id,...req.body}).select().single();res.json(data);});

// STREAMS
app.get('/api/streams/active',async(req,res)=>{const{data,e}=await sb.from('live_streams').select('*,profiles:user_id(display_name,handle,avatar_url)').eq('is_active',true).order('started_at',{ascending:false});res.json(data||[]);});
app.post('/api/streams',auth,async(req,res)=>{const{data,e}=await sb.from('live_streams').insert({user_id:req.user.id,is_active:true,...req.body}).select().single();res.json(data);});
app.post('/api/streams/:id/end',auth,async(req,res)=>{await sb.from('live_streams').update({is_active:false,ended_at:new Date()}).eq('id',req.params.id).eq('user_id',req.user.id);res.json({ok:true});});

// STATS
app.get('/api/stats/:uid',async(req,res)=>{const[pc,fc,fg]=await Promise.all([sb.from('posts').select('*',{count:'exact'}).eq('user_id',req.params.uid),sb.from('follows').select('*',{count:'exact'}).eq('following_id',req.params.uid),sb.from('follows').select('*',{count:'exact'}).eq('follower_id',req.params.uid)]);res.json({posts:pc.count||0,followers:fc.count||0,following:fg.count||0});});

// REPORTS & BLOCKS
app.post('/api/reports',auth,async(req,res)=>{const{data,e}=await sb.from('reports').insert({reporter_id:req.user.id,...req.body}).select().single();res.json(data);});
app.get('/api/blocks',auth,async(req,res)=>{const{data,e}=await sb.from('blocks').select('*,profiles:blocked_id(display_name,handle,avatar_url)').eq('blocker_id',req.user.id);res.json(data||[]);});
app.post('/api/blocks',auth,async(req,res)=>{const{data,e}=await sb.from('blocks').insert({blocker_id:req.user.id,...req.body}).select().single();res.json(data);});

// HEALTH
app.get('/api/health',(req,res)=>res.json({ok:true,time:new Date().toISOString()}));
app.get('/',(req,res)=>res.json({name:'MyChainLink API',v:'1.0.0',status:'running'}));

app.listen(PORT,()=>console.log(`API on port ${PORT}`));
module.exports=app;
