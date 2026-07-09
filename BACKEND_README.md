# MyChainLink Backend API

## Setup

1. Install dependencies:
```bash
npm install
```

2. Copy `.env.example` to `.env` and fill in your Supabase credentials:
```bash
cp .env.example .env
```

3. Start the server:
```bash
npm run dev
```

## Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | /api/health | No | Health check |
| GET | /api/posts | No | Get all posts |
| POST | /api/posts | Yes | Create post |
| POST | /api/follows | Yes | Connect to user |
| DELETE | /api/follows/:id | Yes | Disconnect from user |
| GET | /api/follows/:userId | No | Get followers/following |
| GET | /api/conversations | Yes | Get my conversations |
| POST | /api/conversations | Yes | Start conversation |
| GET | /api/messages/:id | Yes | Get messages in thread |
| POST | /api/messages | Yes | Send message |
| GET | /api/notifications | Yes | Get notifications |
| PATCH | /api/notifications/:id/read | Yes | Mark read |
| POST | /api/streams | Yes | Start live stream |
| GET | /api/streams/active | No | Get active streams |
| POST | /api/streams/:id/end | Yes | End stream |

## Common Pitfalls

1. **CORS errors**: If frontend can't connect, check CORS origin in server.js
2. **RLS failures**: If API returns 500 but SQL works, check RLS policies in Supabase
3. **Auth token**: Pass `Authorization: Bearer <token>` header from Supabase session

## Production Deployment

- Railway: `railway up`
- Render: Connect GitHub repo
- Heroku: `git push heroku main`
- AWS: Use Elastic Beanstalk or ECS
