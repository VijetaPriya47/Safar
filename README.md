# SafarKnots

Safety-first travel companion platform. Find travelers on your train or flight, form groups, and coordinate your journey.

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Next.js 15 (App Router) + TypeScript + Tailwind CSS |
| Backend | Hono + TypeScript |
| Database + Auth + Realtime | Supabase (PostgreSQL + RLS + Realtime) |
| State | Zustand + TanStack Query |
| Monorepo | Turborepo + npm workspaces |
| Deploy | Vercel (web) + Railway (api) |

## Project Structure

```
safarknots/
├── apps/
│   ├── web/          # Next.js frontend → Vercel
│   └── api/          # Hono REST API → Railway
├── packages/
│   └── types/        # Shared TypeScript types
└── supabase/
    └── migrations/   # PostgreSQL schema + RLS
```

## Quick Start

### 1. Create Supabase project

1. Go to [supabase.com](https://supabase.com) → New project
2. Copy your **Project URL** and **anon key** (Settings → API)
3. Copy your **service role key** (Settings → API → secret)
4. Run the migration: Dashboard → SQL Editor → paste `supabase/migrations/001_init.sql` → Run
5. Enable Google OAuth: Authentication → Providers → Google → enable, add Client ID & Secret

### 2. Set up environment variables

```bash
# apps/web/.env.local
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
NEXT_PUBLIC_API_URL=http://localhost:3001

# apps/api/.env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
ALLOWED_ORIGIN=http://localhost:3000
PORT=3001
```

### 3. Install and run

```bash
npm install
npm run dev    # starts both web (3000) and api (3001)
```

## Supabase Auth Setup

In Supabase Dashboard → Authentication → URL Configuration:
- **Site URL**: `http://localhost:3000` (dev) / your Vercel URL (prod)
- **Redirect URLs**: `http://localhost:3000/auth/callback` (dev)

## Deploy

### Vercel (Frontend)
```bash
vercel --cwd apps/web
```
Set env vars: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `NEXT_PUBLIC_API_URL`

### Railway (Backend)
```bash
railway up --service api
```
Set env vars: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `ALLOWED_ORIGIN`, `PORT`

## API Overview

```
POST /auth/sync-profile          # Upsert user after Google OAuth
GET  /auth/me

GET  /users/:id                  # Public profile
PUT  /users/me                   # Update profile
POST /users/:id/block

POST /journeys                   # Create journey → auto-creates room
GET  /journeys/:id
DELETE /journeys/:id

GET  /rooms                      # Browse rooms (?type=&date=&destination=)
GET  /rooms/:id                  # Room + members + groups
POST /rooms/:id/join
DELETE /rooms/:id/leave
GET  /rooms/:id/messages         # Paginated history

POST /rooms/:id/groups           # Create group
GET  /rooms/:id/groups
GET  /groups/:id
POST /groups/:id/join
PUT  /groups/:id/members/:userId # approve / reject
DELETE /groups/:id/members/:userId
GET  /groups/:id/messages

POST /reports
```

## Features by Phase

- **Phase 1 (done):** Foundation — auth, monorepo, API scaffold
- **Phase 2:** Journeys + Rooms — create journey → room, browse, join
- **Phase 3:** Groups + Chat — real-time chat via Supabase Realtime
- **Phase 4:** Discovery + Verification — filters, PNR/student badges
- **Phase 5:** Safety — reports, blocks, moderation, mobile polish
