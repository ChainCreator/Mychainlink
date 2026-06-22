// ==================== SUPABASE ====================
var SURL='https://vjaevzohcnejkaduvtno.supabase.co';
var SKEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZqYWV2em9oY25lamthZHV2dG5vIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkzMTQ2NDAsImV4cCI6MjA2NDg5MDY0MH0._Rd7YqO77e2S0V7p3wFf_eVDFy2_T9wYykU1fQh9fSM';
var sb=null;
var supabaseOnline=false;
try{sb=supabase.createClient(SURL,SKEY);supabaseOnline=true}catch(e){console.log('Supabase offline, using local auth')}

// ==================== LOCAL AUTH FALLBACK ====================
var localUsers=JSON.parse(localStorage.getItem('cl_localUsers')||'[]');
function saveLocalUser(user){localUsers.push(user);localStorage.setItem('cl_localUsers',JSON.stringify(localUsers));var allUsersStore=JSON.parse(localStorage.getItem('cl_allUsers')||'[]');if(!allUsersStore.find(function(u){return u.id===user.id})){allUsersStore.push({id:user.id,name:user.name||user.user_metadata&&user.user_metadata.display_name||'User',handle:user.handle||user.user_metadata&&user.user_metadata.handle||'@user',avatar:user.avatar||user.user_metadata&&user.user_metadata.avatar||''});localStorage.setItem('cl_allUsers',JSON.stringify(allUsersStore))}}
function findLocalUser(email,password){return localUsers.find(function(u){return u.email===email&&u.password===password})}
function getLocalUserById(id){return localUsers.find(function(u){return u.id===id})}
function syncLocalUserToCu(lu){return{id:lu.id,email:lu.email,user_metadata:{display_name:lu.name,handle:lu.handle,bio:lu.bio||'',avatar:lu.avatar||''}}}

// ==================== FOLLOWS (SUPABASE) ====================
var sbFollows={};
var sbFollowers={};
async function loadFollowsFromSupabase(){if(!sb||!supabaseOnline||!cu)return;try{var r=await sb.from('follows').select('*').eq('follower_id',cu.id);if(r.error)throw r.error;(r.data||[]).forEach(function(f){sbFollows[f.following_id]={following:true,subscribed:f.subscribed||false}})}catch(e){console.log('Follows load error',e)}}
async function loadFollowersFromSupabase(){if(!sb||!supabaseOnline||!cu)return;try{var r=await sb.from('follows').select('*').eq('following_id',cu.id);if(r.error)throw r.error;var ids=[];(r.data||[]).forEach(function(f){ids.push(f.follower_id)});sbFollowers[cu.id]=ids}catch(e){console.log('Followers load error',e)}}
async function saveFollowSupabase(id,state){if(!sb||!supabaseOnline||!cu)return false;if(state){var r=await sb.from('follows').insert({follower_id:cu.id,following_id:id}).select();if(r.error&&r.error.code!=='23505'){console.log('Follow insert error',r.error);return false}}else{var r2=await sb.from('follows').delete().eq('follower_id',cu.id).eq('following_id',id);if(r2.error){console.log('Follow delete error',r2.error);return false}}return true}
async function loadAllFollows(){if(sb&&supabaseOnline&&cu){await loadFollowsFromSupabase();await loadFollowersFromSupabase();Object.keys(sbFollows).forEach(function(k){follows[k]=sbFollows[k]});var sbFl=sbFollowers[cu.id]||[];var localFl=JSON.parse(localStorage.getItem('cl_followers')||'{}');localFl[cu.id]=sbFl;localStorage.setItem('cl_followers',JSON.stringify(localFl))}else{var stored=JSON.parse(localStorage.getItem('cl_follows')||'{}');Object.keys(stored).forEach(function(k){follows[k]=stored[k]})}}

// ==================== STATE ====================
var cu=null;
var cp='feed';
var posts=JSON.parse(localStorage.getItem('cl_posts')||'[]');
var notifs=JSON.parse(localStorage.getItem('cl_notifs')||'[]');
var settings=JSON.parse(localStorage.getItem('cl_settings')||'{"comments":true,"subOnly":false,"notifs":true,"dark":true}');
var follows=JSON.parse(localStorage.getItem('cl_follows')||'{}');
var blocks=JSON.parse(localStorage.getItem('cl_blocks')||'[]');
var conversations=JSON.parse(localStorage.getItem('cl_conv')||'{}');
var paypalConnected=localStorage.getItem('cl_paypal')||null;
var vu=null;
var camStream=null;
var camFacing='environment';
var camData='';
var activeThread=null;

// ==================== QUOTES ====================
var quotes=[
  {t:"The best way to predict the future is to create it.",a:"Peter Drucker"},
  {t:"Be yourself; everyone else is already taken.",a:"Oscar Wilde"},
  {t:"In the middle of difficulty lies opportunity.",a:"Albert Einstein"},
  {t:"The only way to do great work is to love what you do.",a:"Steve Jobs"},
  {t:"It always seems impossible until it is done.",a:"Nelson Mandela"},
  {t:"Do not go where the path may lead, go instead where there is no path and leave a trail.",a:"Ralph Waldo Emerson"},
  {t:"The journey of a thousand miles begins with one step.",a:"Lao Tzu"},
  {t:"What lies behind us and what lies before us are tiny matters compared to what lies within us.",a:"Ralph Waldo Emerson"},
  {t:"Believe you can and you are halfway there.",a:"Theodore Roosevelt"},
  {t:"Success is not final, failure is not fatal: it is the courage to continue that counts.",a:"Winston Churchill"},
  {t:"Your time is limited, so do not waste it living someone else is life.",a:"Steve Jobs"},
  {t:"Happiness is not something ready made. It comes from your own actions.",a:"Dalai Lama"}
];
var qi=0;
function rotateQuotes(){qi=(qi+1)%quotes.length;$('quote-text').textContent='"'+quotes[qi].t+'"';$('quote-auth').textContent=quotes[qi].a}
setInterval(rotateQuotes,10000);

// ==================== UTILS ====================
function $(id){return document.getElementById(id)}function toggleShowPw(){var inp=$('su-p');inp.type=inp.type==='password'?'text':'password'}function checkPwStrength(){var p=$('su-p').value;var r=$('pw-rules');if(!r)return;var ok8=p.length>=8;var okU=/[A-Z]/.test(p);var okL=/[a-z]/.test(p);var okN=/[0-9]/.test(p);r.innerHTML=(ok8?'✅':'❌')+' 8+ chars · '+(okU?'✅':'❌')+' uppercase · '+(okL?'✅':'❌')+' lowercase · '+(okN?'✅':'❌')+' number';r.style.color=(ok8&&okU&&okL&&okN)?'#1DB954':'#888'}
function showToast(msg){var t=$('toast');if(!t){t=document.createElement('div');t.className='toast';t.id='toast';document.body.appendChild(t)}t.textContent=msg;t.classList.add('show');setTimeout(function(){t.classList.remove('show')},2500)}
function esc(s){var d=document.createElement('div');d.textContent=s;return d.innerHTML}
function ago(ts){var s=Math.floor((Date.now()-ts)/1000);if(s<60)return'just now';var m=Math.floor(s/60);if(m<60)return m+'m ago';var h=Math.floor(m/60);if(h<24)return h+'h ago';var d=Math.floor(h/24);if(d<7)return d+'d ago';var date=new Date(ts);return date.toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'})}
function uid(){return Date.now().toString(36)+Math.random().toString(36).substr(2)}
function rn(arr){return arr[Math.floor(Math.random()*arr.length)]}
function s(){localStorage.setItem('cl_posts',JSON.stringify(posts))}
function svu(){if(cu)localStorage.setItem('cl_user',JSON.stringify(cu))}
function svp(){localStorage.setItem('cl_posts',JSON.stringify(posts))}
function svn(){localStorage.setItem('cl_notifs',JSON.stringify(notifs))}
function svs(){localStorage.setItem('cl_settings',JSON.stringify(settings))}
function svf(){localStorage.setItem('cl_follows',JSON.stringify(follows))}
function svb(){localStorage.setItem('cl_blocks',JSON.stringify(blocks))}
function svc(){localStorage.setItem('cl_conv',JSON.stringify(conversations))}

// ==================== AUTH ====================
window.swt=function(t){['in','up','fg'].forEach(function(x){var f=$('form-'+x);if(f)f.classList.remove('a');var tab=$('tab-'+x);if(tab)tab.classList.remove('a')});$('form-'+t).classList.add('a');$('tab-'+t).classList.add('a');['li-er','su-er','fg-er'].forEach(function(x){var el=$(x);if(el)el.classList.remove('show')})};
window.showForgot=function(){$('form-in').classList.remove('a');$('form-up').classList.remove('a');$('tab-in').classList.remove('a');$('tab-up').classList.remove('a');$('form-fg').classList.add('a')};
window.showLogin=function(){$('form-fg').classList.remove('a');$('form-up').classList.remove('a');$('tab-up').classList.remove('a');$('form-in').classList.add('a');$('tab-in').classList.add('a')};
window.showTerms=function(){$('m-terms').classList.add('on')};
window.showHarassment=function(){$('m-harass').classList.add('on')};
window.closeModal=function(id){$(id).classList.remove('on');if(id==='m-pp-checkout'&&ppHostedButton){try{ppHostedButton.close()}catch(e){}var btnContainer=$('paypal-container-8L8HY2ULYKSFL');if(btnContainer)btnContainer.innerHTML=''}};window.pendingLoginUser=null;window.showTwoFactorModal=function(){$('fa-code').value='';$('fa-er').classList.remove('show');$('m-2fa').classList.add('on')};window.verify2FA=function(){var code=$('fa-code').value.trim();if(!code){$('fa-er').textContent='Enter your PIN';$('fa-er').classList.add('show');return}if(!window.pendingLoginUser){closeModal('m-2fa');return}if(window.pendingLoginUser.twoFactorPIN!==code){$('fa-er').textContent='Invalid PIN';$('fa-er').classList.add('show');return}$('fa-er').classList.remove('show');cu=syncLocalUserToCu(window.pendingLoginUser);svu();window.pendingLoginUser=null;closeModal('m-2fa');showApp();showToast('Signed in (2FA verified)');};

window.li=async function(){var e=$('li-e').value.trim(),p=$('li-p').value;if(!e||!p){$('li-er').textContent='Fill all fields';$('li-er').classList.add('show');return}$('li-s').classList.add('show');if(sb&&supabaseOnline){try{var r=await sb.auth.signInWithPassword({email:e,password:p});if(r.error)throw r.error;cu=r.data.user;svu();var meta=cu.user_metadata||{};var existing=localUsers.find(function(u){return u.id===cu.id||u.email===e});if(!existing){var supabaseUser={id:cu.id,name:meta.display_name||'User',email:e,password:p,handle:meta.handle||'@user',bio:meta.bio||'',avatar:meta.avatar||'',securityQuestion:'',securityAnswer:'',twoFactorPIN:''};saveLocalUser(supabaseUser);var allUsersStore2=JSON.parse(localStorage.getItem('cl_allUsers')||'[]');if(!allUsersStore2.find(function(u){return u.id===cu.id})){allUsersStore2.push({id:cu.id,name:meta.display_name||'User',handle:meta.handle||'@user',avatar:meta.avatar||''});localStorage.setItem('cl_allUsers',JSON.stringify(allUsersStore2))}}$('li-s').classList.remove('show');showApp();return}catch(err){console.log('Supabase login failed, trying local')}}var lu=findLocalUser(e,p);if(lu){if(lu.twoFactorPIN){$('li-s').classList.remove('show');window.pendingLoginUser=lu;showTwoFactorModal();return}cu=syncLocalUserToCu(lu);svu();$('li-s').classList.remove('show');showApp();showToast('Signed in (local mode)');return}$('li-s').classList.remove('show');$('li-er').textContent='Invalid email or password';$('li-er').classList.add('show')};

window.su=async function(){var n=$('su-n').value.trim(),e=$('su-e').value.trim(),p=$('su-p').value,sq=$('su-sq').value,sa=$('su-sa').value.trim(),fa=$('su-2fa').value.trim();if(!n||!e||!p){$('su-er').textContent='Fill all fields';$('su-er').classList.add('show');return}if(p.length<8){$('su-er').textContent='Password must be 8+ characters';$('su-er').classList.add('show');return}if(!/[A-Z]/.test(p)){$('su-er').textContent='Password needs at least one uppercase letter';$('su-er').classList.add('show');return}if(!/[a-z]/.test(p)){$('su-er').textContent='Password needs at least one lowercase letter';$('su-er').classList.add('show');return}if(!/[0-9]/.test(p)){$('su-er').textContent='Password needs at least one number';$('su-er').classList.add('show');return}if(!sq||!sa){$('su-er').textContent='Security question and answer are required';$('su-er').classList.add('show');return}if(fa&&fa.length!==6){$('su-er').textContent='2FA PIN must be exactly 6 digits';$('su-er').classList.add('show');return}if(!$('su-t').checked){$('su-er').textContent='You must agree to the terms';$('su-er').classList.add('show');return}if(!paypalConnected){$('su-er').textContent='Connect PayPal first';$('su-er').classList.add('show');return}if(findLocalUser(e,p)){$('su-er').textContent='Account already exists';$('su-er').classList.add('show');return}$('su-s').classList.add('show');if(sb&&supabaseOnline){try{var r=await sb.auth.signUp({email:e,password:p,options:{data:{display_name:n,handle:'@'+n.toLowerCase().replace(/\s+/g,''),bio:'',avatar:''}}});if(r.error)throw r.error;cu=r.data.user;svu();var meta2=cu.user_metadata||{};var existing2=localUsers.find(function(u){return u.id===cu.id||u.email===e});if(!existing2){var supabaseUser2={id:cu.id,name:meta2.display_name||n,email:e,password:p,handle:meta2.handle||'@'+n.toLowerCase().replace(/\s+/g,''),bio:meta2.bio||'',avatar:meta2.avatar||'',securityQuestion:sq,securityAnswer:sa,twoFactorPIN:fa||''};saveLocalUser(supabaseUser2);var allUsersStore3=JSON.parse(localStorage.getItem('cl_allUsers')||'[]');if(!allUsersStore3.find(function(u){return u.id===cu.id})){allUsersStore3.push({id:cu.id,name:meta2.display_name||n,handle:meta2.handle||'@'+n.toLowerCase().replace(/\s+/g,''),avatar:meta2.avatar||''});localStorage.setItem('cl_allUsers',JSON.stringify(allUsersStore3))}}var tmpEmail=localStorage.getItem('cl_paypal_email_temp');if(tmpEmail){localStorage.setItem('cl_paypal_email_'+cu.id,tmpEmail);localStorage.removeItem('cl_paypal_email_temp');localStorage.removeItem('cl_paypal_temp');localStorage.setItem('cl_paypal','connected')}$('su-s').classList.remove('show');if(r.data.session){showApp();return}else{showToast('Check your email to confirm!');$('su-s').classList.remove('show');return}}catch(err){console.log('Supabase signup failed, using local')}}var newUser={id:uid(),name:n,email:e,password:p,handle:'@'+n.toLowerCase().replace(/\s+/g,''),bio:'',avatar:'',securityQuestion:sq,securityAnswer:sa,twoFactorPIN:fa||''};saveLocalUser(newUser);cu=syncLocalUserToCu(newUser);svu();var tmpEmail2=localStorage.getItem('cl_paypal_email_temp');if(tmpEmail2){localStorage.setItem('cl_paypal_email_'+cu.id,tmpEmail2);localStorage.removeItem('cl_paypal_email_temp');localStorage.removeItem('cl_paypal_temp');localStorage.setItem('cl_paypal','connected')}$('su-s').classList.remove('show');showApp();showToast('Account created!')};

window.og=async function(){if(!sb){showToast('Auth service unavailable');return}try{await sb.auth.signInWithOAuth({provider:'google',options:{redirectTo:location.origin}})}catch(err){showToast('Google sign-in unavailable. Try email/password instead.')}};
window.ofb=async function(){if(!sb){showToast('Auth service unavailable');return}try{await sb.auth.signInWithOAuth({provider:'facebook',options:{redirectTo:location.origin}})}catch(err){showToast('Facebook sign-in unavailable. Try email/password instead.')}};

window.loadSecurityQuestion=function(){var e=$('fg-e').value.trim();var lu=localUsers.find(function(u){return u.email===e});if(lu&&lu.securityQuestion){$('sq-display').textContent='Q: '+lu.securityQuestion;$('sq-display').style.display='block';$('sq-answer-wrap').style.display='block';$('fg-btn').textContent='Verify Answer & Reset'}};window.sendReset=async function(){var e=$('fg-e').value.trim();if(!e){$('fg-er').textContent='Enter your email';$('fg-er').classList.add('show');return}var lu=localUsers.find(function(u){return u.email===e});if(lu&&lu.securityQuestion){var sa=$('fg-sa').value.trim();if(!sa){$('fg-er').textContent='Answer the security question';$('fg-er').classList.add('show');return}if(sa.toLowerCase()!==lu.securityAnswer.toLowerCase()){$('fg-er').textContent='Incorrect answer';$('fg-er').classList.add('show');return}var p1=$('fg-pw').value,p2=$('fg-pw2').value;if(!p1){$('new-pw-wrap').style.display='block';$('confirm-pw-wrap').style.display='block';$('fg-btn').textContent='Reset Password';$('fg-er').textContent='Enter your new password';$('fg-er').classList.add('show');return}if(p1.length<8||!/[A-Z]/.test(p1)||!/[a-z]/.test(p1)||!/[0-9]/.test(p1)){$('fg-er').textContent='Password must be 8+ chars with uppercase, lowercase, and number';$('fg-er').classList.add('show');return}if(p1!==p2){$('fg-er').textContent='Passwords do not match';$('fg-er').classList.add('show');return}lu.password=p1;localStorage.setItem('cl_localUsers',JSON.stringify(localUsers));$('fg-er').classList.remove('show');showToast('Password reset! Sign in with your new password');showLogin();return}$('fg-s').classList.add('show');if(sb&&supabaseOnline){try{await sb.auth.resetPasswordForEmail(e,{redirectTo:location.origin+'?reset=1'});$('fg-s').classList.remove('show');showToast('Reset link sent!');showLogin()}catch(err){$('fg-s').classList.remove('show');$('fg-er').textContent=err.message||'Failed to send';$('fg-er').classList.add('show')}}else{setTimeout(function(){$('fg-s').classList.remove('show');showToast('If this email exists, a reset link has been sent');showLogin()},1500)}};

window.lo=async function(){if(sb)await sb.auth.signOut();cu=null;localStorage.removeItem('cl_user');$('ma').style.display='none';$('auth-page').classList.remove('hidden');posts=[];localStorage.removeItem('cl_posts');showToast('Signed out')};

window.connectPayPal=function(){$('m-pp-setup').classList.add('on')};window.savePayPalEmail=function(){var e=$('pp-email').value.trim();if(!e||!e.includes('@')){showToast('Enter a valid email');return}if(cu&&cu.id){localStorage.setItem('cl_paypal_email_'+cu.id,e);localStorage.setItem('cl_paypal','connected')}else{localStorage.setItem('cl_paypal_email_temp',e);localStorage.setItem('cl_paypal_temp','connected')}paypalConnected='connected';$('pp-btn').innerHTML='PayPal Connected ✓';$('pp-btn').style.background='#1DB954';$('pp-status').textContent='PayPal connected: '+e;closeModal('m-pp-setup');showToast('PayPal connected!')};

// ==================== APP NAV ====================
window.showApp=function(){$('auth-page').classList.add('hidden');$('ma').style.display='block';if(cu){var meta=cu.user_metadata||{};var lu=localUsers.find(function(u){return u.id===cu.id});if(!lu){var newLocalUser={id:cu.id,name:meta.display_name||'User',email:cu.email||'',password:'',handle:meta.handle||'@user',bio:meta.bio||'',avatar:meta.avatar||'',securityQuestion:'',securityAnswer:'',twoFactorPIN:''};saveLocalUser(newLocalUser);lu=newLocalUser}var bio=meta.bio||'';var avatar=meta.avatar||'';if(lu){bio=lu.bio||bio;avatar=lu.avatar||avatar}var name=meta.display_name||'User';$('c-av').innerHTML=avatar?'<img src="'+avatar+'">':(name?name[0].toUpperCase():'?');$('p-n').textContent=name;$('p-h').textContent=meta.handle||'@user';$('p-b').textContent=bio||'No bio yet'}renderFeed();renderNotifDrop()};
window.navTo=function(p){var map=['feed','people','cam','messages','profile'];var pageMap={feed:'pg-feed',people:'pg-people',cam:'pg-cam',messages:'pg-messages',profile:'pg-profile',settings:'pg-settings',user:'pg-user','coming-soon':'pg-coming-soon'};if(!pageMap[p])return;map.forEach(function(x){var el=document.querySelector('.mit[onclick="navTo(\''+x+'\')"]');if(el)el.classList.remove('a')});var activeBtn=document.querySelector('.mit[onclick="navTo(\''+p+'\')"]');if(activeBtn)activeBtn.classList.add('a');Object.values(pageMap).forEach(function(id){$(id).classList.remove('active')});$(pageMap[p]).classList.add('active');cp=p;if(p==='profile'){renderProfile()}if(p==='people'){renderPeople()}if(p==='messages'){renderMessages();if(window.msgChannel){try{window.msgChannel.unsubscribe()}catch(e){}}window.msgChannel=null;window.currentConvId=null}};
function goBackFromUser(){if(cp==='people'){navTo('people')}else{navTo('feed')}}window.goBackFromUser=goBackFromUser;

// ==================== NOTIFICATIONS PULLDOWN ====================
window.toggleNotif=function(){$('notif-drop').classList.toggle('on')};
window.renderNotifDrop=function(){var d=$('notif-drop');if(!notifs.length){d.innerHTML='<div style="text-align:center;padding:20px;color:#666;font-size:13px">No notifications</div>';return}var h='';notifs.slice(0,10).forEach(function(n){h+='<div class="n-item">';h+='<div class="av">'+(n.un?n.un[0].toUpperCase():'N')+'</div>';h+='<div class="txt" style="flex:1"><b>'+esc(n.un||'User')+'</b> '+esc(n.txt)+'<div class="time">'+ago(n.ts)+'</div></div>';h+='</div>'});d.innerHTML=h};

// ==================== FEED ====================
window.cp=function(){if(!cu){showToast('Please sign in first');return}var t=$('pc-t').value.trim();if(!t){showToast('Write something first');return}var fontClass=$('pc-font').value;var tags=$('pc-tags').value.trim();var cmtOn=$('t-post-cmt').classList.contains('on');var loc=$('pc-loc').value.trim();var extractedTags=t.match(/#[a-zA-Z0-9_]+/g);var allTags=tags;if(extractedTags){var cleanExtracted=extractedTags.map(function(tag){return tag.toLowerCase()}).join(' ');allTags=tags?(tags+' '+cleanExtracted):cleanExtracted}var p={id:uid(),uid:cu.id,un:cu.user_metadata&&cu.user_metadata.display_name?cu.user_metadata.display_name:'User',uh:cu.user_metadata&&cu.user_metadata.handle?cu.user_metadata.handle:'@user',ua:cu.user_metadata&&cu.user_metadata.avatar?cu.user_metadata.avatar:'',t:t,fc:fontClass||'font-inter',ts:Date.now(),lk:[],dk:[],cm:[],c:cmtOn,subOnly:settings.subOnly,tags:allTags,loc:loc};posts.unshift(p);svp();$('pc-t').value='';$('pc-tags').value='';$('pc-loc').value='';renderFeed();showToast('Posted!')};

window.refreshFeed=function(){renderFeed();showToast('Feed refreshed')};window.renderFeed=function(){var fd=$('fd');if(!posts.length){fd.innerHTML='<div class="empty"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="16"/><line x1="8" y1="12" x2="16" y2="12"/></svg><h3>No posts yet</h3><p>Be the first to post something!</p></div>';return}var h='';posts.forEach(function(p){var isMe=cu&&p.uid===cu.id;var isBlocked=blocks.indexOf(p.uid)!==-1;if(isBlocked)return;var u=getUserData(p.uid);var name=u&&u.name?u.name:(p.un||'User');h+='<div class="post">';h+='<div class="post-h">';h+='<div class="av" onclick="viewUser('+(p.uid?"'"+p.uid+"'":'')+')">'+(p.ua?'<img src="'+p.ua+'">':name[0].toUpperCase())+'</div>';h+='<div class="u" style="flex:1"><div class="n" onclick="viewUser('+(p.uid?"'"+p.uid+"'":'')+')">'+esc(name)+'</div><div class="t">'+ago(p.ts)+'</div></div>';if(isMe){h+='<div style="display:flex;gap:8px;margin-left:auto"><button class="btn btn-outline btn-sm" style="padding:4px 8px;font-size:11px" onclick="editPost('+(p.id?"'"+p.id+"'":'')+')">✎ Edit</button><button class="btn btn-outline btn-sm" style="padding:4px 8px;font-size:11px;border-color:#FF3366;color:#FF3366" onclick="delPost('+(p.id?"'"+p.id+"'":'')+')">✕ Delete</button></div>'}if(p.subOnly){h+='<span style="font-size:10px;background:linear-gradient(135deg,#C4A35A,#B8944F);color:#1C1C1C;padding:2px 8px;border-radius:20px;font-weight:700">Subscribers Only</span>'}if(p.loc){h+='<span style="font-size:10px;background:#2A2A2A;color:#888;padding:2px 8px;border-radius:20px;margin-left:6px">📍 '+esc(p.loc)+'</span>'}h+='</div>';h+='<div class="post-c '+(p.fc||'font-inter')+'">'+linkHashtags(esc(p.t))+'</div>';if(p.m){if(p.v){h+='<video class="post-vid" src="'+p.m+'" controls playsinline></video>'}else{h+='<img class="post-img" src="'+p.m+'" onclick="this.requestFullscreen()">'}}h+='<div class="post-actions">';var loved=cu&&p.lk&&p.lk.indexOf(cu.id)!==-1;var hated=cu&&p.dk&&p.dk.indexOf(cu.id)!==-1;h+='<div class="pact '+(loved?'love':'')+'" onclick="lk('+(p.id?"'"+p.id+"'":'')+')">'+(loved?'❤️':'🤍')+' <span>'+(p.lk?p.lk.length:0)+'</span></div>';h+='<div class="pact '+(hated?'hate':'')+'" onclick="dk('+(p.id?"'"+p.id+"'":'')+')">'+(hated?'👎':'👎')+' <span>'+(p.dk?p.dk.length:0)+'</span></div>';if(p.c!==false){h+='<div class="pact" onclick="sc('+(p.id?"'"+p.id+"'":'')+')">💬 <span>'+(p.cm?p.cm.length:0)+'</span></div>'}else{h+='<div class="pact" style="opacity:0.4;cursor:default">💬 <span style="font-size:10px">Off</span></div>'}h+='<div class="pact share-c" onclick="sp('+(p.id?"'"+p.id+"'":'')+')">🔗 Share</div>';h+='</div>';if(p.c!==false&&p.cm&&p.cm.length){h+='<div class="cmt-sect" id="cmts-'+p.id+'">';h+='<div class="cmt-l">';p.cm.forEach(function(c){h+='<div class="cmt"><div class="av">'+(c.un?c.un[0].toUpperCase():'?')+'</div><div class="b"><div class="n">'+esc(c.un||'User')+'</div><div class="x">'+esc(c.x)+'</div></div></div>'});h+='</div>';h+='<div class="cmt-row"><input type="text" placeholder="Write a comment..." id="cm-'+p.id+'"><button class="btn btn-primary btn-sm" onclick="addCmt('+(p.id?"'"+p.id+"'":'')+')">Send</button></div>';h+='</div>'}h+='</div>'});fd.innerHTML=h};

window.lk=function(id){if(!cu){showToast('Sign in to react');return}var p=posts.find(function(x){return x.id===id});if(!p)return;if(!p.lk)p.lk=[];var i=p.lk.indexOf(cu.id);if(i>-1){p.lk.splice(i,1)}else{p.lk.push(cu.id);if(p.dk){var di=p.dk.indexOf(cu.id);if(di>-1)p.dk.splice(di,1)}}svp();renderFeed()};
window.dk=function(id){if(!cu){showToast('Sign in to react');return}var p=posts.find(function(x){return x.id===id});if(!p)return;if(!p.dk)p.dk=[];var i=p.dk.indexOf(cu.id);if(i>-1){p.dk.splice(i,1)}else{p.dk.push(cu.id);if(p.lk){var li=p.lk.indexOf(cu.id);if(li>-1)p.lk.splice(li,1)}}svp();renderFeed()};
window.sc=function(id){var el=$('cmts-'+id);if(el)el.classList.toggle('on')};
window.sp=function(id){var p=posts.find(function(x){return x.id===id});if(navigator.share){navigator.share({title:'My Chain Link',text:p?p.t:'',url:location.href})}else{showToast('Link copied!');if(navigator.clipboard)navigator.clipboard.writeText(location.href)}};
window.addCmt=function(id){if(!cu){showToast('Sign in to comment');return}var p=posts.find(function(x){return x.id===id});if(!p||p.c===false){showToast('Comments disabled on this post');return}var inp=$('cm-'+id);if(!inp)return;var t=inp.value.trim();if(!t)return;if(!p.cm)p.cm=[];p.cm.push({un:cu.user_metadata&&cu.user_metadata.display_name?cu.user_metadata.display_name:'User',x:t,ts:Date.now()});svp();renderFeed();var el=$('cmts-'+id);if(el)el.classList.add('on')};
window.previewProfilePhoto=function(input){var file=input.files[0];if(!file)return;var reader=new FileReader();reader.onload=function(e){var img=$('ep-a-img');img.src=e.target.result;img.parentElement.style.display='block';$('ep-a').setAttribute('data-url',e.target.result)};reader.readAsDataURL(file)};window.previewFont=function(){var sel=$('pc-font').value;var inp=$('pc-t');inp.className=sel};window.tPostCmt=function(){$('t-post-cmt').classList.toggle('on')};window.linkHashtags=function(t){if(!t)return t;return t.replace(/#([a-zA-Z0-9_]+)/g,'<span style="color:#E8D574;cursor:pointer" onclick="searchTag(\'$1\')">#$1</span>')};window.searchTag=function(tag){$('p-sch').value='#'+tag;navTo('people');schPpl('#'+tag)};

// ==================== CAMERA ====================
window.openCam=async function(){if(!cu){showToast('Please sign in first');return}$('cam-o').classList.add('on');try{var s=await navigator.mediaDevices.getUserMedia({video:{facingMode:camFacing},audio:false});camStream=s;$('cam-v').srcObject=s}catch(e){showToast('Camera error: '+e.message)}};
window.closeCam=function(){if(camStream){camStream.getTracks().forEach(function(t){t.stop()});camStream=null}$('cam-o').classList.remove('on');$('cam-pr').classList.remove('on');camData=''};
window.swCam=function(){camFacing=camFacing==='user'?'environment':'user';closeCam();openCam()};
window.snap=function(){var v=$('cam-v'),c=$('cam-c');c.width=v.videoWidth||640;c.height=v.videoHeight||480;var ctx=c.getContext('2d');if(camFacing==='user'){ctx.translate(c.width,0);ctx.scale(-1,1)}ctx.drawImage(v,0,0,c.width,c.height);camData=c.toDataURL('image/jpeg',0.9);$('cam-pi').src=camData;$('cam-pr').classList.add('on')};
window.retake=function(){$('cam-pr').classList.remove('on');camData=''};
window.postCam=function(){if(!camData||!cu)return;var t=$('cam-cap').value.trim();var cmtOn=$('t-post-cmt').classList.contains('on');var loc=$('cam-loc').value.trim();var p={id:uid(),uid:cu.id,un:cu.user_metadata&&cu.user_metadata.display_name?cu.user_metadata.display_name:'User',uh:cu.user_metadata&&cu.user_metadata.handle?cu.user_metadata.handle:'@user',ua:cu.user_metadata&&cu.user_metadata.avatar?cu.user_metadata.avatar:'',t:t,m:camData,v:false,ts:Date.now(),lk:[],dk:[],cm:[],c:cmtOn,subOnly:settings.subOnly,tags:'',loc:loc};posts.unshift(p);svp();closeCam();$('cam-cap').value='';$('cam-loc').value='';renderFeed();showToast('Posted!')};var editingPostId=null;window.editPost=function(id){var p=posts.find(function(x){return x.id===id});if(!p)return;editingPostId=id;$('epost-t').value=p.t||'';$('m-edit-post').classList.add('on')};window.saveEditPost=function(){if(!editingPostId)return;var p=posts.find(function(x){return x.id===editingPostId});if(!p)return;var t=$('epost-t').value.trim();if(!t){showToast('Post cannot be empty');return}p.t=t;var extractedTags=t.match(/#[a-zA-Z0-9_]+/g);if(extractedTags){var cleanExtracted=extractedTags.map(function(tag){return tag.toLowerCase()}).join(' ');p.tags=p.tags?(p.tags+' '+cleanExtracted):cleanExtracted}svp();renderFeed();closeModal('m-edit-post');editingPostId=null;showToast('Post updated!')};window.delPost=function(id){if(!confirm('Delete this post? This cannot be undone.'))return;var i=posts.findIndex(function(x){return x.id===id});if(i>-1){posts.splice(i,1);svp();renderFeed();showToast('Post deleted')}};

// ==================== PROFILE ====================
window.renderProfile=function(){if(!cu)return;var lu=localUsers.find(function(u){return u.id===cu.id});var has2FA=lu&&lu.twoFactorPIN;$('2fa-status').textContent=has2FA?'On':'Off';$('2fa-status').style.color=has2FA?'#1DB954':'#888';var myPosts=posts.filter(function(p){return p.uid===cu.id});$('p-sp').textContent=myPosts.length;if(sb&&supabaseOnline&&cu){sb.from('follows').select('*').eq('following_id',cu.id).then(function(r){var count=(r.data||[]).length;$('p-fl').textContent=count}).catch(function(){$('p-fl').textContent=(JSON.parse(localStorage.getItem('cl_followers')||'{}')[cu.id]||[]).length})}else{$('p-fl').textContent=(JSON.parse(localStorage.getItem('cl_followers')||'{}')[cu.id]||[]).length}$('p-fg').textContent=Object.keys(follows).filter(function(k){return follows[k]&&follows[k].following}).length;var isPremium=localStorage.getItem('cl_premium_'+cu.id);if(isPremium){$('p-premium').style.display='block'}else{$('p-premium').style.display='none'};var h='';var mediaPosts=myPosts.filter(function(p){return p.m});if(!mediaPosts.length){h='<div style="text-align:center;padding:40px;color:#555">No posts yet</div>'}else{h='<div class="pgrid">';mediaPosts.forEach(function(p){h+='<div class="pi">';if(p.v){h+='<video src="'+p.m+'" muted playsInline></video>'}else{h+='<img src="'+p.m+'">'}h+='</div>'});h+='</div>'}$('p-posts').innerHTML=h;var spLink=localStorage.getItem('cl_spotify_'+cu.id);if(spLink){$('sp-link').value=spLink;renderSpotify(spLink)}};
window.saveSpotify=function(){if(!cu)return;var link=$('sp-link').value.trim();if(!link)return;localStorage.setItem('cl_spotify_'+cu.id,link);renderSpotify(link)};
function renderSpotify(link){if(!link)return;var embedDiv=$('sp-embed');embedDiv.innerHTML='';if(link.indexOf('open.spotify.com')>-1){var parts=link.split('/');var type=parts[parts.length-2]||'track';var id=parts[parts.length-1].split('?')[0];if(id){var url='https://open.spotify.com/embed/'+type+'/'+id;var height=type==='playlist'?'380':'80';embedDiv.innerHTML='<iframe src="'+url+'" width="100%" height="'+height+'" frameborder="0" allowtransparency="true" allow="encrypted-media" style="border-radius:8px"></iframe>'}}}window.renderSpotify=renderSpotify;

// ==================== SETTINGS ====================
window.editProfileModal=function(){if(!cu){showToast('Sign in to edit profile');return}var meta=cu.user_metadata||{};$('ep-n').value=meta.display_name||'';$('ep-h').value=meta.handle||'@user';$('ep-b').value=meta.bio||'';var previewDiv=$('ep-a-preview');if(previewDiv)previewDiv.style.display='none';var img=$('ep-a-img');if(img)img.src='';var inp=$('ep-a');if(inp){inp.value='';inp.removeAttribute('data-url');if(meta.avatar){inp.setAttribute('data-url',meta.avatar)}}$('m-edit').classList.add('on')};
window.saveEdit=function(){
  var n=$('ep-n').value.trim();
  var h=$('ep-h').value.trim();
  var b=$('ep-b').value.trim();
  var a=$('ep-a').getAttribute('data-url')||$('ep-a').value.trim();
  if(!cu)return;
  var meta=cu.user_metadata||{};
  var newName=n||meta.display_name||'User';
  var newHandle=h.indexOf('@')===0?h:'@'+h.replace('@','');
  if(newHandle==='@')newHandle='@user';
  var newBio=b||meta.bio||'';
  var newAvatar=a||meta.avatar||'';
  if(sb&&supabaseOnline){
    sb.auth.updateUser({data:{display_name:newName,handle:newHandle,bio:newBio,avatar:newAvatar}})
    .then(function(r){
      if(r.error){showToast(r.error.message)}
      else{cu=r.data.user;finishEdit(newName,newHandle,newBio,newAvatar)}
    })
    .catch(function(e){showToast('Error: '+e.message)});
  }else{
    var lu=localUsers.find(function(u){return u.id===cu.id});
    if(lu){lu.name=newName;lu.handle=newHandle;lu.bio=newBio;lu.avatar=newAvatar;localStorage.setItem('cl_localUsers',JSON.stringify(localUsers));cu=syncLocalUserToCu(lu);svu();finishEdit(newName,newHandle,newBio,newAvatar)}
    else{showToast('User not found')}
  }
};
function finishEdit(n,h,b,a){
  svu();
  $('p-n').textContent=n||'User';
  $('p-h').textContent=h||'@user';
  $('p-b').textContent=b||'No bio yet';
  $('p-av').innerHTML=a?'<img src="'+a+'">':(n?n[0].toUpperCase():'?');
  $('c-av').innerHTML=a?'<img src="'+a+'">':(n?n[0].toUpperCase():'?');
  posts.forEach(function(p){if(p.uid===cu.id){p.un=n||p.un;p.uh=h||p.uh;p.ua=a||p.ua}});
  svp();renderFeed();renderProfile();showToast('Profile updated!');closeModal('m-edit')
}
window.finishEdit=finishEdit;
window.changePwModal=function(){$('m-pw').classList.add('on');$('pw-er').classList.remove('show')};window.setup2FAModal=function(){if(!cu)return;var lu=localUsers.find(function(u){return u.id===cu.id});var has2FA=lu&&lu.twoFactorPIN;$('2fa-setup-text').textContent=has2FA?'Change your 2FA PIN or remove it.':'Set a 6-digit PIN to protect your account.';$('2fa-current-wrap').style.display=has2FA?'block':'none';$('2fa-new').value='';$('2fa-confirm').value='';$('2fa-current').value='';$('2fa-er').classList.remove('show');$('m-2fa-setup').classList.add('on')};window.save2FA=function(){var lu=localUsers.find(function(u){return u.id===cu.id});if(!lu)return;var current=$('2fa-current').value;var newpin=$('2fa-new').value;var confirm=$('2fa-confirm').value;if(lu.twoFactorPIN&&current!==lu.twoFactorPIN){$('2fa-er').textContent='Current PIN is incorrect';$('2fa-er').classList.add('show');return}if(!newpin||newpin.length!==6||!/^[0-9]{6}$/.test(newpin)){$('2fa-er').textContent='PIN must be exactly 6 digits';$('2fa-er').classList.add('show');return}if(newpin!==confirm){$('2fa-er').textContent='PINs do not match';$('2fa-er').classList.add('show');return}lu.twoFactorPIN=newpin;localStorage.setItem('cl_localUsers',JSON.stringify(localUsers));$('2fa-er').classList.remove('show');closeModal('m-2fa-setup');showToast('2FA enabled!');$('2fa-status').textContent='On';$('2fa-status').style.color='#1DB954'};
window.savePw=function(){var p1=$('pw1').value,p2=$('pw2').value,er=$('pw-er');if(p1.length<6){er.textContent='Password must be 6+ characters';er.classList.add('show');return}if(p1!==p2){er.textContent='Passwords do not match';er.classList.add('show');return}er.classList.remove('show');if(sb&&supabaseOnline){sb.auth.updateUser({password:p1}).then(function(r){if(r.error)showToast(r.error.message);else{showToast('Password updated!');closeModal('m-pw')}}).catch(function(e){showToast('Error')});return}var lu=localUsers.find(function(u){return u.id===cu.id});if(lu){lu.password=p1;localStorage.setItem('cl_localUsers',JSON.stringify(localUsers));showToast('Password updated!');closeModal('m-pw')}};
window.tCmt=function(){$('t-cmt').classList.toggle('on');settings.comments=$('t-cmt').classList.contains('on');svs()};
window.tSubOnly=function(){$('t-subonly').classList.toggle('on');settings.subOnly=$('t-subonly').classList.contains('on');svs()};
window.tNot=function(){$('t-not').classList.toggle('on');settings.notifs=$('t-not').classList.contains('on');svs()};
window.tDm=function(){$('t-dm').classList.toggle('on');settings.dark=$('t-dm').classList.contains('on');svs()};
window.delAccountModal=function(){$('m-del').classList.add('on')};
window.delAccount=function(){var confirm=$('del-confirm').value.trim();if(confirm!=='DELETE'){showToast('Type DELETE to confirm');return}if(sb)sb.auth.signOut();localStorage.clear();cu=null;posts=[];location.reload()};

// ==================== PEOPLE / USERS ====================
window.getUserData=function(id){if(!id)return null;if(cu&&id===cu.id)return{id:cu.id,name:cu.user_metadata&&cu.user_metadata.display_name?cu.user_metadata.display_name:'User',handle:cu.user_metadata&&cu.user_metadata.handle?cu.user_metadata.handle:'@user',avatar:cu.user_metadata&&cu.user_metadata.avatar?cu.user_metadata.avatar:'',bio:cu.user_metadata&&cu.user_metadata.bio?cu.user_metadata.bio:''};var lu=localUsers.find(function(u){return u.id===id});if(lu)return{id:lu.id,name:lu.name||lu.user_metadata&&lu.user_metadata.display_name||'User',handle:lu.handle||lu.user_metadata&&lu.user_metadata.handle||'@user',avatar:lu.avatar||lu.user_metadata&&lu.user_metadata.avatar||'',bio:lu.bio||lu.user_metadata&&lu.user_metadata.bio||''};var allUsersStore=JSON.parse(localStorage.getItem('cl_allUsers')||'[]');var fromAll=allUsersStore.find(function(u){return u.id===id});if(fromAll)return{id:fromAll.id,name:fromAll.name||fromAll.user_metadata&&fromAll.user_metadata.display_name||'User',handle:fromAll.handle||fromAll.user_metadata&&fromAll.user_metadata.handle||'@user',avatar:fromAll.avatar||fromAll.user_metadata&&fromAll.user_metadata.avatar||'',bio:fromAll.bio||fromAll.user_metadata&&fromAll.user_metadata.bio||''};var fromPost=posts.find(function(p){return p.uid===id});if(fromPost)return{id:id,name:fromPost.un||'User',handle:fromPost.uh||'@user',avatar:fromPost.ua||'',bio:''};return null};
window.renderPeople=function(){var list=$('ppl-list');var allUsers=[];var allUsersMap={};function addUser(u){if(!u||!u.id)return;if(cu&&u.id===cu.id)return;if(allUsersMap[u.id])return;allUsersMap[u.id]=true;allUsers.push(u)}localUsers.forEach(function(u){addUser({id:u.id,name:u.name||u.user_metadata&&u.user_metadata.display_name||'User',handle:u.handle||u.user_metadata&&u.user_metadata.handle||'@user',avatar:u.avatar||u.user_metadata&&u.user_metadata.avatar||''})});posts.forEach(function(p){addUser({id:p.uid,name:p.un||'User',handle:p.uh||'@user',avatar:p.ua||''})});var allUsersStore=JSON.parse(localStorage.getItem('cl_allUsers')||'[]');allUsersStore.forEach(function(u){addUser(u)});if(!allUsers.length){list.innerHTML='<div class="empty"><h3>No people yet</h3><p>Be the first to join and invite friends!</p></div>';return}var h='';allUsers.forEach(function(u){var isBlocked=blocks.indexOf(u.id)!==-1;var isFollowing=follows[u.id]&&follows[u.id].following;var isSubbed=follows[u.id]&&follows[u.id].subscribed;h+='<div class="p-card">';h+='<div class="av">'+(u.avatar?'<img src="'+u.avatar+'">':(u.name?u.name[0].toUpperCase():'?'))+'</div>';h+='<div class="info"><div class="n">'+esc(u.name)+'</div><div class="h">'+esc(u.handle)+'</div></div>';h+='<div class="actions">';if(!isBlocked){h+='<button class="btn btn-outline btn-sm" onclick="viewUser('+(u.id?"'"+u.id+"'":'')+')">View</button>';if(cu&&u.id!==cu.id){h+='<button class="btn btn-outline btn-sm" onclick="navTo(\'messages\');openThread('+(u.id?\"'\"+u.id+\"'\":'')+')">Message</button>';h+='<button class="btn '+(isFollowing?'btn-outline':'btn-primary')+' btn-sm" onclick="toggleFollowId('+(u.id?"'"+u.id+"'":'')+');renderPeople()">'+(isFollowing?'Disconnect':'Connect')+'</button>';}}else{h+='<span style="color:#FF3366;font-size:12px">Blocked</span>'}h+='</div>';h+='</div>'});list.innerHTML=h};
window.schPpl=function(v){var list=$('ppl-list');if(!v.trim()){renderPeople();return}var term=v.toLowerCase();var allUsers=[];var allUsersMap={};function addUser(u){if(!u||!u.id)return;if(cu&&u.id===cu.id)return;if(allUsersMap[u.id])return;allUsersMap[u.id]=true;allUsers.push(u)}localUsers.forEach(function(u){addUser({id:u.id,name:u.name||u.user_metadata&&u.user_metadata.display_name||'User',handle:u.handle||u.user_metadata&&u.user_metadata.handle||'@user',avatar:u.avatar||u.user_metadata&&u.user_metadata.avatar||''})});posts.forEach(function(p){if(p.uid&&p.uid!==(cu&&cu.id)&&!allUsersMap[p.uid]){addUser({id:p.uid,name:p.un||'User',handle:p.uh||'@user',avatar:p.ua||''})}});var allUsersStore=JSON.parse(localStorage.getItem('cl_allUsers')||'[]');allUsersStore.forEach(function(u){addUser(u)});var filtered=allUsers.filter(function(u){return(u.name||'').toLowerCase().indexOf(term)>-1||(u.handle||'').toLowerCase().indexOf(term)>-1});if(term.indexOf('#')===0){var tagPosts=posts.filter(function(p){return p.tags&&p.tags.toLowerCase().indexOf(term)>-1});tagPosts.forEach(function(p){if(p.uid&&p.uid!==(cu&&cu.id)){var u=getUserData(p.uid);if(u)addUser(u)}});filtered=allUsers.filter(function(u){return(u.name||'').toLowerCase().indexOf(term)>-1||(u.handle||'').toLowerCase().indexOf(term)>-1||(u.tags||'').toLowerCase().indexOf(term)>-1})}if(!filtered.length){list.innerHTML='<div class="empty"><h3>No results</h3><p>No users match "'+esc(v)+'"</p></div>';return}var h='';filtered.forEach(function(u){var isFollowing=follows[u.id]&&follows[u.id].following;h+='<div class="p-card">';h+='<div class="av">'+(u.avatar?'<img src="'+u.avatar+'">':(u.name?u.name[0].toUpperCase():'?'))+'</div>';h+='<div class="info"><div class="n">'+esc(u.name)+'</div><div class="h">'+esc(u.handle)+'</div></div>';h+='<div class="actions">';h+='<button class="btn btn-outline btn-sm" onclick="viewUser('+(u.id?"'"+u.id+"'":'')+')">View</button>';if(cu&&u.id!==cu.id){h+='<button class="btn btn-outline btn-sm" onclick="navTo(\'messages\');openThread('+(u.id?\"'\"+u.id+\"'\":'')+')">Message</button>';h+='<button class="btn '+(isFollowing?'btn-outline':'btn-primary')+' btn-sm" onclick="toggleFollowId('+(u.id?"'"+u.id+"'":'')+');schPpl(\''+v.replace(/'/g,"\\'")+'\')">'+(isFollowing?'Disconnect':'Connect')+'</button>'}h+='</div>';h+='</div>'});list.innerHTML=h};
window.viewUser=function(id){if(!id)return;var u=getUserData(id);if(!u)return;vu=u;var isMe=cu&&u.id===cu.id;var myPosts=posts.filter(function(p){return p.uid===u.id});$('vu-av').innerHTML=u.avatar?'<img src="'+u.avatar+'">':(u.name?u.name[0].toUpperCase():'?');$('vu-name').textContent=u.name||'User';$('vu-h').textContent=u.handle||'@user';$('vu-b').textContent=u.bio||'No bio yet';$('vu-sp').textContent=myPosts.length;var uFollowing=0;var uFollowers=0;var uSubscribers=0;function finishViewUser(){if(follows[u.id]&&follows[u.id].following)uFollowing++;$('vu-fl').textContent=uFollowers;$('vu-fg').textContent=uFollowing;var isPremium=localStorage.getItem('cl_premium_'+u.id);if(isPremium){$('vu-premium').style.display='block'}else{$('vu-premium').style.display='none'};var promo=$('vu-premium-promo');if(promo){var myPremium=localStorage.getItem('cl_premium_'+(cu?cu.id:''));if(isPremium&&!myPremium){promo.style.display='block';$('vu-premium-promo-text').textContent='Become a Premium Link to watch '+esc(u.name||'User')+'\'s live content and unlock exclusive posts'}else{promo.style.display='none'}};$('vu-fbtn').textContent=follows[u.id]&&follows[u.id].following?'Disconnect':'Connect';$('vu-bbtn').textContent=blocks.indexOf(u.id)!==-1?'Unblock':'Block';$('vu-bbtn').style.display=isMe?'none':'inline-flex';$('vu-sbtn').style.display=isMe?'none':'inline-flex';$('vu-fbtn').style.display=isMe?'none':'inline-flex';var h='';var mediaPosts=myPosts.filter(function(p){return p.m});if(!mediaPosts.length){h='<div style="text-align:center;padding:40px;color:#555">No posts yet</div>'}else{h='<div class="pgrid">';mediaPosts.forEach(function(p){h+='<div class="pi">';if(p.v){h+='<video src="'+p.m+'" muted playsInline></video>'}else{h+='<img src="'+p.m+'">'}h+='</div>'});h+='</div>'}$('vu-posts').innerHTML=h;navTo('user')}if(sb&&supabaseOnline){sb.from('follows').select('*').eq('following_id',u.id).then(function(r){var ids=[];(r.data||[]).forEach(function(f){ids.push(f.follower_id);if(f.subscribed)uSubscribers++});uFollowers=ids.length;var localFl=JSON.parse(localStorage.getItem('cl_followers')||'{}');localFl[u.id]=ids;localStorage.setItem('cl_followers',JSON.stringify(localFl));finishViewUser()}).catch(function(){finishViewUser()})}else{finishViewUser()}};
window.toggleFollowVU=function(){if(!cu||!vu)return;if(!follows[vu.id])follows[vu.id]={following:false,subscribed:false};follows[vu.id].following=!follows[vu.id].following;svf();saveFollowSupabase(vu.id,follows[vu.id].following);var allFollowers=JSON.parse(localStorage.getItem('cl_followers')||'{}');if(!allFollowers[vu.id])allFollowers[vu.id]=[];var myIdx=allFollowers[vu.id].indexOf(cu.id);if(follows[vu.id].following){if(myIdx===-1)allFollowers[vu.id].push(cu.id)}else{if(myIdx>-1)allFollowers[vu.id].splice(myIdx,1)}localStorage.setItem('cl_followers',JSON.stringify(allFollowers));$('vu-fbtn').textContent=follows[vu.id].following?'Disconnect':'Connect';showToast(follows[vu.id].following?'Connected!':'Disconnected')};
window.toggleFollow=function(){if(!cu)return};
window.toggleFollowId=function(id){if(!cu||!id)return;if(!follows[id])follows[id]={following:false,subscribed:false};follows[id].following=!follows[id].following;svf();saveFollowSupabase(id,follows[id].following);var allFollowers=JSON.parse(localStorage.getItem('cl_followers')||'{}');if(!allFollowers[id])allFollowers[id]=[];var myIdx=allFollowers[id].indexOf(cu.id);if(follows[id].following){if(myIdx===-1)allFollowers[id].push(cu.id)}else{if(myIdx>-1)allFollowers[id].splice(myIdx,1)}localStorage.setItem('cl_followers',JSON.stringify(allFollowers))};
window.toggleBlock=function(){if(!cu||!vu)return;var i=blocks.indexOf(vu.id);if(i>-1){blocks.splice(i,1);showToast('Unblocked');$('vu-bbtn').textContent='Block'}else{blocks.push(vu.id);showToast('Blocked');$('vu-bbtn').textContent='Unblock';if(follows[vu.id]){follows[vu.id].following=false;follows[vu.id].subscribed=false}svf()}svb()};
window.showFollowers=function(){if(!cu)return;$('flw-t').textContent='Connects';var h='';function renderFollowerList(ids){if(!ids.length){h='<div style="text-align:center;padding:20px;color:#666">No connects yet</div>'}else{ids.forEach(function(id){var u=getUserData(id);if(!u)return;h+='<div class="p-card" style="margin-bottom:8px;cursor:pointer" onclick="viewUserFromModal(this)" data-uid="'+id+'">';h+='<div class="av" style="width:40px;height:40px">'+(u.avatar?'<img src="'+u.avatar+'">':(u.name?u.name[0].toUpperCase():'?'))+'</div>';h+='<div class="info"><div class="n">'+esc(u.name)+'</div><div class="h">'+esc(u.handle)+'</div></div>';h+='</div>'})}$('flw-l').innerHTML=h;$('m-flw').classList.add('on')}if(sb&&supabaseOnline){sb.from('follows').select('*').eq('following_id',cu.id).then(function(r){var ids=[];(r.data||[]).forEach(function(f){ids.push(f.follower_id)});var localFl=JSON.parse(localStorage.getItem('cl_followers')||'{}');localFl[cu.id]=ids;localStorage.setItem('cl_followers',JSON.stringify(localFl));renderFollowerList(ids)}).catch(function(){var ids=(JSON.parse(localStorage.getItem('cl_followers')||'{}')[cu.id]||[]);renderFollowerList(ids)})}else{var ids=(JSON.parse(localStorage.getItem('cl_followers')||'{}')[cu.id]||[]);renderFollowerList(ids)}};
window.viewUserFromModal=function(el){var id=el.getAttribute('data-uid');if(id){closeModal('m-flw');viewUser(id)}};window.showFollowing=function(){if(!cu)return;$('flw-t').textContent='Connected to';var h='';var followingIds=Object.keys(follows).filter(function(k){return follows[k]&&follows[k].following});if(!followingIds.length){h='<div style="text-align:center;padding:20px;color:#666">Not connected to anyone yet</div>'}else{followingIds.forEach(function(id){var u=getUserData(id);if(!u)return;h+='<div class="p-card" style="margin-bottom:8px;cursor:pointer" onclick="viewUserFromModal(this)" data-uid="'+id+'">';h+='<div class="av" style="width:40px;height:40px">'+(u.avatar?'<img src="'+u.avatar+'">':(u.name?u.name[0].toUpperCase():'?'))+'</div>';h+='<div class="info"><div class="n">'+esc(u.name)+'</div><div class="h">'+esc(u.handle)+'</div></div>';h+='</div>'})}$('flw-l').innerHTML=h;$('m-flw').classList.add('on')};

// ==================== SUBSCRIBE ====================
window.openSubModal=function(){$('m-pp-checkout').classList.add('on');var btnContainer=$('paypal-button-container');if(btnContainer)btnContainer.innerHTML='';setTimeout(function(){processRealSub()},300)};window.openSubVU=function(){if(!vu){showToast('No user selected');return}var u=getUserData(vu.id);if(!u)return;$('sub-to-name').textContent=u.name||'Creator';$('sub-to-n').textContent=u.name||'User';$('sub-to-av').innerHTML=u.avatar?'<img src="'+u.avatar+'">':(u.name?u.name[0].toUpperCase():'?');$('m-pp-checkout').classList.add('on');var btnContainer=$('paypal-button-container');if(btnContainer)btnContainer.innerHTML='';setTimeout(function(){processRealSub()},300)};window.ppHostedButton=null;window.processRealSub=function(){if(!cu){showToast('Sign in to subscribe');return}if(!vu){showToast('No user selected');return}var creatorPaypal=localStorage.getItem('cl_paypal_email_'+vu.id);if(!creatorPaypal){showToast('This creator has not set up PayPal yet');return}if(typeof paypal==='undefined'||!paypal.HostedButtons){showToast('PayPal is loading, please wait');return}var container=$('paypal-container-8L8HY2ULYKSFL');if(!container)return;if(ppHostedButton){try{ppHostedButton.close()}catch(e){}}container.innerHTML='';ppHostedButton=paypal.HostedButtons({hostedButtonId:'8L8HY2ULYKSFL'});ppHostedButton.render('#paypal-container-8L8HY2ULYKSFL')};

// ==================== LIVE STREAMING (WebRTC) ====================
var liveStream = null;
var liveViewers = 0;
var liveStreamId = null;
var liveIsBroadcaster = false;
var liveStreamerId = null;
var liveSignalChannel = null;
var livePcMap = {};
var liveViewerPc = null;
var liveChatMsgs = [];
var liveIceServers = [
  { urls: 'stun:stun.l.google.com:19302' },
  { urls: 'stun:stun1.l.google.com:19302' }
];

window.goLive = async function() {
  if (!cu) { showToast('Please sign in first'); return; }
  var isPremium = localStorage.getItem('cl_premium_' + cu.id);
  if (!isPremium) { showToast('Premium only'); navTo('coming-soon'); return; }
  try {
    var s = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' }, audio: true });
    liveStream = s;
    liveIsBroadcaster = true;
    if (sb && supabaseOnline) {
      var title = (cu.user_metadata && cu.user_metadata.display_name ? cu.user_metadata.display_name : 'User') + ' is live';
      var r = await sb.from('live_streams').insert({ user_id: cu.id, title: title, is_active: true, room_id: cu.id + '-' + Date.now() }).select().single();
      if (!r.error && r.data) liveStreamId = r.data.id;
    }
    if (!liveStreamId) liveStreamId = cu.id + '-' + Date.now();
    $('live-o').classList.add('on');
    $('live-v').srcObject = s;
    $('live-v').muted = true;
    $('live-end-btn').textContent = 'End Live';
    $('live-end-btn').style.display = 'block';
    $('live-chat').innerHTML = '';
    liveChatMsgs = [];
    $('live-viewers').textContent = '0 viewers';
    setupLiveSignalChannel(true);
    showToast('You are LIVE');
  } catch (e) { showToast('Camera error: ' + e.message); cleanupLive(); }
};

window.watchLive = async function(streamId, streamerId, streamerName) {
  if (!cu) { showToast('Please sign in first'); return; }
  liveStreamId = streamId;
  liveStreamerId = streamerId;
  liveIsBroadcaster = false;
  $('live-o').classList.add('on');
  $('live-v').srcObject = null;
  $('live-v').muted = false;
  $('live-end-btn').textContent = 'Leave Stream';
  $('live-end-btn').style.display = 'block';
  $('live-chat').innerHTML = '';
  liveChatMsgs = [];
  $('live-viewers').textContent = 'Joining...';
  var topInfo = document.createElement('div');
  topInfo.id = 'live-streamer-info';
  topInfo.style.cssText = 'position:absolute;top:60px;left:16px;z-index:10;color:#fff;font-weight:700;font-size:16px;text-shadow:0 1px 4px rgba(0,0,0,0.8)';
  topInfo.textContent = streamerName || 'Live Stream';
  var existing = $('live-streamer-info');
  if (existing) existing.remove();
  $('live-o').appendChild(topInfo);
  if (sb && supabaseOnline && streamId) {
    sb.from('stream_viewers').upsert({ stream_id: streamId, user_id: cu.id }, { onConflict: 'stream_id,user_id' }).catch(function(){});
  }
  setupLiveSignalChannel(false);
  showToast('Joining live stream...');
};

function setupLiveSignalChannel(isBroadcaster) {
  if (!sb || !supabaseOnline) return;
  if (liveSignalChannel) { try { liveSignalChannel.unsubscribe(); } catch(e) {} }
  var chName = 'stream-signal-' + liveStreamId;
  liveSignalChannel = sb.channel(chName);
  liveSignalChannel.on('broadcast', { event: 'signal' }, function(payload) {
    var msg = payload.payload;
    if (!msg) return;
    if (isBroadcaster) handleBroadcasterSignal(msg);
    else handleViewerSignal(msg);
  });
  liveSignalChannel.subscribe(function(status) {
    if (status === 'SUBSCRIBED' && !isBroadcaster) {
      liveSignalChannel.send({ type: 'broadcast', event: 'signal', payload: { type: 'join', from: cu.id, to: 'all' } });
    }
  });
}

async function handleBroadcasterSignal(msg) {
  if (msg.type === 'join' && msg.from !== cu.id) {
    var viewerId = msg.from;
    var pc = new RTCPeerConnection({ iceServers: liveIceServers });
    livePcMap[viewerId] = pc;
    if (liveStream) liveStream.getTracks().forEach(function(track) { pc.addTrack(track, liveStream); });
    pc.onicecandidate = function(e) {
      if (e.candidate) liveSignalChannel.send({ type: 'broadcast', event: 'signal', payload: { type: 'ice', from: cu.id, to: viewerId, data: e.candidate } });
    };
    pc.onconnectionstatechange = function() { if (pc.connectionState === 'connected') updateLiveViewerCount(); };
    var offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    liveSignalChannel.send({ type: 'broadcast', event: 'signal', payload: { type: 'offer', from: cu.id, to: viewerId, data: offer } });
  }
  if (msg.type === 'answer' && msg.to === cu.id) {
    var pc = livePcMap[msg.from];
    if (pc) await pc.setRemoteDescription(new RTCSessionDescription(msg.data));
  }
  if (msg.type === 'ice' && msg.to === cu.id) {
    var pc = livePcMap[msg.from];
    if (pc) await pc.addIceCandidate(new RTCIceCandidate(msg.data));
  }
  if (msg.type === 'chat') appendLiveChat(msg.fromName || 'User', msg.text, msg.from === cu.id);
}

async function handleViewerSignal(msg) {
  if (msg.type === 'offer' && msg.to === cu.id) {
    if (liveViewerPc) { try { liveViewerPc.close(); } catch(e) {} }
    liveViewerPc = new RTCPeerConnection({ iceServers: liveIceServers });
    liveViewerPc.ontrack = function(e) {
      if (e.streams && e.streams[0]) { $('live-v').srcObject = e.streams[0]; $('live-viewers').textContent = 'Connected'; }
    };
    liveViewerPc.onicecandidate = function(e) {
      if (e.candidate && liveSignalChannel) liveSignalChannel.send({ type: 'broadcast', event: 'signal', payload: { type: 'ice', from: cu.id, to: liveStreamerId, data: e.candidate } });
    };
    await liveViewerPc.setRemoteDescription(new RTCSessionDescription(msg.data));
    var answer = await liveViewerPc.createAnswer();
    await liveViewerPc.setLocalDescription(answer);
    liveSignalChannel.send({ type: 'broadcast', event: 'signal', payload: { type: 'answer', from: cu.id, to: liveStreamerId, data: answer } });
  }
  if (msg.type === 'ice' && msg.to === cu.id && liveViewerPc) await liveViewerPc.addIceCandidate(new RTCIceCandidate(msg.data));
  if (msg.type === 'chat') appendLiveChat(msg.fromName || 'User', msg.text, msg.from === cu.id);
}

function updateLiveViewerCount() {
  var count = Object.keys(livePcMap).length;
  liveViewers = count;
  $('live-viewers').textContent = count + ' viewer' + (count !== 1 ? 's' : '');
  if (sb && supabaseOnline && liveStreamId) sb.from('live_streams').update({ viewer_count: count }).eq('id', liveStreamId).catch(function(){});
}

function appendLiveChat(name, text, isMe) {
  var chat = $('live-chat');
  var div = document.createElement('div');
  div.className = 'live-chat-msg';
  if (isMe) { div.style.alignSelf = 'flex-end'; div.style.background = 'rgba(232,213,116,0.2)'; div.style.color = '#E8D574'; }
  div.innerHTML = '<b>' + esc(name) + ':</b> ' + esc(text);
  chat.appendChild(div);
  chat.scrollTop = chat.scrollHeight;
  if (chat.children.length > 30) chat.removeChild(chat.firstChild);
}

window.sendLiveChat = function() {
  var inp = $('live-chat-input');
  var t = inp.value.trim();
  if (!t) return;
  var name = cu && cu.user_metadata && cu.user_metadata.display_name ? cu.user_metadata.display_name : 'You';
  appendLiveChat(name, t, true);
  if (liveSignalChannel) liveSignalChannel.send({ type: 'broadcast', event: 'signal', payload: { type: 'chat', from: cu.id, fromName: name, text: t } });
  inp.value = '';
};

window.endLive = function() {
  if (liveIsBroadcaster) { if (!confirm('End your live stream?')) return; cleanupLive(); showToast('Live ended'); }
  else { cleanupLive(); showToast('Left stream'); }
};

function cleanupLive() {
  $('live-o').classList.remove('on');
  if (liveStream) { liveStream.getTracks().forEach(function(t) { t.stop(); }); liveStream = null; }
  if (liveViewerPc) { try { liveViewerPc.close(); } catch(e) {} liveViewerPc = null; }
  Object.keys(livePcMap).forEach(function(k) { try { livePcMap[k].close(); } catch(e) {} });
  livePcMap = {};
  if (liveSignalChannel) { try { liveSignalChannel.unsubscribe(); } catch(e) {} liveSignalChannel = null; }
  if (liveIsBroadcaster && liveStreamId && sb && supabaseOnline) sb.from('live_streams').update({ is_active: false, ended_at: new Date().toISOString() }).eq('id', liveStreamId).catch(function(){});
  if (!liveIsBroadcaster && liveStreamId && cu && sb && supabaseOnline) sb.from('stream_viewers').update({ left_at: new Date().toISOString() }).eq('stream_id', liveStreamId).eq('user_id', cu.id).catch(function(){});
  var info = $('live-streamer-info'); if (info) info.remove();
  $('live-chat').innerHTML = '';
  liveChatMsgs = [];
  liveStreamId = null;
  liveStreamerId = null;
  liveIsBroadcaster = false;
  liveViewers = 0;
}

window.loadActiveStreams = async function() {
  var container = $('active-streams-banner');
  if (!container) return;
  if (!sb || !supabaseOnline) { container.style.display = 'none'; return; }
  try {
    var r = await sb.from('live_streams').select('*, profiles:user_id(display_name, handle, avatar_url)').eq('is_active', true).order('started_at', { ascending: false });
    var streams = r.data || [];
    if (!streams.length) { container.style.display = 'none'; return; }
    var h = '<div style="display:flex;gap:12px;overflow-x:auto;padding:4px 0">';
    streams.forEach(function(s) {
      var prof = s.profiles || {};
      var name = prof.display_name || 'User';
      var avatar = prof.avatar_url ? '<img src="' + prof.avatar_url + '" style="width:100%;height:100%;object-fit:cover">' : name[0].toUpperCase();
      h += '<div onclick="watchLive(\'' + s.id + '\',\'' + s.user_id + '\',\'' + esc(name) + '\')" style="flex:0 0 auto;text-align:center;cursor:pointer">';
      h += '<div style="width:64px;height:64px;border-radius:50%;background:#FF3366;display:flex;align-items:center;justify-content:center;color:#fff;font-weight:700;font-size:24px;border:3px solid #FF3366;position:relative">';
      h += '<div style="position:absolute;inset:0;border-radius:50%;overflow:hidden">' + avatar + '</div>';
      h += '<div style="position:absolute;bottom:-2px;right:-2px;background:#FF3366;color:#fff;font-size:9px;font-weight:700;padding:2px 6px;border-radius:8px">LIVE</div>';
      h += '</div>';
      h += '<div style="font-size:12px;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:70px">' + esc(name) + '</div>';
      h += '</div>';
    });
    h += '</div>';
    container.innerHTML = h;
    container.style.display = 'block';
  } catch(e) { container.style.display = 'none'; }
};

// ==================== VIDEO CALLS ====================
window.startVideoCall = async function() {
  if (!cu) { showToast('Please sign in first'); return; }
  $('call-o').classList.add('on');
  $('call-status').textContent = 'Calling...';
  try {
    var s = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' }, audio: true });
    $('call-local-v').srcObject = s;
    callStream = s;
    setTimeout(function() {
      $('call-status').textContent = 'In call · 0:00';
      callSeconds = 0;
      callTimer = setInterval(function() {
        callSeconds++;
        var m = Math.floor(callSeconds / 60);
        var s = callSeconds % 60;
        $('call-status').textContent = 'In call · ' + m + ':' + (s < 10 ? '0' : '') + s;
      }, 1000);
    }, 2000);
  } catch (e) { showToast('Camera error: ' + e.message); endCall(); }
};
window.endCall = function() {
  $('call-o').classList.remove('on');
  if (callStream) { callStream.getTracks().forEach(function(t) { t.stop(); }); callStream = null; }
  if (callTimer) { clearInterval(callTimer); callTimer = null; }
  $('call-status').textContent = 'Calling...';
  showToast('Call ended');
};
var callStream = null;
var callTimer = null;
var callSeconds = 0;

// ==================== MESSAGES ====================
window.renderMessages=function (){var list=$('conv-list');var promo=$('msg-premium-promo');if(promo){var isPremium=localStorage.getItem('cl_premium_'+(cu?cu.id:''));promo.style.display=isPremium?'none':'block'}if(!cu){list.innerHTML='<div class="empty"><h3>Sign in</h3><p>Sign in to send messages</p></div>';return}if(sb&&supabaseOnline){sb.from('conversations').select('*').or('participant_1.eq.'+cu.id+',participant_2.eq.'+cu.id).order('updated_at',{ascending:false}).limit(50).then(function(r){if(r.error){console.log('Conv error',r.error);renderMessagesLocal();return}var convs=r.data||[];if(!convs.length){list.innerHTML='<div class="empty"><h3>No conversations</h3><p>Start messaging people from posts</p></div>';return}var h='';convs.forEach(function(c){var otherId=c.participant_1===cu.id?c.participant_2:c.participant_1;if(blocks.indexOf(otherId)!==-1)return;var u=getUserData(otherId)||{name:'User',handle:'@user',avatar:''};var lastMsg=c.last_message_text||'Tap to start chatting';var lastTime=c.last_message_at?ago(new Date(c.last_message_at).getTime()):'';h+='<div class="p-card" style="cursor:pointer" onclick="openThread('+(otherId?"'"+otherId+"'":'')+')">';h+='<div class="av" style="width:52px;height:52px">'+(u.avatar?'<img src="'+u.avatar+'">':(u.name?u.name[0].toUpperCase():'?'))+'</div>';h+='<div class="info" style="flex:1;min-width:0"><div class="n">'+esc(u.name)+'</div><div class="h" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis">'+esc(lastMsg)+'</div></div>';h+='<div style="text-align:right;flex-shrink:0;font-size:11px;color:#666">'+lastTime+'</div>';h+='</div>'});list.innerHTML=h}).catch(function(e){console.log('Conv catch',e);renderMessagesLocal()})}else{renderMessagesLocal()}};window.renderMessagesLocal=function(){var list=$('conv-list');if(!cu){list.innerHTML='<div class="empty"><h3>Sign in</h3><p>Sign in to send messages</p></div>';return}var uids=[];posts.forEach(function(p){if(p.uid&&p.uid!==cu.id&&uids.indexOf(p.uid)===-1&&blocks.indexOf(p.uid)===-1)uids.push(p.uid)});Object.keys(conversations).forEach(function(k){if(k!==cu.id&&uids.indexOf(k)===-1&&blocks.indexOf(k)===-1)uids.push(k)});if(!uids.length){list.innerHTML='<div class="empty"><h3>No conversations</h3><p>Start messaging people from posts</p></div>';return}var h='';uids.forEach(function(id){var u=getUserData(id);if(!u)return;var msgs=conversations[id]||[];var lastMsg=msgs.length?msgs[msgs.length-1].text:'Tap to start chatting';var lastTime=msgs.length?ago(msgs[msgs.length-1].ts):'';h+='<div class="p-card" style="cursor:pointer" onclick="openThread('+(id?"'"+id+"'":'')+')">';h+='<div class="av" style="width:52px;height:52px">'+(u.avatar?'<img src="'+u.avatar+'">':(u.name?u.name[0].toUpperCase():'?'))+'</div>';h+='<div class="info" style="flex:1;min-width:0"><div class="n">'+esc(u.name)+'</div><div class="h" style="white-space:nowrap;overflow:hidden;text-overflow:ellipsis">'+esc(lastMsg)+'</div></div>';h+='<div style="text-align:right;flex-shrink:0;font-size:11px;color:#666">'+lastTime+'</div>';h+='</div>'});list.innerHTML=h};
window.openThread=function(id){var u=getUserData(id);if(!u)return;activeThread=id;$('msg-list-view').style.display='none';$('msg-thread-view').style.display='flex';$('th-av').innerHTML=u.avatar?'<img src="'+u.avatar+'">':(u.name?u.name[0].toUpperCase():'?');$('th-name').textContent=u.name||'User';loadMessages(id)};window.loadMessages=function(id){if(!id)return;if(sb&&supabaseOnline){sb.rpc('get_or_create_conversation',{user1:cu.id,user2:id}).then(function(r){if(r.error){console.log('get_or_create_conversation error',r.error);renderThread();return}var convId=r.data;var otherId=id;activeThread=otherId;window.currentConvId=convId;renderThreadFromSupabase(convId,otherId);startMsgRealtime(convId,otherId)}).catch(function(e){console.log('get_or_create_conversation catch',e);renderThread()})}else{renderThread()}};window.renderThreadFromSupabase=function(convId,otherId){if(!convId)return;window.currentConvId=convId;activeThread=otherId;sb.from('messages').select('*').eq('conversation_id',convId).order('created_at',{ascending:true}).then(function(r){if(r.error){console.log('Messages error',r.error);renderThread();return}var msgs=r.data||[];var localMsgs=[];msgs.forEach(function(m){localMsgs.push({text:m.content,sent:m.sender_id===cu.id,ts:new Date(m.created_at).getTime()})});conversations[otherId]=localMsgs;svc();renderThreadLocalMsgs(localMsgs)}).catch(function(e){console.log('Messages catch',e);renderThread()})};window.startMsgRealtime=function(convId,otherId){if(window.msgChannel){try{window.msgChannel.unsubscribe()}catch(e){}}window.msgChannel=sb.channel('messages-'+convId).on('postgres_changes',{event:'INSERT',schema:'public',table:'messages',filter:'conversation_id=eq.'+convId},function(payload){var m=payload.new;if(!m)return;var isSent=m.sender_id===cu.id;if(isSent)return;var localMsgs=conversations[otherId]||[];localMsgs.push({text:m.content,sent:false,ts:new Date(m.created_at).getTime()});conversations[otherId]=localMsgs;svc();if(activeThread===otherId){renderThreadLocalMsgs(localMsgs)}}).subscribe()};
window.backToConv=function(){activeThread=null;window.currentConvId=null;if(window.msgChannel){try{window.msgChannel.unsubscribe()}catch(e){}}window.msgChannel=null;$('msg-thread-view').style.display='none';$('msg-list-view').style.display='block'};
function renderThread(){if(!activeThread)return;if(window.currentConvId&&sb&&supabaseOnline){renderThreadFromSupabase(window.currentConvId,activeThread);return}renderThreadLocalMsgs(conversations[activeThread]||[])}window.renderThread=renderThread;window.renderThreadLocalMsgs=function(msgs){msgs=msgs||[];var h='';msgs.forEach(function(m){var isSent=m.sent;h+='<div style="align-self:'+(isSent?'flex-end':'flex-start')+';max-width:75%">';h+='<div style="padding:10px 14px;border-radius:'+(isSent?'16px 16px 4px 16px':'16px 16px 16px 4px')+';background:'+(isSent?'linear-gradient(135deg,#F5E6A3,#E8D574)':'#2A2A2A')+';color:'+(isSent?'#1C1C1C':'#F0F0F0')+';font-size:14px">'+esc(m.text)+'</div>';h+='<div style="font-size:10px;color:#666;margin-top:2px;text-align:'+(isSent?'right':'left')+'">'+new Date(m.ts).toLocaleTimeString([],{hour:'2-digit',minute:'2-digit'})+'</div>';h+='</div>'});$('msg-bubbles').innerHTML=h;$('msg-bubbles').scrollTop=$('msg-bubbles').scrollHeight};
window.sendMsg=function(){if(!activeThread)return;var inp=$('msg-input');var t=inp.value.trim();if(!t)return;var localMsgs=conversations[activeThread]||[];localMsgs.push({text:t,sent:true,ts:Date.now()});conversations[activeThread]=localMsgs;svc();renderThreadLocalMsgs(localMsgs);inp.value='';if(sb&&supabaseOnline&&window.currentConvId){sb.from('messages').insert({conversation_id:window.currentConvId,sender_id:cu.id,receiver_id:activeThread,content:t}).then(function(r){if(r.error){console.log('Send error',r.error);showToast('Message saved locally')}}).catch(function(e){console.log('Send catch',e);showToast('Message saved locally')})}};

// ==================== OFFLINE HANDLING ====================
window.addEventListener('offline',function(){showToast('You are offline. Some features may not work.')});window.addEventListener('online',function(){showToast('You are back online!')});
// ==================== INIT ====================
function tryLogin(){if(localStorage.getItem('cl_user')){try{cu=JSON.parse(localStorage.getItem('cl_user'));showApp();loadAllFollows();return true}catch(e){}}return false}
if(sb&&supabaseOnline){sb.auth.getSession().then(function(r){if(r.data&&r.data.session){cu=r.data.session.user;svu();showApp();loadAllFollows()}else{tryLogin()}}).catch(function(){tryLogin()})}else{tryLogin()}
// Check for PayPal return
if(location.search.includes('paypal')){setTimeout(function(){if(vu){if(!follows[vu.id])follows[vu.id]={following:false,subscribed:false};follows[vu.id].subscribed=true;svf();showToast('Payment successful! You are now subscribed.');history.replaceState(null,'',location.pathname)}},1000)}}