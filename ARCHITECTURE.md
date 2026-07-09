# MYCHAINLINK ARCHITECTURE v1.0

## EXECUTIVE SUMMARY

A real-time social platform built on **authentic connections** — no filters, no gallery uploads, camera-only content. Designed for global scale from day one.

---

## 1. TECH STACK

### Phase 1: MVP (Current)
| Layer | Technology | Why |
|-------|------------|-----|
| Frontend | Vanilla JS + HTML | Fast iteration, no build step |
| Backend | Supabase (PostgreSQL) | Auth, DB, real-time subscriptions |
| Storage | Supabase Storage | CDN-backed media uploads |
| Hosting | Netlify | Simple drag-and-drop deploy |

### Phase 2: Scale (Recommended)
| Layer | Technology | Why |
|-------|------------|-----|
| Frontend | Next.js 14 (App Router) | SSR, SEO, React ecosystem |
| Styling | Tailwind CSS | Utility-first, fast development |
| Backend | Node.js + Express | Custom API logic, WebRTC signaling |
| Real-time | Redis + Socket.io | Pub/sub, presence, distributed messaging |
| Database | PostgreSQL (Supabase) | Keep existing data, add read replicas |
| Cache | Redis | Session management, rate limiting |
| Media | Supabase Storage / AWS S3 | Presigned URLs, CDN delivery |
| Payments | Stripe + PayPal (server-side) | Webhooks, creator payouts, secure |
| WebRTC | Mediasoup (SFU) | Production-grade live streaming, video calls |
| Infra | Vercel + Railway/AWS | Edge deployment, global CDN |

---

## 2. DATABASE SCHEMA

```
users
├── id (uuid, PK)
├── email (text, unique)
├── display_name (text)
├── handle (text, unique)
├── bio (text)
├── avatar_url (text)
├── is_premium (boolean)
├── paypal_email (text)
├── stripe_account_id (text)
├── two_factor_pin (text)
├── security_question (text)
├── security_answer (text)
├── created_at (timestamp)
└── last_login (timestamp)

posts
├── id (uuid, PK)
├── user_id (uuid, FK → users.id)
├── content (text)
├── media_url (text)
├── media_type (enum: image, video)
├── is_camera_only (boolean)
├── has_comments (boolean)
├── is_premium_only (boolean)
├── price (decimal) -- for locked content
├── tags (text[])
├── location (text)
├── likes_count (integer)
├── comments_count (integer)
├── created_at (timestamp)
└── updated_at (timestamp)

follows
├── id (uuid, PK)
├── follower_id (uuid, FK → users.id)
├── following_id (uuid, FK → users.id)
├── subscribed (boolean) -- premium subscription
├── created_at (timestamp)
└── UNIQUE(follower_id, following_id)

conversations
├── id (uuid, PK)
├── participant_1 (uuid, FK → users.id)
├── participant_2 (uuid, FK → users.id)
├── last_message_at (timestamp)
└── created_at (timestamp)

messages
├── id (uuid, PK)
├── conversation_id (uuid, FK → conversations.id)
├── sender_id (uuid, FK → users.id)
├── content (text)
├── media_url (text)
├── media_type (enum: text, image, video)
├── is_read (boolean)
├── created_at (timestamp)
└── updated_at (timestamp)

blocks
├── id (uuid, PK)
├── blocker_id (uuid, FK → users.id)
├── blocked_id (uuid, FK → users.id)
├── created_at (timestamp)
└── UNIQUE(blocker_id, blocked_id)

notifications
├── id (uuid, PK)
├── user_id (uuid, FK → users.id)
├── type (enum: like, comment, follow, message, mention)
├── actor_id (uuid, FK → users.id)
├── reference_id (uuid) -- post_id or message_id
├── is_read (boolean)
├── created_at (timestamp)

payments
├── id (uuid, PK)
├── payer_id (uuid, FK → users.id)
├── payee_id (uuid, FK → users.id)
├── amount (decimal)
├── currency (text)
├── platform_fee (decimal)
├── creator_payout (decimal)
├── status (enum: pending, completed, failed, refunded)
├── payment_method (enum: paypal, stripe)
├── external_id (text) -- PayPal/Stripe transaction ID
├── created_at (timestamp)
└── completed_at (timestamp)

live_streams
├── id (uuid, PK)
├── user_id (uuid, FK → users.id)
├── title (text)
├── is_active (boolean)
├── viewer_count (integer)
├── started_at (timestamp)
└── ended_at (timestamp)

stream_viewers
├── id (uuid, PK)
├── stream_id (uuid, FK → live_streams.id)
├── user_id (uuid, FK → users.id)
├── joined_at (timestamp)
└── left_at (timestamp)
```

---

## 3. USER FLOWS

### Sign Up → Onboarding
```
1. Landing Page → Click "Join"
2. Fill: Name, Email, Password, Security Q/A
3. Optional: 2FA PIN setup
4. Connect PayPal (for creators)
5. Verify email (Supabase auth)
6. Set profile: Handle, Bio, Avatar
7. Welcome tutorial (camera-first post)
```

### Core Loop (Authenticated User)
```
Feed
├── Create Post (camera-only, optional text, tags, location)
├── Scroll Feed (likes, comments, shares)
├── View Profile → Connect/Disconnect
├── View Profile → Subscribe (premium)
├── DM → Open Thread
└── Go Live (premium only)

People Discovery
├── Search by name/handle
├── Browse by hashtag
├── View Profile → Connect
├── View Profile → Message
└── Block (anti-bullying)

Messages
├── Conversation List
├── Thread View
├── Send: Text, Camera Photo, Video (premium)
└── Video Call (premium only)
```

### Creator Monetization (Premium)
```
1. User becomes Premium (Stripe/PayPal)
2. Sets locked content price per post
3. Goes Live (premium badge shown)
4. Followers pay to unlock content
5. Platform takes X%, creator gets Y%
6. Payout to connected PayPal/Stripe
```

---

## 4. API ARCHITECTURE (High-Level)

### Supabase REST/GraphQL (Phase 1)
- All CRUD via Supabase client
- RLS policies for security
- Real-time subscriptions for messages, notifications, feed

### Custom Node.js API (Phase 2)
```
POST /api/auth/refresh
POST /api/payments/create-intent
POST /api/payments/confirm
POST /api/webhooks/stripe
POST /api/webhooks/paypal
POST /api/webrtc/signal
POST /api/live/start
POST /api/live/join
POST /api/live/end
GET  /api/live/:id/viewers
```

---

## 5. REAL-TIME ARCHITECTURE

### Messaging (Supabase Realtime → Redis)
**Phase 1:** Supabase Realtime for instant messages
**Phase 2:** Redis Pub/Sub for distributed messaging across multiple servers

### WebRTC (Video Calls / Live Streaming)
```
1. Signaling Server (Node.js + Socket.io)
   - Exchange SDP offers/answers
   - Exchange ICE candidates
2. STUN/TURN Server (Coturn or Twilio)
   - NAT traversal for peer connections
3. SFU for Live Streaming (Mediasoup)
   - Selective Forwarding Unit
   - One broadcaster → many viewers
   - Scales to thousands of concurrent viewers
```

---

## 6. SECURITY & COMPLIANCE

- **RLS Policies:** Every table has row-level security
- **Rate Limiting:** Redis-based, per user per endpoint
- **Content Moderation:** AI-based toxicity detection + user reporting
- **GDPR:** Data export, deletion endpoints
- **Payments:** PCI compliance via Stripe/PayPal (no card data stored)

---

## 7. DEPLOYMENT STRATEGY

### Phase 1: MVP (Now)
- **Frontend:** Netlify (drag-and-drop)
- **Backend:** Supabase (managed PostgreSQL + Auth)
- **Media:** Supabase Storage
- **Domain:** mychainlink.ca (CNAME to Netlify)

### Phase 2: Scale (Next)
- **Frontend:** Vercel (Next.js, edge caching)
- **Backend:** Railway or AWS ECS (Node.js containers)
- **Database:** Supabase Pro (read replicas, connection pooling)
- **Cache:** Redis Cloud or Upstash
- **WebRTC:** Dedicated TURN/SFU servers

---

## 8. PHASE ROADMAP

| Phase | Goal | Timeline | Deliverable |
|-------|------|----------|-------------|
| **1.1** | Fix core bugs | Week 1 | Working nav, auth, posts, follows |
| **1.2** | Real-time features | Week 2 | Supabase messages, notifications |
| **1.3** | Camera + media | Week 3 | Supabase Storage, camera-only upload |
| **2.0** | Premium system | Week 4-5 | PayPal/Stripe backend, locked content |
| **2.1** | Live streaming | Week 6-7 | WebRTC SFU, live badge, viewer count |
| **2.2** | Video calls | Week 8 | 1:1 WebRTC peer connections |
| **3.0** | Scale prep | Week 9-10 | Next.js migration, Redis, Node.js API |
| **3.1** | Global launch | Week 11-12 | CDN, load testing, monitoring |

---

## 9. CRITICAL DECISIONS

1. **Camera-Only Enforcement:** How? Browser API can't block file picker. Solution: Metadata tagging + community reporting + AI image analysis (detect edited/filtered images).
2. **Anti-Bullying:** Comments toggle per post + auto-hide toxic comments (Perspective API) + one-click block.
3. **Creator Payouts:** PayPal Payouts API or Stripe Connect. Platform fee: 20-30% (standard).
4. **Content Moderation:** Hybrid approach. AI pre-screen + human review for reports.

---

## 10. NEXT STEPS

1. **Fix current app** (nav, auth, Supabase follows table)
2. **Wire up real-time messaging** (Supabase messages table + RLS)
3. **Add media storage** (Supabase Storage bucket + presigned URLs)
4. **Build premium backend** (Node.js + Stripe/PayPal webhooks)
5. **Prototype WebRTC** (simple peer-to-peer video call)

**Ready to start coding when you are.**
