-- ═══════════════════════════════════════════════════════════════
-- SafarKnots — Initial Schema + RLS Policies
-- ═══════════════════════════════════════════════════════════════

-- ── Extensions ───────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ── Tables ───────────────────────────────────────────────────────────────────

CREATE TABLE users (
  id              uuid PRIMARY KEY,                        -- matches auth.users.id
  email           text UNIQUE NOT NULL,
  name            text NOT NULL,
  avatar_url      text,
  google_id       text UNIQUE NOT NULL,
  bio             text,
  gender          text CHECK (gender IN ('male','female','other','prefer_not_to_say')),
  college_name    text,
  college_verified boolean NOT NULL DEFAULT false,
  pnr_verified    boolean NOT NULL DEFAULT false,
  is_blocked      boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE journeys (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  journey_type  text NOT NULL CHECK (journey_type IN ('train','flight','route')),
  train_number  text,
  flight_number text,
  source        text NOT NULL,
  destination   text NOT NULL,
  journey_date  date NOT NULL,
  pnr_number    text,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE rooms (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_key     text UNIQUE NOT NULL,
  room_type    text NOT NULL CHECK (room_type IN ('train','flight','route')),
  identifier   text,
  source       text NOT NULL,
  destination  text NOT NULL,
  journey_date date NOT NULL,
  member_count int NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE room_members (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id    uuid NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  journey_id uuid REFERENCES journeys(id),
  joined_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (room_id, user_id)
);

CREATE TABLE groups (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id          uuid NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  creator_id       uuid NOT NULL REFERENCES users(id),
  name             text NOT NULL,
  description      text,
  gender_filter    text NOT NULL DEFAULT 'any' CHECK (gender_filter IN ('all_boys','all_girls','mixed','any')),
  batch_filter     text NOT NULL DEFAULT 'any',
  max_members      int NOT NULL DEFAULT 10,
  visibility       text NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','private')),
  requires_approval boolean NOT NULL DEFAULT false,
  member_count     int NOT NULL DEFAULT 1,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE group_members (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    uuid NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      text NOT NULL DEFAULT 'approved' CHECK (status IN ('pending','approved','rejected')),
  joined_at   timestamptz NOT NULL DEFAULT now(),
  approved_at timestamptz,
  approved_by uuid REFERENCES users(id),
  UNIQUE (group_id, user_id)
);

CREATE TABLE messages (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id      uuid REFERENCES rooms(id) ON DELETE CASCADE,
  group_id     uuid REFERENCES groups(id) ON DELETE CASCADE,
  sender_id    uuid NOT NULL REFERENCES users(id),
  content      text NOT NULL,
  message_type text NOT NULL DEFAULT 'text' CHECK (message_type IN ('text','system')),
  is_deleted   boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT messages_target_check CHECK (
    (room_id IS NOT NULL AND group_id IS NULL) OR
    (room_id IS NULL AND group_id IS NOT NULL)
  )
);

CREATE TABLE reports (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id      uuid NOT NULL REFERENCES users(id),
  reported_user_id uuid NOT NULL REFERENCES users(id),
  room_id          uuid REFERENCES rooms(id),
  group_id         uuid REFERENCES groups(id),
  reason           text NOT NULL,
  description      text,
  status           text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','reviewed','resolved')),
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE blocks (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (blocker_id, blocked_id)
);

CREATE TABLE verifications (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type         text NOT NULL CHECK (type IN ('pnr','college')),
  document_url text,
  status       text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','verified','rejected')),
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- ── Indexes ──────────────────────────────────────────────────────────────────

CREATE INDEX idx_journeys_user_id ON journeys(user_id);
CREATE INDEX idx_journeys_date ON journeys(journey_date);
CREATE INDEX idx_rooms_destination ON rooms(destination);
CREATE INDEX idx_rooms_date ON rooms(journey_date);
CREATE INDEX idx_rooms_type ON rooms(room_type);
CREATE INDEX idx_room_members_room ON room_members(room_id);
CREATE INDEX idx_room_members_user ON room_members(user_id);
CREATE INDEX idx_groups_room ON groups(room_id);
CREATE INDEX idx_group_members_group ON group_members(group_id);
CREATE INDEX idx_group_members_user ON group_members(user_id);
CREATE INDEX idx_messages_room ON messages(room_id, created_at);
CREATE INDEX idx_messages_group ON messages(group_id, created_at);
CREATE INDEX idx_blocks_blocker ON blocks(blocker_id);
CREATE INDEX idx_blocks_blocked ON blocks(blocked_id);

-- ── Helper RPCs (member count management) ────────────────────────────────────

CREATE OR REPLACE FUNCTION increment_room_member_count(room_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE rooms SET member_count = member_count + 1 WHERE id = room_id;
$$;

CREATE OR REPLACE FUNCTION decrement_room_member_count(room_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE rooms SET member_count = GREATEST(0, member_count - 1) WHERE id = room_id;
$$;

CREATE OR REPLACE FUNCTION increment_group_member_count(group_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE groups SET member_count = member_count + 1 WHERE id = group_id;
$$;

CREATE OR REPLACE FUNCTION decrement_group_member_count(group_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE groups SET member_count = GREATEST(1, member_count - 1) WHERE id = group_id;
$$;

-- ── Enable RLS ───────────────────────────────────────────────────────────────

ALTER TABLE users         ENABLE ROW LEVEL SECURITY;
ALTER TABLE journeys      ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms         ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_members  ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups        ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages      ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports       ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocks        ENABLE ROW LEVEL SECURITY;
ALTER TABLE verifications ENABLE ROW LEVEL SECURITY;

-- ── RLS Policies ─────────────────────────────────────────────────────────────

-- users: public read of non-blocked users, self update
CREATE POLICY "users_select" ON users
  FOR SELECT USING (NOT is_blocked);

CREATE POLICY "users_insert" ON users
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update" ON users
  FOR UPDATE USING (auth.uid() = id);

-- journeys: owner only
CREATE POLICY "journeys_select" ON journeys
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "journeys_insert" ON journeys
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "journeys_update" ON journeys
  FOR UPDATE USING (auth.uid() = user_id);

-- rooms: public read
CREATE POLICY "rooms_select" ON rooms
  FOR SELECT USING (true);

CREATE POLICY "rooms_insert" ON rooms
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "rooms_update" ON rooms
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- room_members: public read, insert if authenticated
CREATE POLICY "room_members_select" ON room_members
  FOR SELECT USING (true);

CREATE POLICY "room_members_insert" ON room_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "room_members_delete" ON room_members
  FOR DELETE USING (auth.uid() = user_id);

-- groups: public groups visible to all, private only to members
CREATE POLICY "groups_select_public" ON groups
  FOR SELECT USING (
    visibility = 'public'
    OR creator_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM group_members gm
      WHERE gm.group_id = id
        AND gm.user_id = auth.uid()
        AND gm.status = 'approved'
    )
  );

CREATE POLICY "groups_insert" ON groups
  FOR INSERT WITH CHECK (
    auth.uid() = creator_id
    AND EXISTS (SELECT 1 FROM room_members rm WHERE rm.room_id = room_id AND rm.user_id = auth.uid())
  );

CREATE POLICY "groups_update" ON groups
  FOR UPDATE USING (auth.uid() = creator_id);

-- group_members: approved members can see each other; pending only visible to self and creator
CREATE POLICY "group_members_select" ON group_members
  FOR SELECT USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups g
      WHERE g.id = group_id
        AND (
          g.creator_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM group_members gm2
            WHERE gm2.group_id = g.id
              AND gm2.user_id = auth.uid()
              AND gm2.status = 'approved'
          )
        )
    )
  );

CREATE POLICY "group_members_insert" ON group_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "group_members_update" ON group_members
  FOR UPDATE USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups g WHERE g.id = group_id AND g.creator_id = auth.uid()
    )
  );

CREATE POLICY "group_members_delete" ON group_members
  FOR DELETE USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM groups g WHERE g.id = group_id AND g.creator_id = auth.uid()
    )
  );

-- messages: readable if member of the room or group
CREATE POLICY "messages_select" ON messages
  FOR SELECT USING (
    is_deleted = false
    AND (
      (room_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM room_members rm WHERE rm.room_id = messages.room_id AND rm.user_id = auth.uid()
      ))
      OR
      (group_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM group_members gm WHERE gm.group_id = messages.group_id AND gm.user_id = auth.uid() AND gm.status = 'approved'
      ))
    )
  );

CREATE POLICY "messages_insert" ON messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND (
      (room_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM room_members rm WHERE rm.room_id = messages.room_id AND rm.user_id = auth.uid()
      ))
      OR
      (group_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM group_members gm WHERE gm.group_id = messages.group_id AND gm.user_id = auth.uid() AND gm.status = 'approved'
      ))
    )
  );

-- reports: reporters can insert, only see own reports
CREATE POLICY "reports_insert" ON reports
  FOR INSERT WITH CHECK (auth.uid() = reporter_id);

CREATE POLICY "reports_select" ON reports
  FOR SELECT USING (auth.uid() = reporter_id);

-- blocks: fully private to the blocker
CREATE POLICY "blocks_select" ON blocks
  FOR SELECT USING (auth.uid() = blocker_id);

CREATE POLICY "blocks_insert" ON blocks
  FOR INSERT WITH CHECK (auth.uid() = blocker_id);

CREATE POLICY "blocks_delete" ON blocks
  FOR DELETE USING (auth.uid() = blocker_id);

-- verifications: owner only (document_url protected from others)
CREATE POLICY "verifications_select" ON verifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "verifications_insert" ON verifications
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ── Realtime publication ──────────────────────────────────────────────────────

-- Add messages table to the supabase_realtime publication for live chat
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE group_members;
