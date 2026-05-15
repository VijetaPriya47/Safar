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
-- SafarKnots seed data — generated 2026-05-16T09:58:23.483Z
-- 100 users · 20 rooms · 29 groups · 622 messages

-- ── Users ──────────────────────────────────────────────────────────────
INSERT INTO public.users (id,email,name,google_id,avatar_url,bio,gender,college_name,college_verified,pnr_verified) VALUES
('3e1f24fe-b192-4b2b-8272-4cc3f5c14d37','arjun.sharma17@example.com','Arjun Sharma','google_mock_484fc6ad198e4995abb08f22fc51ba97','https://api.dicebear.com/7.x/avataaars/svg?seed=Arjun%20Sharma','From Delhi. IIT Bombay grad.','male','IIT Bombay',true,true),
('a25875b0-b6f7-4bed-8424-c5eac04a8691','rohan.verma47@example.com','Rohan Verma','google_mock_a895e18ba36f404bb8f2f41cfc3f85ad','https://api.dicebear.com/7.x/avataaars/svg?seed=Rohan%20Verma','NIT Surathkal | Chemical | Batch 2025','male','NIT Surathkal',false,false),
('fa7f925a-d508-4c83-93f0-d7d43c39b7b5','karan.singh95@example.com','Karan Singh','google_mock_055f9e67d9fc47cc9808bd8ebb25985e','https://api.dicebear.com/7.x/avataaars/svg?seed=Karan%20Singh','NIT Warangal | ME | Batch 2022','male','NIT Warangal',false,false),
('f8cce76e-7552-4d2b-bd11-af60602755d9','amit.patel36@example.com','Amit Patel','google_mock_cd401699540b4c79a3480dd4bae9c0ba','https://api.dicebear.com/7.x/avataaars/svg?seed=Amit%20Patel','Final year at Osmania University. Always up for a good trip.','male','Osmania University',false,true),
('4ddbcbb8-2be7-4a7d-a880-545cc2975bbc','rahul.gupta38@example.com','Rahul Gupta','google_mock_18319165ff6840e0b600a608a889c4b9','https://api.dicebear.com/7.x/avataaars/svg?seed=Rahul%20Gupta',NULL,'male','IIIT Delhi',false,false),
('2b779edc-8e5e-40e9-859e-2e1cd1dde32a','vikram.nair33@example.com','Vikram Nair','google_mock_29ca0aa18c5d410095711e7e8d0b44d8','https://api.dicebear.com/7.x/avataaars/svg?seed=Vikram%20Nair','Final year at LPU Punjab. Always up for a good trip.','male','LPU Punjab',false,false),
('f994f2cc-f321-49fe-8d75-3b7982d875d0','siddharth.joshi19@example.com','Siddharth Joshi','google_mock_a252b25b12cf4e5c84df38df018e4d17','https://api.dicebear.com/7.x/avataaars/svg?seed=Siddharth%20Joshi','NIT Warangal | ME | Batch 2022','male','NIT Warangal',true,true),
('3eaf7eed-95d3-4881-933f-3d1c82fca8ff','aditya.kumar29@example.com','Aditya Kumar','google_mock_79b21b80169148bd99deed5aad86348b','https://api.dicebear.com/7.x/avataaars/svg?seed=Aditya%20Kumar','From Delhi. NIT Trichy grad.','male','NIT Trichy',false,true),
('f462e61a-1e7f-48e6-919d-5b596e3ed0d6','pranav.mishra61@example.com','Pranav Mishra','google_mock_d7b8eb9607e248719aba0f38c22fc1ff','https://api.dicebear.com/7.x/avataaars/svg?seed=Pranav%20Mishra','Final year at IIT Madras. Always up for a good trip.','male','IIT Madras',true,true),
('a77f8394-6c66-4d6d-a16b-5013cfd88385','ishaan.tiwari64@example.com','Ishaan Tiwari','google_mock_66db4158949c41fa864cfc29c5ba29b9','https://api.dicebear.com/7.x/avataaars/svg?seed=Ishaan%20Tiwari',NULL,'male','IIT Bombay',false,false),
('ee82a7e1-8708-4359-9763-095bde24e848','ayush.rao91@example.com','Ayush Rao','google_mock_2a88f91434b94d749b288af265f7fb52','https://api.dicebear.com/7.x/avataaars/svg?seed=Ayush%20Rao','BITS Hyderabad student, love traveling!','male','BITS Hyderabad',false,true),
('7ea642d5-8df7-4ae1-a624-5daa8af23a34','divyansh.chauhan32@example.com','Divyansh Chauhan','google_mock_3bf6e7119a694743b4bf70bc649b9729','https://api.dicebear.com/7.x/avataaars/svg?seed=Divyansh%20Chauhan','IIT Kanpur student, love traveling!','male','IIT Kanpur',true,true),
('83b12a8b-8a08-4e95-af91-78cc1032cff1','harsh.agarwal81@example.com','Harsh Agarwal','google_mock_043064fce0594a3795ce11c7919a70b2','https://api.dicebear.com/7.x/avataaars/svg?seed=Harsh%20Agarwal','Final year at BITS Hyderabad. Always up for a good trip.','male','BITS Hyderabad',true,false),
('50176064-54ea-44ae-89f7-b378fda2df85','nikhil.mehta14@example.com','Nikhil Mehta','google_mock_01404d73784145c48849c4775a157825','https://api.dicebear.com/7.x/avataaars/svg?seed=Nikhil%20Mehta','Final year at Pune University. Always up for a good trip.','male','Pune University',false,false),
('8988ce23-8368-4981-9d43-27369de4a5f8','shubham.pandey50@example.com','Shubham Pandey','google_mock_ea8c3fa590194e61b82b951cd5503581','https://api.dicebear.com/7.x/avataaars/svg?seed=Shubham%20Pandey','From Bangalore. IIT Bombay grad.','male','IIT Bombay',false,false),
('d66070b8-f157-4df9-82e0-ff9aa4d67252','aarav.srivastava55@example.com','Aarav Srivastava','google_mock_1f9b507e03014faeacb24737411205b4','https://api.dicebear.com/7.x/avataaars/svg?seed=Aarav%20Srivastava','From Delhi. Delhi University grad.','male','Delhi University',false,false),
('d9b37982-f6b2-4b30-b48e-bdd24b288731','varun.kapoor57@example.com','Varun Kapoor','google_mock_957a808bb3c84a4f8edab601f95f1168','https://api.dicebear.com/7.x/avataaars/svg?seed=Varun%20Kapoor',NULL,'male','NIT Surathkal',false,false),
('8ede2d73-0ca1-4412-8704-0a0144d56dc6','yash.bhatia99@example.com','Yash Bhatia','google_mock_c2eafe50ac79434cbd1aecf9ba3be349','https://api.dicebear.com/7.x/avataaars/svg?seed=Yash%20Bhatia','Final year at BITS Hyderabad. Always up for a good trip.','male','BITS Hyderabad',false,false),
('f5884ea3-0f91-4a69-98b6-40d11702a6bd','dev.saxena82@example.com','Dev Saxena','google_mock_b0dca078855042818657f0ddf2186f8f','https://api.dicebear.com/7.x/avataaars/svg?seed=Dev%20Saxena','NIT Trichy | Civil | Batch 2023','male','NIT Trichy',false,true),
('0adaf0ce-abec-421d-bb57-037f7b332e1d','kunal.malhotra60@example.com','Kunal Malhotra','google_mock_23763d4d05c44d65a6479ab2f5c78938','https://api.dicebear.com/7.x/avataaars/svg?seed=Kunal%20Malhotra','IIT Delhi student, love traveling!','male','IIT Delhi',false,true),
('6fcce34a-52e2-4bf7-b1cd-143821d54bc3','tushar.reddy94@example.com','Tushar Reddy','google_mock_837dc5e47be54fea9531096b39f739c1','https://api.dicebear.com/7.x/avataaars/svg?seed=Tushar%20Reddy','Final year at Thapar University. Always up for a good trip.','male','Thapar University',true,true),
('2780e8f1-3f06-4674-9215-3cd2bad13c03','akash.dubey81@example.com','Akash Dubey','google_mock_4136a0de0d2d4198809cb4c1af2b79fe','https://api.dicebear.com/7.x/avataaars/svg?seed=Akash%20Dubey','Final year at Delhi University. Always up for a good trip.','male','Delhi University',false,false),
('13cbbc82-15fc-4d8e-9da1-5d3301ec9466','gaurav.tripathi65@example.com','Gaurav Tripathi','google_mock_d8d2591f08bb4ee79ee910faeac317e9','https://api.dicebear.com/7.x/avataaars/svg?seed=Gaurav%20Tripathi','From Bangalore. Anna University grad.','male','Anna University',false,false),
('40b935b5-0ffc-407e-bc76-af36d8053bc2','mohit.bansal11@example.com','Mohit Bansal','google_mock_fe748d54d46444548f3c96ccf5a3a6f4','https://api.dicebear.com/7.x/avataaars/svg?seed=Mohit%20Bansal','From Hyderabad. Anna University grad.','male','Anna University',true,true),
('0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','ritesh.yadav51@example.com','Ritesh Yadav','google_mock_138af097ebf242f9a3ab78fa177b12b6','https://api.dicebear.com/7.x/avataaars/svg?seed=Ritesh%20Yadav',NULL,'male','NIT Surathkal',true,true),
('f8164cc9-a372-45bf-b6f4-d1a5ad115c82','suraj.jain47@example.com','Suraj Jain','google_mock_762a42a14a9f4b9ab74c96ed9a2d12a1','https://api.dicebear.com/7.x/avataaars/svg?seed=Suraj%20Jain','IIIT Delhi | CSE | Batch 2026','male','IIIT Delhi',false,false),
('66e43919-33bb-4434-999f-22a3086cb7f4','ankit.bhatt16@example.com','Ankit Bhatt','google_mock_68ae493ea4804374ae161efce57ebfa0','https://api.dicebear.com/7.x/avataaars/svg?seed=Ankit%20Bhatt','NIT Surathkal student, love traveling!','male','NIT Surathkal',true,true),
('95ff91b3-6c6a-41d7-ac38-471ac85422da','abhishek.chaudhary39@example.com','Abhishek Chaudhary','google_mock_98f309fc04ee4488bcf2a92b97880ffb','https://api.dicebear.com/7.x/avataaars/svg?seed=Abhishek%20Chaudhary','BITS Hyderabad student, love traveling!','male','BITS Hyderabad',true,false),
('599561ff-7b0e-4659-9b96-eedcd5842f34','deepak.rawat13@example.com','Deepak Rawat','google_mock_4a112308a8e247a8bc34f7b80f94fe23','https://api.dicebear.com/7.x/avataaars/svg?seed=Deepak%20Rawat','BITS Hyderabad | Civil | Batch 2022','male','BITS Hyderabad',false,true),
('73e3a251-b873-433b-9ebf-ba9b9c3b712d','lokesh.patil44@example.com','Lokesh Patil','google_mock_9362816028044462ab7895c3b33bf2ac','https://api.dicebear.com/7.x/avataaars/svg?seed=Lokesh%20Patil','From Mumbai. IIT Madras grad.','male','IIT Madras',false,false),
('656130ae-d5e3-46f8-aa53-21bcc35c28a8','manish.garg66@example.com','Manish Garg','google_mock_73984dd30c974f5f92e45cc9c2d5fddb','https://api.dicebear.com/7.x/avataaars/svg?seed=Manish%20Garg','Manipal University | Chemical | Batch 2022','male','Manipal University',false,false),
('cf6c3a10-8460-4f52-8ee2-7a029042c5d7','naveen.pillai50@example.com','Naveen Pillai','google_mock_7bbd754ea6b14491b56aea11ec3cc88d','https://api.dicebear.com/7.x/avataaars/svg?seed=Naveen%20Pillai','From Kolkata. Osmania University grad.','male','Osmania University',false,false),
('fadcce80-f0d7-4031-8233-fb8fc9e34e0f','omkar.desai88@example.com','Omkar Desai','google_mock_28c1df2211d34f52a5dd0992ed9948eb','https://api.dicebear.com/7.x/avataaars/svg?seed=Omkar%20Desai','Mumbai University | ME | Batch 2023','male','Mumbai University',false,false),
('a8dc8480-38ba-4e2c-879d-61e888626bf3','parth.thakur20@example.com','Parth Thakur','google_mock_b0fd53960e6c47e0a98fac12c0a1b998','https://api.dicebear.com/7.x/avataaars/svg?seed=Parth%20Thakur','IIT Kanpur student, love traveling!','male','IIT Kanpur',true,false),
('ea7cb6f3-8697-4cdc-9b14-2132a630b8c2','rajat.kashyap99@example.com','Rajat Kashyap','google_mock_5b04bc1a62924a34aef42d2869783d07','https://api.dicebear.com/7.x/avataaars/svg?seed=Rajat%20Kashyap','SRM Chennai student, love traveling!','male','SRM Chennai',true,false),
('f3883e6b-8190-42eb-b94b-84c6dad5e909','sachin.goyal16@example.com','Sachin Goyal','google_mock_88d8eeed7c03429db49aa653e4ee71d6','https://api.dicebear.com/7.x/avataaars/svg?seed=Sachin%20Goyal','Final year at Manipal University. Always up for a good trip.','male','Manipal University',true,false),
('0e52e760-d927-49d5-b3f7-568970536394','tanmay.shah9@example.com','Tanmay Shah','google_mock_1a9ab015163047b0976cb954b8680615','https://api.dicebear.com/7.x/avataaars/svg?seed=Tanmay%20Shah','From Bangalore. IIT Kharagpur grad.','male','IIT Kharagpur',false,true),
('c21a9c50-33b1-4700-a705-778fc04434f5','ujjwal.dixit7@example.com','Ujjwal Dixit','google_mock_901af382c2e741d59cabed6937cb7e64','https://api.dicebear.com/7.x/avataaars/svg?seed=Ujjwal%20Dixit','From Hyderabad. IIIT Hyderabad grad.','male','IIIT Hyderabad',true,false),
('2f6e2744-67bd-49f0-b2a6-dc104146a963','vinay.murthy53@example.com','Vinay Murthy','google_mock_12faddde14a14e448f07eacacff2822c','https://api.dicebear.com/7.x/avataaars/svg?seed=Vinay%20Murthy','Delhi University student, love traveling!','male','Delhi University',true,false),
('f798196b-807b-48df-a7c7-16961e01b088','zaid.khan2@example.com','Zaid Khan','google_mock_24b10ac68cd04950b00244b348b252b9','https://api.dicebear.com/7.x/avataaars/svg?seed=Zaid%20Khan',NULL,'male','IIT Madras',false,false),
('7508a61b-7926-4b0b-9741-92bdf0a5b801','aryan.bose53@example.com','Aryan Bose','google_mock_f66a978473a440f9a46a2e5ee3163c1e','https://api.dicebear.com/7.x/avataaars/svg?seed=Aryan%20Bose',NULL,'male','Mumbai University',false,false),
('2a397b4f-1650-428d-806e-a9c929655ca1','chirag.menon63@example.com','Chirag Menon','google_mock_2575ebaa5ff34be595fd0e7c9369522e','https://api.dicebear.com/7.x/avataaars/svg?seed=Chirag%20Menon',NULL,'male','NIT Surathkal',false,true),
('53f4a2aa-025f-4886-b165-363912f8e678','dhruv.khanna57@example.com','Dhruv Khanna','google_mock_66d5e9bedd4246b99cafc3e5ae4d0752','https://api.dicebear.com/7.x/avataaars/svg?seed=Dhruv%20Khanna','From Delhi. VIT Vellore grad.','male','VIT Vellore',true,false),
('d9757067-5e1b-41f2-8343-fe980c4bd506','farhan.siddiqui39@example.com','Farhan Siddiqui','google_mock_c5d3194db8ea4d7597b5a22a0039002a','https://api.dicebear.com/7.x/avataaars/svg?seed=Farhan%20Siddiqui','From Delhi. Osmania University grad.','male','Osmania University',false,true),
('f40d0980-d059-4c82-ad90-a1e19b1adf33','girish.iyer87@example.com','Girish Iyer','google_mock_efa6b92805244413b0853d4b298a409c','https://api.dicebear.com/7.x/avataaars/svg?seed=Girish%20Iyer','From Hyderabad. Osmania University grad.','male','Osmania University',false,false),
('7c0dc257-7e74-4bd8-a9ea-4d8ec8391be8','himanshu.tomar77@example.com','Himanshu Tomar','google_mock_aea126aad652441fb352ff5d35bdd004','https://api.dicebear.com/7.x/avataaars/svg?seed=Himanshu%20Tomar','From Kolkata. Pune University grad.','male','Pune University',true,true),
('4e28df34-c6c3-4b37-9449-74893ca8dfae','jai.rathore88@example.com','Jai Rathore','google_mock_c161d4f65b6b42558d456ba375c40856','https://api.dicebear.com/7.x/avataaars/svg?seed=Jai%20Rathore',NULL,'male','Thapar University',true,false),
('9b70939f-08cc-4e07-80cb-06b8a7584ddf','karthik.subramaniam11@example.com','Karthik Subramaniam','google_mock_f03ced00fbcb4d9ca87adcd256e343a4','https://api.dicebear.com/7.x/avataaars/svg?seed=Karthik%20Subramaniam','From Mumbai. IIIT Hyderabad grad.','male','IIIT Hyderabad',true,false),
('5c1b5a20-6f22-431a-a2ba-016f5d112e49','lalit.shekhawat59@example.com','Lalit Shekhawat','google_mock_1e7220978d604476a4e972e9bb2b5e71','https://api.dicebear.com/7.x/avataaars/svg?seed=Lalit%20Shekhawat','BHU Varanasi student, love traveling!','male','BHU Varanasi',false,false),
('b255e0d1-47f5-47e2-b7fa-3682b9c70ef5','madhav.jha7@example.com','Madhav Jha','google_mock_6d11c89b8a604cd79c38778f7b7d6366','https://api.dicebear.com/7.x/avataaars/svg?seed=Madhav%20Jha','BITS Hyderabad | ECE | Batch 2023','male','BITS Hyderabad',false,false),
('9a994052-6788-48cc-9240-6a26c8d32c35','nakul.oberoi92@example.com','Nakul Oberoi','google_mock_e2c8ed60e674458286d48dfd7d738266','https://api.dicebear.com/7.x/avataaars/svg?seed=Nakul%20Oberoi','From Bangalore. AMU Aligarh grad.','male','AMU Aligarh',false,true),
('ee99aa6b-48e7-4074-a4ba-fb16d76249d1','omkar.kulkarni58@example.com','Omkar Kulkarni','google_mock_d1d6c7fe1d25416aac4dbb90537749db','https://api.dicebear.com/7.x/avataaars/svg?seed=Omkar%20Kulkarni','IIT Bombay | Civil | Batch 2021','male','IIT Bombay',true,true),
('323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','piyush.agarwal93@example.com','Piyush Agarwal','google_mock_7eefbd654ae045ba92c294fd0511bc32','https://api.dicebear.com/7.x/avataaars/svg?seed=Piyush%20Agarwal','Final year at IIT Kharagpur. Always up for a good trip.','male','IIT Kharagpur',false,false),
('25ce2843-8039-420c-bf21-cd436c59195d','qasim.ali87@example.com','Qasim Ali','google_mock_5f04306d59a545039b490a5e1a27e25e','https://api.dicebear.com/7.x/avataaars/svg?seed=Qasim%20Ali','Final year at BHU Varanasi. Always up for a good trip.','male','BHU Varanasi',true,true),
('f88cf7f0-e103-4db9-897c-f70b5544e51f','rakesh.yadav98@example.com','Rakesh Yadav','google_mock_03991ca103294a07b904be77502bcaac','https://api.dicebear.com/7.x/avataaars/svg?seed=Rakesh%20Yadav','From Mumbai. BITS Hyderabad grad.','male','BITS Hyderabad',false,true),
('b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','saurabh.bhardwaj39@example.com','Saurabh Bhardwaj','google_mock_3c5b0082c33f4b069903110e9ee26724','https://api.dicebear.com/7.x/avataaars/svg?seed=Saurabh%20Bhardwaj',NULL,'male','IIT Delhi',false,false),
('f91fbdcd-2c3b-4ad6-b653-3e323af41f79','tarun.luthra39@example.com','Tarun Luthra','google_mock_18208abe1bb44f018069f72438ab66a6','https://api.dicebear.com/7.x/avataaars/svg?seed=Tarun%20Luthra','Final year at Anna University. Always up for a good trip.','male','Anna University',false,false),
('424c8082-c736-4860-9e90-24be1565854e','uday.pal76@example.com','Uday Pal','google_mock_40616409a56f448c966d723335c6e233','https://api.dicebear.com/7.x/avataaars/svg?seed=Uday%20Pal','NIT Warangal student, love traveling!','male','NIT Warangal',true,false),
('02ccdcd8-e45a-435d-bc04-86f2bb129992','vivek.anand37@example.com','Vivek Anand','google_mock_0ae135a0c0f8498a806d41e888babac5','https://api.dicebear.com/7.x/avataaars/svg?seed=Vivek%20Anand',NULL,'male','Mumbai University',false,false),
('637e185c-f1fe-4afe-af7f-b7b7e9b60edc','waqar.hussain8@example.com','Waqar Hussain','google_mock_a6934dc418504cd4a0ec95776199bcb3','https://api.dicebear.com/7.x/avataaars/svg?seed=Waqar%20Hussain','From Bangalore. BITS Pilani grad.','male','BITS Pilani',false,false),
('eb2d91e8-f6ed-45da-a4ba-63e5765c05fe','priya.sharma83@example.com','Priya Sharma','google_mock_d12f4155b7d44db996fc5ab6c18838bb','https://api.dicebear.com/7.x/avataaars/svg?seed=Priya%20Sharma','Anna University | Civil | Batch 2020','female','Anna University',false,true),
('e6dc2b9c-600e-455a-a943-7eb328f05212','ananya.singh64@example.com','Ananya Singh','google_mock_cf06f6bd8a8b422abb86d420e65a796e','https://api.dicebear.com/7.x/avataaars/svg?seed=Ananya%20Singh','IIT Kanpur | ME | Batch 2021','female','IIT Kanpur',true,false),
('575e3b18-220a-4b1b-975e-fbdaebcb3f92','neha.verma25@example.com','Neha Verma','google_mock_f51b8fa204a742eb9fa85baf729f5497','https://api.dicebear.com/7.x/avataaars/svg?seed=Neha%20Verma',NULL,'female','AMU Aligarh',false,true),
('660fb29d-479e-40f5-95a2-81f045db5c69','shreya.patel9@example.com','Shreya Patel','google_mock_3d680796b1fd439db18a26f72fc5faee','https://api.dicebear.com/7.x/avataaars/svg?seed=Shreya%20Patel',NULL,'female','AMU Aligarh',false,false),
('96252279-a167-4d8b-8a55-8e35699a01c0','pooja.gupta28@example.com','Pooja Gupta','google_mock_4126cb00926a44f183e5345b73f0124e','https://api.dicebear.com/7.x/avataaars/svg?seed=Pooja%20Gupta','From Hyderabad. IIIT Hyderabad grad.','female','IIIT Hyderabad',false,true),
('49db741c-b8a0-46b0-9ba2-37fdc8b9ef96','aarohi.nair18@example.com','Aarohi Nair','google_mock_ab7381d3874f4db8865f14328f01c818','https://api.dicebear.com/7.x/avataaars/svg?seed=Aarohi%20Nair','Osmania University student, love traveling!','female','Osmania University',false,false),
('bc44693f-6524-49c9-a6d8-06a3ca4d61d8','diya.joshi92@example.com','Diya Joshi','google_mock_75d731ecd9144e82804b0d5c280d4dfe','https://api.dicebear.com/7.x/avataaars/svg?seed=Diya%20Joshi','From Delhi. Thapar University grad.','female','Thapar University',false,true),
('287cffed-71ac-4b66-8552-4aadd6cbf3dc','ishita.kumar98@example.com','Ishita Kumar','google_mock_2e2712dd540c4719882fd73f7efcfb33','https://api.dicebear.com/7.x/avataaars/svg?seed=Ishita%20Kumar','LPU Punjab student, love traveling!','female','LPU Punjab',false,false),
('72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','kavya.mishra13@example.com','Kavya Mishra','google_mock_014770cd40264e4c9a31b6a79c654024','https://api.dicebear.com/7.x/avataaars/svg?seed=Kavya%20Mishra','From Mumbai. IIT Madras grad.','female','IIT Madras',true,true),
('a484a03b-1cb9-4790-835b-64245238bcda','lakshmi.tiwari21@example.com','Lakshmi Tiwari','google_mock_fa7f560d46184d5281c0817403d36267','https://api.dicebear.com/7.x/avataaars/svg?seed=Lakshmi%20Tiwari','IIIT Delhi student, love traveling!','female','IIIT Delhi',false,false),
('97b03499-1962-4087-b478-48102f464a91','meera.rao51@example.com','Meera Rao','google_mock_fa3091a4ad5c45cf848b1b14c12fccf0','https://api.dicebear.com/7.x/avataaars/svg?seed=Meera%20Rao','From Delhi. NIT Warangal grad.','female','NIT Warangal',true,false),
('73250fab-0868-4148-a348-e1654293fbab','nandini.chauhan54@example.com','Nandini Chauhan','google_mock_459aaf026c444e5aba34962fb37c0a37','https://api.dicebear.com/7.x/avataaars/svg?seed=Nandini%20Chauhan','From Mumbai. AMU Aligarh grad.','female','AMU Aligarh',true,true),
('7a348d56-91d8-4610-959b-0fc29c14686e','pallavi.agarwal65@example.com','Pallavi Agarwal','google_mock_1490210e2330432298afa0d50fcda2a7','https://api.dicebear.com/7.x/avataaars/svg?seed=Pallavi%20Agarwal','Jadavpur University | Chemical | Batch 2025','female','Jadavpur University',false,true),
('8f1072d4-86dd-40b5-8521-0db5b9f305a2','riya.mehta61@example.com','Riya Mehta','google_mock_746e7d740c4143d0b96994ff730ad794','https://api.dicebear.com/7.x/avataaars/svg?seed=Riya%20Mehta',NULL,'female','NIT Trichy',false,true),
('380997d4-59cd-41f2-9f95-a97b1a65c25b','sneha.pandey54@example.com','Sneha Pandey','google_mock_82f19dae604448429b98cdcb63d6f073','https://api.dicebear.com/7.x/avataaars/svg?seed=Sneha%20Pandey','Delhi University | ME | Batch 2026','female','Delhi University',true,true),
('0412662f-98b9-4fda-a1b4-4173f2c27ad4','tanvi.srivastava44@example.com','Tanvi Srivastava','google_mock_8d9f46fdbda44df99bc64028b2da96c5','https://api.dicebear.com/7.x/avataaars/svg?seed=Tanvi%20Srivastava',NULL,'female','IIIT Delhi',true,true),
('c6cac135-7583-4250-a794-189b972b8fc9','uma.kapoor53@example.com','Uma Kapoor','google_mock_0a6348b0eeb04fffaeaf88e59ced93f9','https://api.dicebear.com/7.x/avataaars/svg?seed=Uma%20Kapoor','Final year at NIT Surathkal. Always up for a good trip.','female','NIT Surathkal',false,true),
('be8c4d41-4490-481c-a7f9-6cb6f65d9866','vidhi.bhatia67@example.com','Vidhi Bhatia','google_mock_e46198e93d844f67932965de4aade886','https://api.dicebear.com/7.x/avataaars/svg?seed=Vidhi%20Bhatia','From Bangalore. Mumbai University grad.','female','Mumbai University',false,true),
('9340edc8-05a5-4c4a-8c73-2a35ad4bfec6','swati.saxena58@example.com','Swati Saxena','google_mock_97d233d61b6044cf8f400c03eff44f1e','https://api.dicebear.com/7.x/avataaars/svg?seed=Swati%20Saxena',NULL,'female','AMU Aligarh',true,true),
('955b7867-3dfe-4a2a-91ce-600feb668284','aditi.malhotra50@example.com','Aditi Malhotra','google_mock_28329943fb95473eaba05d5bb1fc786f','https://api.dicebear.com/7.x/avataaars/svg?seed=Aditi%20Malhotra','AMU Aligarh | CSE | Batch 2021','female','AMU Aligarh',true,false),
('d98aa471-cb45-4263-936f-87b6a955f196','bhavna.reddy29@example.com','Bhavna Reddy','google_mock_74ef29bbe4cd47a29ba097d5f8003491','https://api.dicebear.com/7.x/avataaars/svg?seed=Bhavna%20Reddy','Delhi University | Chemical | Batch 2022','female','Delhi University',false,true),
('0863b4e8-e752-4c04-837e-419f091fe3dd','charu.dubey62@example.com','Charu Dubey','google_mock_66c2d93e113f46b1a33b90564cafb59f','https://api.dicebear.com/7.x/avataaars/svg?seed=Charu%20Dubey','Osmania University student, love traveling!','female','Osmania University',true,true),
('43eaa843-55b6-44b9-943a-f28e2f552f1f','dipika.tripathi26@example.com','Dipika Tripathi','google_mock_f6c66640490345bbba7c54138dc7a17f','https://api.dicebear.com/7.x/avataaars/svg?seed=Dipika%20Tripathi','Final year at BHU Varanasi. Always up for a good trip.','female','BHU Varanasi',false,true),
('4d0a152e-ea34-4f15-a703-309516ee6b4d','esha.bansal34@example.com','Esha Bansal','google_mock_08c1f48c4a9d453fa3524884ad83c83d','https://api.dicebear.com/7.x/avataaars/svg?seed=Esha%20Bansal','IIT Madras | ECE | Batch 2021','female','IIT Madras',true,true),
('6a3f8cad-ce91-4c37-985c-2c2a2a6f5851','fatima.khan71@example.com','Fatima Khan','google_mock_75f2fb470b534598ab6513489493e11c','https://api.dicebear.com/7.x/avataaars/svg?seed=Fatima%20Khan','Final year at Delhi University. Always up for a good trip.','female','Delhi University',true,false),
('ee94d5e1-b558-4c66-bc3e-7d603dfb21e1','garima.yadav36@example.com','Garima Yadav','google_mock_4c5711622b3944a1b72d9d40dfb821fb','https://api.dicebear.com/7.x/avataaars/svg?seed=Garima%20Yadav','From Mumbai. IIT Kharagpur grad.','female','IIT Kharagpur',false,true),
('bfa15c31-e6cb-4704-a3fe-ecb67862c1ed','harshi.jain23@example.com','Harshi Jain','google_mock_56e1e8d7526c4cd192b004f4edbb8cb9','https://api.dicebear.com/7.x/avataaars/svg?seed=Harshi%20Jain','Delhi University | Civil | Batch 2023','female','Delhi University',false,false),
('b6ac128c-ca95-438e-b6e5-e1b850f78352','isha.bhatt64@example.com','Isha Bhatt','google_mock_b9053de31b9249a5ad7821e01afeab16','https://api.dicebear.com/7.x/avataaars/svg?seed=Isha%20Bhatt',NULL,'female','Anna University',true,false),
('8645c745-a0a1-4ea7-89ff-ca7cd6a9074f','jaya.chaudhary96@example.com','Jaya Chaudhary','google_mock_9b01a282edd647ba95b1d0ed92c330f2','https://api.dicebear.com/7.x/avataaars/svg?seed=Jaya%20Chaudhary',NULL,'female','Jadavpur University',true,true),
('a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','komal.rawat2@example.com','Komal Rawat','google_mock_abd3b34f4b4845b4a28c3bfb82bb405b','https://api.dicebear.com/7.x/avataaars/svg?seed=Komal%20Rawat','From Kolkata. IIT Kharagpur grad.','female','IIT Kharagpur',true,true),
('63a974f3-6530-40b4-892f-1a620b38563e','lavanya.menon2@example.com','Lavanya Menon','google_mock_8cb2d346eeb141a0933c8825e9d8f3f1','https://api.dicebear.com/7.x/avataaars/svg?seed=Lavanya%20Menon',NULL,'female','IIT Delhi',false,true),
('2daa15f6-74b4-4c83-9153-edb6c92317e8','mansi.oberoi32@example.com','Mansi Oberoi','google_mock_b11ff8c8c6a94fec80fbe6807cababdd','https://api.dicebear.com/7.x/avataaars/svg?seed=Mansi%20Oberoi',NULL,'female','IIT Kharagpur',true,true),
('f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','nisha.kulkarni72@example.com','Nisha Kulkarni','google_mock_e0e4508aedf343489df8f889196c659c','https://api.dicebear.com/7.x/avataaars/svg?seed=Nisha%20Kulkarni','Final year at BHU Varanasi. Always up for a good trip.','female','BHU Varanasi',true,true),
('dd32fda6-6a98-4538-a5c5-c21092fd78e4','ojasvi.pandey97@example.com','Ojasvi Pandey','google_mock_0ff53be79f8448a5b69ef8a909e3182f','https://api.dicebear.com/7.x/avataaars/svg?seed=Ojasvi%20Pandey','NIT Surathkal student, love traveling!','female','NIT Surathkal',true,true),
('6125af0e-06f0-464b-b752-bbbe0d5b6b27','payal.jha4@example.com','Payal Jha','google_mock_e4555d89145c49c0b5907443786b735c','https://api.dicebear.com/7.x/avataaars/svg?seed=Payal%20Jha','Final year at IIT Bombay. Always up for a good trip.','female','IIT Bombay',true,true),
('f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','ritika.bose66@example.com','Ritika Bose','google_mock_120d75f49c6944bf87175f93ab0fc396','https://api.dicebear.com/7.x/avataaars/svg?seed=Ritika%20Bose',NULL,'female','SRM Chennai',true,true),
('e7a41005-3e6d-434f-bd4d-b38fcaf970d1','shalini.khanna40@example.com','Shalini Khanna','google_mock_e09454ba95f34cd79a08316f9d72c76e','https://api.dicebear.com/7.x/avataaars/svg?seed=Shalini%20Khanna','Final year at NIT Surathkal. Always up for a good trip.','female','NIT Surathkal',true,false),
('4f270acd-505b-44ce-86ba-538743a770e5','trisha.iyer43@example.com','Trisha Iyer','google_mock_815ae65944424e54aa6aa6852598efd1','https://api.dicebear.com/7.x/avataaars/svg?seed=Trisha%20Iyer','Manipal University | ECE | Batch 2026','female','Manipal University',false,true),
('d0ff8ce3-8f3a-4afb-b2c7-c28b13651a84','urvi.soni44@example.com','Urvi Soni','google_mock_4743599211724842b34c17e32ef899ab','https://api.dicebear.com/7.x/avataaars/svg?seed=Urvi%20Soni','From Hyderabad. IIT Delhi grad.','female','IIT Delhi',true,true),
('5a1be9c2-63af-4f6e-af20-9231c845ce53','vandana.mishra27@example.com','Vandana Mishra','google_mock_d15c2f3e6d3b4d87aa1170af768919f1','https://api.dicebear.com/7.x/avataaars/svg?seed=Vandana%20Mishra','Final year at NIT Warangal. Always up for a good trip.','female','NIT Warangal',true,true);

-- ── Rooms ──────────────────────────────────────────────────────────────
INSERT INTO public.rooms (id,room_key,room_type,identifier,source,destination,journey_date,member_count) VALUES
('564ec993-187e-4aef-9acd-8adbd6836cad','train_12301_2026-05-29','train','12301','New Delhi','Howrah','2026-05-29',8),
('0044eb37-07f3-4329-afc0-e0142cd1e716','train_12302_2026-06-14','train','12302','Howrah','New Delhi','2026-06-14',4),
('bdcf88d5-4c97-49d1-a3e4-17ca7362bea7','train_12951_2026-05-24','train','12951','New Delhi','Mumbai Central','2026-05-24',7),
('9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137','train_12952_2026-05-17','train','12952','Mumbai Central','New Delhi','2026-05-17',3),
('cab0c412-cd35-4876-8333-27cf971b1036','train_12627_2026-05-25','train','12627','New Delhi','Bengaluru','2026-05-25',3),
('29f22b79-ca71-4a72-a011-29f4fd992705','train_12628_2026-05-31','train','12628','Bengaluru','New Delhi','2026-05-31',5),
('2a5ff177-4154-4a27-ae0c-d7828e141029','train_12505_2026-06-13','train','12505','New Delhi','Guwahati','2026-06-13',3),
('17061f6f-be50-44a0-af22-debf59b246b4','train_12506_2026-06-08','train','12506','Guwahati','New Delhi','2026-06-08',5),
('3658226f-91db-4ae4-b9d7-20b9d367ce58','train_22691_2026-06-04','train','22691','New Delhi','Bengaluru','2026-06-04',5),
('1e91aa35-5420-4017-a29d-9bff0b89f8e9','train_12259_2026-05-20','train','12259','New Delhi','Kolkata','2026-05-20',8),
('9a11861f-0b94-4ec8-82f5-b35d2e1823a1','train_12030_2026-05-27','train','12030','Amritsar','New Delhi','2026-05-27',4),
('13d543f1-0bbb-44c0-9af6-23c61449e892','train_12137_2026-05-17','train','12137','Firozpur','Mumbai','2026-05-17',4),
('adc7e753-0103-485c-9e47-f3046bc38d19','train_12001_2026-06-15','train','12001','New Delhi','Bhopal','2026-06-15',8),
('212f75e6-5329-4efd-b275-b11adc94abe0','train_12049_2026-05-29','train','12049','Hazrat Nizamuddin','Agra','2026-05-29',8),
('674ed3e0-2f82-425e-a6c9-89c2df478bac','train_12650_2026-05-27','train','12650','Hazrat Nizamuddin','Bengaluru','2026-05-27',4),
('0a8a42df-47a3-4090-b4ac-48fc58102e8b','flight_AI202_2026-05-21','flight','AI202','New Delhi','Mumbai','2026-05-21',3),
('70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a','flight_AI203_2026-05-27','flight','AI203','Mumbai','New Delhi','2026-05-27',7),
('2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b','flight_6E341_2026-06-15','flight','6E341','New Delhi','Bengaluru','2026-06-15',4),
('33c0d80a-0479-424a-bfe3-6d9516b223c0','flight_6E342_2026-06-05','flight','6E342','Bengaluru','New Delhi','2026-06-05',6),
('c0bfb213-de36-48c9-91c6-2144e79afa41','flight_SG401_2026-06-15','flight','SG401','New Delhi','Hyderabad','2026-06-15',1);

-- ── Journeys ────────────────────────────────────────────────────────────
INSERT INTO public.journeys (id,user_id,journey_type,train_number,flight_number,source,destination,journey_date) VALUES
('ff8c2a47-4bcd-44d8-a639-219bf630fd29','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37','train','12301',NULL,'New Delhi','Howrah','2026-05-29'),
('2b843d49-78d8-4b17-971b-bef00236ee2c','a25875b0-b6f7-4bed-8424-c5eac04a8691','train','12301',NULL,'New Delhi','Howrah','2026-05-29'),
('019f8c76-42c7-427e-8d36-52c8d83ca490','fa7f925a-d508-4c83-93f0-d7d43c39b7b5','train','12301',NULL,'New Delhi','Howrah','2026-05-29'),
('eab14e5a-ba26-489f-8654-823f3e100537','f8cce76e-7552-4d2b-bd11-af60602755d9','train','12301',NULL,'New Delhi','Howrah','2026-05-29'),
('e33b649e-ee5c-4209-8083-2765042f1705','4ddbcbb8-2be7-4a7d-a880-545cc2975bbc','train','12301',NULL,'New Delhi','Howrah','2026-05-29'),
('fa468a55-21c0-42d1-905e-aed35ac391e9','2b779edc-8e5e-40e9-859e-2e1cd1dde32a','train','12301',NULL,'New Delhi','Howrah','2026-05-29'),
('37ace939-a0e6-44c2-981b-bb1c10e8053e','f994f2cc-f321-49fe-8d75-3b7982d875d0','train','12301',NULL,'New Delhi','Howrah','2026-05-29'),
('2a24f62a-5fa2-4bfd-8a6f-c47eccd65e09','3eaf7eed-95d3-4881-933f-3d1c82fca8ff','train','12301',NULL,'New Delhi','Howrah','2026-05-29'),
('d32cf5ce-5b54-4b2e-ace1-39f5a8459501','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','train','12302',NULL,'Howrah','New Delhi','2026-06-14'),
('6967b8a3-6ab8-4aad-ae73-10adcdf72e19','a77f8394-6c66-4d6d-a16b-5013cfd88385','train','12302',NULL,'Howrah','New Delhi','2026-06-14'),
('ccafacc2-05ef-426e-a80e-50a17c1a81c0','ee82a7e1-8708-4359-9763-095bde24e848','train','12302',NULL,'Howrah','New Delhi','2026-06-14'),
('e9bc3893-5ebd-4788-9338-bff6c634c7ec','7ea642d5-8df7-4ae1-a624-5daa8af23a34','train','12302',NULL,'Howrah','New Delhi','2026-06-14'),
('6700330f-88a1-4f4f-a2ec-3fe5345b20fc','83b12a8b-8a08-4e95-af91-78cc1032cff1','train','12951',NULL,'New Delhi','Mumbai Central','2026-05-24'),
('3d7ce13c-9cef-400f-a35d-13960dbc5460','50176064-54ea-44ae-89f7-b378fda2df85','train','12951',NULL,'New Delhi','Mumbai Central','2026-05-24'),
('7a36e56a-9df6-4328-a787-50378b559fad','8988ce23-8368-4981-9d43-27369de4a5f8','train','12951',NULL,'New Delhi','Mumbai Central','2026-05-24'),
('6f84ea61-f8a5-440a-8ebc-2ad82811e000','d66070b8-f157-4df9-82e0-ff9aa4d67252','train','12951',NULL,'New Delhi','Mumbai Central','2026-05-24'),
('d2e2abf8-0889-4f12-aad2-26a7a55d2209','d9b37982-f6b2-4b30-b48e-bdd24b288731','train','12951',NULL,'New Delhi','Mumbai Central','2026-05-24'),
('b8a08362-d931-4bb4-8e4f-5334caf21cba','8ede2d73-0ca1-4412-8704-0a0144d56dc6','train','12951',NULL,'New Delhi','Mumbai Central','2026-05-24'),
('5f328b10-a994-4222-bbec-5df6d9a339f6','f5884ea3-0f91-4a69-98b6-40d11702a6bd','train','12951',NULL,'New Delhi','Mumbai Central','2026-05-24'),
('12f722ee-0405-4cd7-be3b-607995f0cb3a','0adaf0ce-abec-421d-bb57-037f7b332e1d','train','12952',NULL,'Mumbai Central','New Delhi','2026-05-17'),
('86c85736-a1cd-4190-bb5e-befc9eb28b06','6fcce34a-52e2-4bf7-b1cd-143821d54bc3','train','12952',NULL,'Mumbai Central','New Delhi','2026-05-17'),
('74c75302-4bb1-422f-9200-5b91d2f45849','2780e8f1-3f06-4674-9215-3cd2bad13c03','train','12952',NULL,'Mumbai Central','New Delhi','2026-05-17'),
('4329ef81-923c-44dc-a712-7bf2d17c811f','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','train','12627',NULL,'New Delhi','Bengaluru','2026-05-25'),
('385dd8fa-4d57-4c55-be02-55dd9eab2329','40b935b5-0ffc-407e-bc76-af36d8053bc2','train','12627',NULL,'New Delhi','Bengaluru','2026-05-25'),
('9f1538b5-f7d2-4004-aa74-a30e57b9d77e','0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','train','12627',NULL,'New Delhi','Bengaluru','2026-05-25'),
('998a6b3d-352d-4360-83aa-7cd1e67d73ab','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','train','12628',NULL,'Bengaluru','New Delhi','2026-05-31'),
('4513de22-8b74-4298-a0ef-fe12fc490873','66e43919-33bb-4434-999f-22a3086cb7f4','train','12628',NULL,'Bengaluru','New Delhi','2026-05-31'),
('4f392397-3339-4f01-be9e-4088ca856490','95ff91b3-6c6a-41d7-ac38-471ac85422da','train','12628',NULL,'Bengaluru','New Delhi','2026-05-31'),
('a99ea9c8-5f4a-458e-b1f2-b2c518d77680','599561ff-7b0e-4659-9b96-eedcd5842f34','train','12628',NULL,'Bengaluru','New Delhi','2026-05-31'),
('726e89ec-db77-4760-be89-f35612646964','73e3a251-b873-433b-9ebf-ba9b9c3b712d','train','12628',NULL,'Bengaluru','New Delhi','2026-05-31'),
('de348f8d-b98f-4ee9-a6b3-2d48ba405b01','656130ae-d5e3-46f8-aa53-21bcc35c28a8','train','12505',NULL,'New Delhi','Guwahati','2026-06-13'),
('a166dd99-b98d-45f0-ae1e-1ed8be9eb6ca','cf6c3a10-8460-4f52-8ee2-7a029042c5d7','train','12505',NULL,'New Delhi','Guwahati','2026-06-13'),
('5b47b861-8c11-4c82-b2b5-fee1d2380abb','fadcce80-f0d7-4031-8233-fb8fc9e34e0f','train','12505',NULL,'New Delhi','Guwahati','2026-06-13'),
('f307ffa4-6cc2-48b9-a478-19618bc954b3','a8dc8480-38ba-4e2c-879d-61e888626bf3','train','12506',NULL,'Guwahati','New Delhi','2026-06-08'),
('4b5ada19-fbe7-4655-8ffd-3ccabdffcac0','ea7cb6f3-8697-4cdc-9b14-2132a630b8c2','train','12506',NULL,'Guwahati','New Delhi','2026-06-08'),
('e725ab3e-c7f8-4444-8725-b703a79b615d','f3883e6b-8190-42eb-b94b-84c6dad5e909','train','12506',NULL,'Guwahati','New Delhi','2026-06-08'),
('5a80d2f2-2cb9-4cff-a840-b513984f895a','0e52e760-d927-49d5-b3f7-568970536394','train','12506',NULL,'Guwahati','New Delhi','2026-06-08'),
('130c511a-fd61-43cb-9539-b8e502945c4f','c21a9c50-33b1-4700-a705-778fc04434f5','train','12506',NULL,'Guwahati','New Delhi','2026-06-08'),
('ff48f343-42e9-4eee-b9a8-d5977a541b51','2f6e2744-67bd-49f0-b2a6-dc104146a963','train','22691',NULL,'New Delhi','Bengaluru','2026-06-04'),
('2e29fb31-a2cf-4798-9a99-b63b6402c2ec','f798196b-807b-48df-a7c7-16961e01b088','train','22691',NULL,'New Delhi','Bengaluru','2026-06-04'),
('1c5125b2-63f1-4f9c-b6ea-a4beb68f5e2d','7508a61b-7926-4b0b-9741-92bdf0a5b801','train','22691',NULL,'New Delhi','Bengaluru','2026-06-04'),
('db16ad59-252d-4be6-a41a-4d613d1d326b','2a397b4f-1650-428d-806e-a9c929655ca1','train','22691',NULL,'New Delhi','Bengaluru','2026-06-04'),
('1be50440-e63b-480d-bfc6-f78cf6740944','53f4a2aa-025f-4886-b165-363912f8e678','train','22691',NULL,'New Delhi','Bengaluru','2026-06-04'),
('30965bcc-bf90-4b04-beb5-c4f5fd1ef423','d9757067-5e1b-41f2-8343-fe980c4bd506','train','12259',NULL,'New Delhi','Kolkata','2026-05-20'),
('792fc7f3-4f5b-49d0-bec7-c86fce16c155','f40d0980-d059-4c82-ad90-a1e19b1adf33','train','12259',NULL,'New Delhi','Kolkata','2026-05-20'),
('75a4c899-4978-4c51-b81f-9263a93d91f5','7c0dc257-7e74-4bd8-a9ea-4d8ec8391be8','train','12259',NULL,'New Delhi','Kolkata','2026-05-20'),
('628bb5e4-3b0d-4fdd-882d-6e0e9c9f4f2d','4e28df34-c6c3-4b37-9449-74893ca8dfae','train','12259',NULL,'New Delhi','Kolkata','2026-05-20'),
('601cc75f-e8c7-4490-bc0d-75d0bc3ce0e6','9b70939f-08cc-4e07-80cb-06b8a7584ddf','train','12259',NULL,'New Delhi','Kolkata','2026-05-20'),
('5f7156a2-9866-4d6f-965d-564cd2a44167','5c1b5a20-6f22-431a-a2ba-016f5d112e49','train','12259',NULL,'New Delhi','Kolkata','2026-05-20'),
('2c843329-da8e-4cfe-b8aa-f5bf844f70d0','b255e0d1-47f5-47e2-b7fa-3682b9c70ef5','train','12259',NULL,'New Delhi','Kolkata','2026-05-20'),
('d6c549c5-232d-4cc8-8432-af20a7758e4f','9a994052-6788-48cc-9240-6a26c8d32c35','train','12259',NULL,'New Delhi','Kolkata','2026-05-20'),
('588893cd-13df-4565-bb76-28591cc20814','ee99aa6b-48e7-4074-a4ba-fb16d76249d1','train','12030',NULL,'Amritsar','New Delhi','2026-05-27'),
('583c0c22-4d43-462e-8200-4f24fb60d776','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','train','12030',NULL,'Amritsar','New Delhi','2026-05-27'),
('3b2b4621-14ab-416f-92dc-7a0e63f796b1','25ce2843-8039-420c-bf21-cd436c59195d','train','12030',NULL,'Amritsar','New Delhi','2026-05-27'),
('0c9bb72e-1382-4671-8c1e-8bab3092c0d1','f88cf7f0-e103-4db9-897c-f70b5544e51f','train','12030',NULL,'Amritsar','New Delhi','2026-05-27'),
('8e1a7cef-54a0-47a3-a3b6-de3ad435493d','b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','train','12137',NULL,'Firozpur','Mumbai','2026-05-17'),
('c5e603a4-ceba-4bed-9a42-9d96ff88d455','f91fbdcd-2c3b-4ad6-b653-3e323af41f79','train','12137',NULL,'Firozpur','Mumbai','2026-05-17'),
('4d384bb1-71eb-41df-8d3f-54f6f37e48aa','424c8082-c736-4860-9e90-24be1565854e','train','12137',NULL,'Firozpur','Mumbai','2026-05-17'),
('8945bd2c-4245-461d-99fa-220fc958c62d','02ccdcd8-e45a-435d-bc04-86f2bb129992','train','12137',NULL,'Firozpur','Mumbai','2026-05-17'),
('81145a25-d108-4c64-b624-2b4a9ea732ab','637e185c-f1fe-4afe-af7f-b7b7e9b60edc','train','12001',NULL,'New Delhi','Bhopal','2026-06-15'),
('bdc2e4f1-31a2-4341-bda7-7d861b662290','eb2d91e8-f6ed-45da-a4ba-63e5765c05fe','train','12001',NULL,'New Delhi','Bhopal','2026-06-15'),
('209fa189-53b9-43d2-a04b-bfcb2ad76796','e6dc2b9c-600e-455a-a943-7eb328f05212','train','12001',NULL,'New Delhi','Bhopal','2026-06-15'),
('3a731f7a-359b-4894-b853-22ccabd6c20f','575e3b18-220a-4b1b-975e-fbdaebcb3f92','train','12001',NULL,'New Delhi','Bhopal','2026-06-15'),
('0da30b32-8c30-493b-a3c3-05a83d102463','660fb29d-479e-40f5-95a2-81f045db5c69','train','12001',NULL,'New Delhi','Bhopal','2026-06-15'),
('0a5ba68d-d037-4d7a-b07e-8d216d04427f','96252279-a167-4d8b-8a55-8e35699a01c0','train','12001',NULL,'New Delhi','Bhopal','2026-06-15'),
('d69e950f-a49e-43a2-bbe2-df79a6243bbb','49db741c-b8a0-46b0-9ba2-37fdc8b9ef96','train','12001',NULL,'New Delhi','Bhopal','2026-06-15'),
('d4c8e756-f3a0-491d-bcd7-aac4b7ccf728','bc44693f-6524-49c9-a6d8-06a3ca4d61d8','train','12001',NULL,'New Delhi','Bhopal','2026-06-15'),
('a0c1cc7f-842c-4991-8a88-be2e913b4007','287cffed-71ac-4b66-8552-4aadd6cbf3dc','train','12049',NULL,'Hazrat Nizamuddin','Agra','2026-05-29'),
('94d9c624-feea-4183-b84b-bfe7cc2cd5d8','72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','train','12049',NULL,'Hazrat Nizamuddin','Agra','2026-05-29'),
('497a8b4b-e3a5-4619-b6e2-6da102fa37db','a484a03b-1cb9-4790-835b-64245238bcda','train','12049',NULL,'Hazrat Nizamuddin','Agra','2026-05-29'),
('1331ea30-b595-49a4-87e6-6dc6b931ca62','97b03499-1962-4087-b478-48102f464a91','train','12049',NULL,'Hazrat Nizamuddin','Agra','2026-05-29'),
('eb05cd40-7473-4dda-8a82-ed3241bc51d5','73250fab-0868-4148-a348-e1654293fbab','train','12049',NULL,'Hazrat Nizamuddin','Agra','2026-05-29'),
('e1f4fa9f-ba64-41cd-9e16-1116f7de3ba1','7a348d56-91d8-4610-959b-0fc29c14686e','train','12049',NULL,'Hazrat Nizamuddin','Agra','2026-05-29'),
('0a6c55a4-d68f-4e1e-9725-c4bb1f073692','8f1072d4-86dd-40b5-8521-0db5b9f305a2','train','12049',NULL,'Hazrat Nizamuddin','Agra','2026-05-29'),
('92842996-50b6-498a-ba93-136945310fc5','380997d4-59cd-41f2-9f95-a97b1a65c25b','train','12049',NULL,'Hazrat Nizamuddin','Agra','2026-05-29'),
('a151929e-0946-4872-902c-41d2a0510895','0412662f-98b9-4fda-a1b4-4173f2c27ad4','train','12650',NULL,'Hazrat Nizamuddin','Bengaluru','2026-05-27'),
('cf4baba0-d695-455d-978b-560a6b735576','c6cac135-7583-4250-a794-189b972b8fc9','train','12650',NULL,'Hazrat Nizamuddin','Bengaluru','2026-05-27'),
('143914d6-e748-4b7e-81a2-20fa93e5f483','be8c4d41-4490-481c-a7f9-6cb6f65d9866','train','12650',NULL,'Hazrat Nizamuddin','Bengaluru','2026-05-27'),
('e524c08d-d075-41df-9cd2-dfa429a2a0d7','9340edc8-05a5-4c4a-8c73-2a35ad4bfec6','train','12650',NULL,'Hazrat Nizamuddin','Bengaluru','2026-05-27'),
('5acd5105-8c3e-4a8c-85a3-1c858e608543','955b7867-3dfe-4a2a-91ce-600feb668284','flight',NULL,'AI202','New Delhi','Mumbai','2026-05-21'),
('78295fe8-55c0-4307-aef4-a7e2d4726c09','d98aa471-cb45-4263-936f-87b6a955f196','flight',NULL,'AI202','New Delhi','Mumbai','2026-05-21'),
('14eba6a0-038e-4a97-8e3f-9949728169cb','0863b4e8-e752-4c04-837e-419f091fe3dd','flight',NULL,'AI202','New Delhi','Mumbai','2026-05-21'),
('db1d0730-1307-4225-89b3-a6559a705112','43eaa843-55b6-44b9-943a-f28e2f552f1f','flight',NULL,'AI203','Mumbai','New Delhi','2026-05-27'),
('b3f3da05-9e5e-4654-8c15-9f6d6ec2cd7a','4d0a152e-ea34-4f15-a703-309516ee6b4d','flight',NULL,'AI203','Mumbai','New Delhi','2026-05-27'),
('d4358474-9e0e-4b56-baae-aced3fe3c169','6a3f8cad-ce91-4c37-985c-2c2a2a6f5851','flight',NULL,'AI203','Mumbai','New Delhi','2026-05-27'),
('cdbb5269-adf7-49b1-8b14-4f38b5c84430','ee94d5e1-b558-4c66-bc3e-7d603dfb21e1','flight',NULL,'AI203','Mumbai','New Delhi','2026-05-27'),
('a2c74dbe-8f06-4a1c-a43b-974a9ee65f55','bfa15c31-e6cb-4704-a3fe-ecb67862c1ed','flight',NULL,'AI203','Mumbai','New Delhi','2026-05-27'),
('f697eed5-4157-440e-9de7-3e9a45b7ce3d','b6ac128c-ca95-438e-b6e5-e1b850f78352','flight',NULL,'AI203','Mumbai','New Delhi','2026-05-27'),
('3f092b31-857d-4437-a857-23f4941e96c4','8645c745-a0a1-4ea7-89ff-ca7cd6a9074f','flight',NULL,'AI203','Mumbai','New Delhi','2026-05-27'),
('a99c8e9c-b632-4b08-b0f4-11e9a3c13c97','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','flight',NULL,'6E341','New Delhi','Bengaluru','2026-06-15'),
('f163dd79-36a0-43f9-add5-6029c83c3aac','63a974f3-6530-40b4-892f-1a620b38563e','flight',NULL,'6E341','New Delhi','Bengaluru','2026-06-15'),
('5de9c982-d8d9-46cd-80ba-f7a270071304','2daa15f6-74b4-4c83-9153-edb6c92317e8','flight',NULL,'6E341','New Delhi','Bengaluru','2026-06-15'),
('ca8ca81a-bbb3-4456-8ee3-044060d5eb35','f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','flight',NULL,'6E341','New Delhi','Bengaluru','2026-06-15'),
('47ad01ba-7891-4a1e-ba59-282254340a9c','dd32fda6-6a98-4538-a5c5-c21092fd78e4','flight',NULL,'6E342','Bengaluru','New Delhi','2026-06-05'),
('682cbb41-93c2-4e42-8cb0-ced59a564c21','6125af0e-06f0-464b-b752-bbbe0d5b6b27','flight',NULL,'6E342','Bengaluru','New Delhi','2026-06-05'),
('1a5d6da2-7d03-40bc-96d8-2f69758da947','f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','flight',NULL,'6E342','Bengaluru','New Delhi','2026-06-05'),
('313108de-5ff1-4edf-99ba-ac1f5e56d95f','e7a41005-3e6d-434f-bd4d-b38fcaf970d1','flight',NULL,'6E342','Bengaluru','New Delhi','2026-06-05'),
('b538fdf4-79dc-4857-975d-42aaba8f4b76','4f270acd-505b-44ce-86ba-538743a770e5','flight',NULL,'6E342','Bengaluru','New Delhi','2026-06-05'),
('45068696-101e-4ce8-9e31-74121df32332','d0ff8ce3-8f3a-4afb-b2c7-c28b13651a84','flight',NULL,'6E342','Bengaluru','New Delhi','2026-06-05'),
('a3851570-f6c4-49cd-b7e1-184467fa0905','5a1be9c2-63af-4f6e-af20-9231c845ce53','flight',NULL,'SG401','New Delhi','Hyderabad','2026-06-15');

-- ── Room Members ────────────────────────────────────────────────────────
INSERT INTO public.room_members (id,room_id,user_id,journey_id) VALUES
('9648d471-afa4-4c5c-8850-ab6203537c01','564ec993-187e-4aef-9acd-8adbd6836cad','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37','ff8c2a47-4bcd-44d8-a639-219bf630fd29'),
('67c5b653-21a4-4760-af49-a99759800d2f','564ec993-187e-4aef-9acd-8adbd6836cad','a25875b0-b6f7-4bed-8424-c5eac04a8691','2b843d49-78d8-4b17-971b-bef00236ee2c'),
('c9626d6a-977a-454a-be9e-c0d502e88602','564ec993-187e-4aef-9acd-8adbd6836cad','fa7f925a-d508-4c83-93f0-d7d43c39b7b5','019f8c76-42c7-427e-8d36-52c8d83ca490'),
('6f74eab5-79ab-40e9-91e2-426bcb134eb9','564ec993-187e-4aef-9acd-8adbd6836cad','f8cce76e-7552-4d2b-bd11-af60602755d9','eab14e5a-ba26-489f-8654-823f3e100537'),
('6ae08c12-a1be-4810-801a-7c3ccc89441d','564ec993-187e-4aef-9acd-8adbd6836cad','4ddbcbb8-2be7-4a7d-a880-545cc2975bbc','e33b649e-ee5c-4209-8083-2765042f1705'),
('1b5d766f-0486-46af-aaab-935b13c3b906','564ec993-187e-4aef-9acd-8adbd6836cad','2b779edc-8e5e-40e9-859e-2e1cd1dde32a','fa468a55-21c0-42d1-905e-aed35ac391e9'),
('074fb1cb-f956-4a8d-a9cd-edbe73c460f6','564ec993-187e-4aef-9acd-8adbd6836cad','f994f2cc-f321-49fe-8d75-3b7982d875d0','37ace939-a0e6-44c2-981b-bb1c10e8053e'),
('4ffd4df5-ca38-443e-bbf3-28a47ace98fe','564ec993-187e-4aef-9acd-8adbd6836cad','3eaf7eed-95d3-4881-933f-3d1c82fca8ff','2a24f62a-5fa2-4bfd-8a6f-c47eccd65e09'),
('f51d8b12-63c1-497b-974f-a60f7524fd6c','0044eb37-07f3-4329-afc0-e0142cd1e716','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','d32cf5ce-5b54-4b2e-ace1-39f5a8459501'),
('fc1dd2fc-3a59-4084-a7ed-925ca0dfaff0','0044eb37-07f3-4329-afc0-e0142cd1e716','a77f8394-6c66-4d6d-a16b-5013cfd88385','6967b8a3-6ab8-4aad-ae73-10adcdf72e19'),
('fcc4c29c-eb37-4ca1-b6d8-b046130278cf','0044eb37-07f3-4329-afc0-e0142cd1e716','ee82a7e1-8708-4359-9763-095bde24e848','ccafacc2-05ef-426e-a80e-50a17c1a81c0'),
('3ac416d0-ee51-474a-baea-33c1a9c633bb','0044eb37-07f3-4329-afc0-e0142cd1e716','7ea642d5-8df7-4ae1-a624-5daa8af23a34','e9bc3893-5ebd-4788-9338-bff6c634c7ec'),
('ba716958-e4ce-4551-803c-9841304a03e3','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7','83b12a8b-8a08-4e95-af91-78cc1032cff1','6700330f-88a1-4f4f-a2ec-3fe5345b20fc'),
('ac826fa2-b42a-4c8a-beed-4ef4fef521e0','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7','50176064-54ea-44ae-89f7-b378fda2df85','3d7ce13c-9cef-400f-a35d-13960dbc5460'),
('a0c44ced-6fea-4270-96ed-3cd7b46cde93','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7','8988ce23-8368-4981-9d43-27369de4a5f8','7a36e56a-9df6-4328-a787-50378b559fad'),
('1174ec4b-3722-4fe5-8880-58450941e0fd','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7','d66070b8-f157-4df9-82e0-ff9aa4d67252','6f84ea61-f8a5-440a-8ebc-2ad82811e000'),
('5c08de16-fa8c-4f59-bfb7-87bbe5941d3e','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7','d9b37982-f6b2-4b30-b48e-bdd24b288731','d2e2abf8-0889-4f12-aad2-26a7a55d2209'),
('2bf04ca3-bbcb-4b51-8912-b34e906cbb76','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7','8ede2d73-0ca1-4412-8704-0a0144d56dc6','b8a08362-d931-4bb4-8e4f-5334caf21cba'),
('18eafe7d-f1cd-4e5d-ad06-54f5f0353cff','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7','f5884ea3-0f91-4a69-98b6-40d11702a6bd','5f328b10-a994-4222-bbec-5df6d9a339f6'),
('9ba3df8b-6493-44cf-933e-7d330d2f85fd','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137','0adaf0ce-abec-421d-bb57-037f7b332e1d','12f722ee-0405-4cd7-be3b-607995f0cb3a'),
('a1f26e09-4040-4b08-aeb2-e085bab5c31b','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137','6fcce34a-52e2-4bf7-b1cd-143821d54bc3','86c85736-a1cd-4190-bb5e-befc9eb28b06'),
('660501ad-882d-41d9-96ec-97eed0956d4d','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137','2780e8f1-3f06-4674-9215-3cd2bad13c03','74c75302-4bb1-422f-9200-5b91d2f45849'),
('ceebeb52-11ea-43f0-9b4a-774dd5d2c0c1','cab0c412-cd35-4876-8333-27cf971b1036','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','4329ef81-923c-44dc-a712-7bf2d17c811f'),
('9490b849-7dd3-4fd6-8b27-6aeec63a2c44','cab0c412-cd35-4876-8333-27cf971b1036','40b935b5-0ffc-407e-bc76-af36d8053bc2','385dd8fa-4d57-4c55-be02-55dd9eab2329'),
('90a097bd-0ac0-4acb-a8a8-9af995197ae9','cab0c412-cd35-4876-8333-27cf971b1036','0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','9f1538b5-f7d2-4004-aa74-a30e57b9d77e'),
('43898761-c121-4d4a-ad12-6b1366ad1041','29f22b79-ca71-4a72-a011-29f4fd992705','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','998a6b3d-352d-4360-83aa-7cd1e67d73ab'),
('145153ba-87e1-4f61-8fd7-90f8983cb3cb','29f22b79-ca71-4a72-a011-29f4fd992705','66e43919-33bb-4434-999f-22a3086cb7f4','4513de22-8b74-4298-a0ef-fe12fc490873'),
('affea23b-8d33-45ce-bb1d-05ec3e9a6a08','29f22b79-ca71-4a72-a011-29f4fd992705','95ff91b3-6c6a-41d7-ac38-471ac85422da','4f392397-3339-4f01-be9e-4088ca856490'),
('ac8cc350-ab45-420a-bcac-255c3370e4c2','29f22b79-ca71-4a72-a011-29f4fd992705','599561ff-7b0e-4659-9b96-eedcd5842f34','a99ea9c8-5f4a-458e-b1f2-b2c518d77680'),
('ae71a24c-8472-46d2-b6ff-dad3496cbb0f','29f22b79-ca71-4a72-a011-29f4fd992705','73e3a251-b873-433b-9ebf-ba9b9c3b712d','726e89ec-db77-4760-be89-f35612646964'),
('8432f58e-53c9-4670-9cb4-e43635dff2a9','2a5ff177-4154-4a27-ae0c-d7828e141029','656130ae-d5e3-46f8-aa53-21bcc35c28a8','de348f8d-b98f-4ee9-a6b3-2d48ba405b01'),
('7bfe929c-c632-4bbd-b17c-f5347d46286a','2a5ff177-4154-4a27-ae0c-d7828e141029','cf6c3a10-8460-4f52-8ee2-7a029042c5d7','a166dd99-b98d-45f0-ae1e-1ed8be9eb6ca'),
('16f8e1b7-ffc2-4710-a31a-0a8b3272fd80','2a5ff177-4154-4a27-ae0c-d7828e141029','fadcce80-f0d7-4031-8233-fb8fc9e34e0f','5b47b861-8c11-4c82-b2b5-fee1d2380abb'),
('039a0a83-03ed-4dcb-862e-09bcaf73bfed','17061f6f-be50-44a0-af22-debf59b246b4','a8dc8480-38ba-4e2c-879d-61e888626bf3','f307ffa4-6cc2-48b9-a478-19618bc954b3'),
('4756fc8d-30c0-46a0-87df-d26f1daf3dfa','17061f6f-be50-44a0-af22-debf59b246b4','ea7cb6f3-8697-4cdc-9b14-2132a630b8c2','4b5ada19-fbe7-4655-8ffd-3ccabdffcac0'),
('b1f7a69d-344b-431d-8965-197e9e8ef875','17061f6f-be50-44a0-af22-debf59b246b4','f3883e6b-8190-42eb-b94b-84c6dad5e909','e725ab3e-c7f8-4444-8725-b703a79b615d'),
('5e392741-e44a-42f6-998c-18add7f5bad9','17061f6f-be50-44a0-af22-debf59b246b4','0e52e760-d927-49d5-b3f7-568970536394','5a80d2f2-2cb9-4cff-a840-b513984f895a'),
('b49f2d50-40cc-4993-841f-da1df4e88dbf','17061f6f-be50-44a0-af22-debf59b246b4','c21a9c50-33b1-4700-a705-778fc04434f5','130c511a-fd61-43cb-9539-b8e502945c4f'),
('7a8d986b-2390-4dac-a218-76871d847e8e','3658226f-91db-4ae4-b9d7-20b9d367ce58','2f6e2744-67bd-49f0-b2a6-dc104146a963','ff48f343-42e9-4eee-b9a8-d5977a541b51'),
('29611699-5677-4bdf-aaa9-8ae9ab6f88b0','3658226f-91db-4ae4-b9d7-20b9d367ce58','f798196b-807b-48df-a7c7-16961e01b088','2e29fb31-a2cf-4798-9a99-b63b6402c2ec'),
('72fdb814-86e2-48e1-b523-f5604cab5366','3658226f-91db-4ae4-b9d7-20b9d367ce58','7508a61b-7926-4b0b-9741-92bdf0a5b801','1c5125b2-63f1-4f9c-b6ea-a4beb68f5e2d'),
('d0e892d6-ef3a-48f8-a1da-0faf6ccd3b44','3658226f-91db-4ae4-b9d7-20b9d367ce58','2a397b4f-1650-428d-806e-a9c929655ca1','db16ad59-252d-4be6-a41a-4d613d1d326b'),
('cd4a7203-ca14-4041-bb79-55d2c5b64f13','3658226f-91db-4ae4-b9d7-20b9d367ce58','53f4a2aa-025f-4886-b165-363912f8e678','1be50440-e63b-480d-bfc6-f78cf6740944'),
('facef442-6de1-4bab-9d96-9731895e19ce','1e91aa35-5420-4017-a29d-9bff0b89f8e9','d9757067-5e1b-41f2-8343-fe980c4bd506','30965bcc-bf90-4b04-beb5-c4f5fd1ef423'),
('55851330-0d71-4a12-bda6-3dd538ec8ad4','1e91aa35-5420-4017-a29d-9bff0b89f8e9','f40d0980-d059-4c82-ad90-a1e19b1adf33','792fc7f3-4f5b-49d0-bec7-c86fce16c155'),
('bf4564cb-0400-47fc-b56c-fa3db9e5a6fd','1e91aa35-5420-4017-a29d-9bff0b89f8e9','7c0dc257-7e74-4bd8-a9ea-4d8ec8391be8','75a4c899-4978-4c51-b81f-9263a93d91f5'),
('fc61b53f-b13e-4f1e-b15e-441c74455cb2','1e91aa35-5420-4017-a29d-9bff0b89f8e9','4e28df34-c6c3-4b37-9449-74893ca8dfae','628bb5e4-3b0d-4fdd-882d-6e0e9c9f4f2d'),
('c60d1bca-bc9d-4ee1-8d31-9a89be0664f7','1e91aa35-5420-4017-a29d-9bff0b89f8e9','9b70939f-08cc-4e07-80cb-06b8a7584ddf','601cc75f-e8c7-4490-bc0d-75d0bc3ce0e6'),
('7bdc979f-e252-4129-ba18-436d86056679','1e91aa35-5420-4017-a29d-9bff0b89f8e9','5c1b5a20-6f22-431a-a2ba-016f5d112e49','5f7156a2-9866-4d6f-965d-564cd2a44167'),
('a2ea6b29-c33d-4b9b-bd5f-e110ce1bbfbc','1e91aa35-5420-4017-a29d-9bff0b89f8e9','b255e0d1-47f5-47e2-b7fa-3682b9c70ef5','2c843329-da8e-4cfe-b8aa-f5bf844f70d0'),
('a66981a1-47db-48b5-abcf-2c358a51ae35','1e91aa35-5420-4017-a29d-9bff0b89f8e9','9a994052-6788-48cc-9240-6a26c8d32c35','d6c549c5-232d-4cc8-8432-af20a7758e4f'),
('12c2ffd9-0d26-411d-959c-9e46adcc273e','9a11861f-0b94-4ec8-82f5-b35d2e1823a1','ee99aa6b-48e7-4074-a4ba-fb16d76249d1','588893cd-13df-4565-bb76-28591cc20814'),
('4e893daf-0946-4790-aa5b-93d9dff0934c','9a11861f-0b94-4ec8-82f5-b35d2e1823a1','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','583c0c22-4d43-462e-8200-4f24fb60d776'),
('19e799b6-86d3-45a9-991b-ee2649897c3d','9a11861f-0b94-4ec8-82f5-b35d2e1823a1','25ce2843-8039-420c-bf21-cd436c59195d','3b2b4621-14ab-416f-92dc-7a0e63f796b1'),
('cdf0d2a4-249e-42b8-babb-98002b16f8c3','9a11861f-0b94-4ec8-82f5-b35d2e1823a1','f88cf7f0-e103-4db9-897c-f70b5544e51f','0c9bb72e-1382-4671-8c1e-8bab3092c0d1'),
('3c5dbd9f-a85a-44c6-b91c-622f507c4af4','13d543f1-0bbb-44c0-9af6-23c61449e892','b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','8e1a7cef-54a0-47a3-a3b6-de3ad435493d'),
('252ba388-9dd0-4a73-8ab2-67905f666dd1','13d543f1-0bbb-44c0-9af6-23c61449e892','f91fbdcd-2c3b-4ad6-b653-3e323af41f79','c5e603a4-ceba-4bed-9a42-9d96ff88d455'),
('260b0871-9c7a-4889-9a1b-8e717faf6fc8','13d543f1-0bbb-44c0-9af6-23c61449e892','424c8082-c736-4860-9e90-24be1565854e','4d384bb1-71eb-41df-8d3f-54f6f37e48aa'),
('4c817276-1167-45c3-b8d4-f8d20f5a56c0','13d543f1-0bbb-44c0-9af6-23c61449e892','02ccdcd8-e45a-435d-bc04-86f2bb129992','8945bd2c-4245-461d-99fa-220fc958c62d'),
('c93aa897-75e9-4bd2-bd6e-7e5ddd2cb359','adc7e753-0103-485c-9e47-f3046bc38d19','637e185c-f1fe-4afe-af7f-b7b7e9b60edc','81145a25-d108-4c64-b624-2b4a9ea732ab'),
('1d1a4d81-dfb4-4d22-ba4a-333e3c155139','adc7e753-0103-485c-9e47-f3046bc38d19','eb2d91e8-f6ed-45da-a4ba-63e5765c05fe','bdc2e4f1-31a2-4341-bda7-7d861b662290'),
('9dbde194-4ab6-42f4-b3d6-997e0c973ba0','adc7e753-0103-485c-9e47-f3046bc38d19','e6dc2b9c-600e-455a-a943-7eb328f05212','209fa189-53b9-43d2-a04b-bfcb2ad76796'),
('22420e40-bc50-4831-a2b8-e8eb68e76af7','adc7e753-0103-485c-9e47-f3046bc38d19','575e3b18-220a-4b1b-975e-fbdaebcb3f92','3a731f7a-359b-4894-b853-22ccabd6c20f'),
('0c3719d3-2511-4b51-8087-343ed539802c','adc7e753-0103-485c-9e47-f3046bc38d19','660fb29d-479e-40f5-95a2-81f045db5c69','0da30b32-8c30-493b-a3c3-05a83d102463'),
('07b6b206-149c-45a0-80fc-bd664c8c3b48','adc7e753-0103-485c-9e47-f3046bc38d19','96252279-a167-4d8b-8a55-8e35699a01c0','0a5ba68d-d037-4d7a-b07e-8d216d04427f'),
('71db174a-6130-4864-9b51-0d4883c13558','adc7e753-0103-485c-9e47-f3046bc38d19','49db741c-b8a0-46b0-9ba2-37fdc8b9ef96','d69e950f-a49e-43a2-bbe2-df79a6243bbb'),
('3c29135d-2457-4567-988c-d60df07bd056','adc7e753-0103-485c-9e47-f3046bc38d19','bc44693f-6524-49c9-a6d8-06a3ca4d61d8','d4c8e756-f3a0-491d-bcd7-aac4b7ccf728'),
('67bdc7c5-f964-40ec-97de-7b68ac006ef8','212f75e6-5329-4efd-b275-b11adc94abe0','287cffed-71ac-4b66-8552-4aadd6cbf3dc','a0c1cc7f-842c-4991-8a88-be2e913b4007'),
('5abf3420-a759-47f3-8b92-e1223f47b817','212f75e6-5329-4efd-b275-b11adc94abe0','72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','94d9c624-feea-4183-b84b-bfe7cc2cd5d8'),
('799c73a2-99b1-4c95-8d9e-a27ad4b31b96','212f75e6-5329-4efd-b275-b11adc94abe0','a484a03b-1cb9-4790-835b-64245238bcda','497a8b4b-e3a5-4619-b6e2-6da102fa37db'),
('de262f6a-834a-4cb7-ba83-6f0f75455b6c','212f75e6-5329-4efd-b275-b11adc94abe0','97b03499-1962-4087-b478-48102f464a91','1331ea30-b595-49a4-87e6-6dc6b931ca62'),
('42463343-929c-47dd-ac4a-aa3f2cd0b01f','212f75e6-5329-4efd-b275-b11adc94abe0','73250fab-0868-4148-a348-e1654293fbab','eb05cd40-7473-4dda-8a82-ed3241bc51d5'),
('de4d790a-998d-4953-a01e-ef88a661f589','212f75e6-5329-4efd-b275-b11adc94abe0','7a348d56-91d8-4610-959b-0fc29c14686e','e1f4fa9f-ba64-41cd-9e16-1116f7de3ba1'),
('cb0acb01-f2cc-47b7-9e7a-da6c69643dce','212f75e6-5329-4efd-b275-b11adc94abe0','8f1072d4-86dd-40b5-8521-0db5b9f305a2','0a6c55a4-d68f-4e1e-9725-c4bb1f073692'),
('a4c9a7f4-313a-43aa-98c0-a711d363f1ee','212f75e6-5329-4efd-b275-b11adc94abe0','380997d4-59cd-41f2-9f95-a97b1a65c25b','92842996-50b6-498a-ba93-136945310fc5'),
('a90e8a74-dcbd-4309-89ec-fc3ee76ce873','674ed3e0-2f82-425e-a6c9-89c2df478bac','0412662f-98b9-4fda-a1b4-4173f2c27ad4','a151929e-0946-4872-902c-41d2a0510895'),
('edb914ce-72b1-43e2-8c90-52129e9c511a','674ed3e0-2f82-425e-a6c9-89c2df478bac','c6cac135-7583-4250-a794-189b972b8fc9','cf4baba0-d695-455d-978b-560a6b735576'),
('9fec810a-7083-4359-b348-d420c1a29f13','674ed3e0-2f82-425e-a6c9-89c2df478bac','be8c4d41-4490-481c-a7f9-6cb6f65d9866','143914d6-e748-4b7e-81a2-20fa93e5f483'),
('e407ff6e-3345-40d9-9bf9-0b894e1c5034','674ed3e0-2f82-425e-a6c9-89c2df478bac','9340edc8-05a5-4c4a-8c73-2a35ad4bfec6','e524c08d-d075-41df-9cd2-dfa429a2a0d7'),
('39fe0180-e9ab-4223-895e-566cd710c90d','0a8a42df-47a3-4090-b4ac-48fc58102e8b','955b7867-3dfe-4a2a-91ce-600feb668284','5acd5105-8c3e-4a8c-85a3-1c858e608543'),
('f0981ff2-cfe5-4cc8-b592-a667c89d1536','0a8a42df-47a3-4090-b4ac-48fc58102e8b','d98aa471-cb45-4263-936f-87b6a955f196','78295fe8-55c0-4307-aef4-a7e2d4726c09'),
('ad31b4a8-882d-4f71-983d-46b3ee9da1cb','0a8a42df-47a3-4090-b4ac-48fc58102e8b','0863b4e8-e752-4c04-837e-419f091fe3dd','14eba6a0-038e-4a97-8e3f-9949728169cb'),
('c22d15b7-d4bf-495f-b80b-7a2d57d315d8','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a','43eaa843-55b6-44b9-943a-f28e2f552f1f','db1d0730-1307-4225-89b3-a6559a705112'),
('ef35c9e2-f489-4ac3-bb6f-c8b36410a6bc','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a','4d0a152e-ea34-4f15-a703-309516ee6b4d','b3f3da05-9e5e-4654-8c15-9f6d6ec2cd7a'),
('85376f94-95e7-46c7-8c46-f34733b39ed7','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a','6a3f8cad-ce91-4c37-985c-2c2a2a6f5851','d4358474-9e0e-4b56-baae-aced3fe3c169'),
('5b58495b-5ace-47fa-aebc-028754b59224','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a','ee94d5e1-b558-4c66-bc3e-7d603dfb21e1','cdbb5269-adf7-49b1-8b14-4f38b5c84430'),
('1a80d6b1-1ca8-4107-a6c5-b9baeba23afe','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a','bfa15c31-e6cb-4704-a3fe-ecb67862c1ed','a2c74dbe-8f06-4a1c-a43b-974a9ee65f55'),
('432707cd-42c3-42ea-8ad1-9adb8a85033b','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a','b6ac128c-ca95-438e-b6e5-e1b850f78352','f697eed5-4157-440e-9de7-3e9a45b7ce3d'),
('054b8cd9-fc15-49ca-98a0-f962d61e2f77','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a','8645c745-a0a1-4ea7-89ff-ca7cd6a9074f','3f092b31-857d-4437-a857-23f4941e96c4'),
('22d13b60-e69f-4548-8a24-2830943c2574','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','a99c8e9c-b632-4b08-b0f4-11e9a3c13c97'),
('b74998e3-09f6-42b9-91fe-c65053b3f651','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b','63a974f3-6530-40b4-892f-1a620b38563e','f163dd79-36a0-43f9-add5-6029c83c3aac'),
('d0510c62-fd61-40ea-a3ca-8c2d518c3d53','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b','2daa15f6-74b4-4c83-9153-edb6c92317e8','5de9c982-d8d9-46cd-80ba-f7a270071304'),
('50894df2-c5a9-4f8e-807c-ffee8496572d','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b','f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','ca8ca81a-bbb3-4456-8ee3-044060d5eb35'),
('e24dc65d-c055-46bf-8883-b1629d42b4f7','33c0d80a-0479-424a-bfe3-6d9516b223c0','dd32fda6-6a98-4538-a5c5-c21092fd78e4','47ad01ba-7891-4a1e-ba59-282254340a9c'),
('3ddcf3e0-c67b-4401-8915-845d75a75693','33c0d80a-0479-424a-bfe3-6d9516b223c0','6125af0e-06f0-464b-b752-bbbe0d5b6b27','682cbb41-93c2-4e42-8cb0-ced59a564c21'),
('bcde3f4a-59a1-4345-8575-0d83e66e57f6','33c0d80a-0479-424a-bfe3-6d9516b223c0','f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','1a5d6da2-7d03-40bc-96d8-2f69758da947'),
('aafbdfa4-0520-40e5-8f5f-58060fbb3dca','33c0d80a-0479-424a-bfe3-6d9516b223c0','e7a41005-3e6d-434f-bd4d-b38fcaf970d1','313108de-5ff1-4edf-99ba-ac1f5e56d95f'),
('2215b141-6c70-4372-9a52-1515da50b34b','33c0d80a-0479-424a-bfe3-6d9516b223c0','4f270acd-505b-44ce-86ba-538743a770e5','b538fdf4-79dc-4857-975d-42aaba8f4b76'),
('c02f4796-679f-41aa-83de-04808f30877e','33c0d80a-0479-424a-bfe3-6d9516b223c0','d0ff8ce3-8f3a-4afb-b2c7-c28b13651a84','45068696-101e-4ce8-9e31-74121df32332'),
('316515e8-e5a1-4751-a09c-64569d566117','c0bfb213-de36-48c9-91c6-2144e79afa41','5a1be9c2-63af-4f6e-af20-9231c845ce53','a3851570-f6c4-49cd-b7e1-184467fa0905');

-- ── Groups ──────────────────────────────────────────────────────────────
INSERT INTO public.groups (id,room_id,creator_id,name,description,gender_filter,max_members,visibility,requires_approval,member_count) VALUES
('a53b89dd-262c-484f-a187-18dc15f313c4','564ec993-187e-4aef-9acd-8adbd6836cad','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37','Night Owls 🦉','For those traveling overnight — let''s make it fun','all_girls',13,'public',false,6),
('e8d5a104-9919-45c6-8853-d6efd0a483b1','0044eb37-07f3-4329-afc0-e0142cd1e716','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','Boys Only 🚀','Just the guys, no filter','mixed',15,'public',false,3),
('a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','0044eb37-07f3-4329-afc0-e0142cd1e716','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','IIT Gang 🎓','Only IITians, represent!','any',9,'public',true,2),
('14d9523b-ad69-4b52-8a91-464b78d35ed9','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7','83b12a8b-8a08-4e95-af91-78cc1032cff1','Chill Vibes 😎','No drama, just good company','any',13,'public',false,5),
('39c9ca91-9823-4bfa-99f5-3eced6575baa','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137','0adaf0ce-abec-421d-bb57-037f7b332e1d','Night Shift ☀️','Connecting night travelers','mixed',5,'public',false,3),
('4968d6e8-ec57-454d-be23-45b064c61a7d','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137','0adaf0ce-abec-421d-bb57-037f7b332e1d','Study Group 📚','Final year students connect here','mixed',8,'public',false,3),
('a2f10238-59ac-49f3-94f2-11e20d60cb1f','cab0c412-cd35-4876-8333-27cf971b1036','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Foodies 🍱','Who wants to share food and find good dhabas','all_boys',14,'public',false,2),
('fff34913-5402-4a77-a757-bc11bbfa0337','cab0c412-cd35-4876-8333-27cf971b1036','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Card Players ♠️','Anyone up for a game of cards?','mixed',14,'public',false,3),
('a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','29f22b79-ca71-4a72-a011-29f4fd992705','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Cab Sharing 🚕','Let''s split cab fare from the station','any',12,'public',true,5),
('3e9c9f44-b99a-4c37-a15b-b0b303b1e657','29f22b79-ca71-4a72-a011-29f4fd992705','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Music Lovers 🎵','AirPods in, vibe together','any',9,'public',true,2),
('46faec95-6337-48a2-9ee6-6d3e4bc75347','2a5ff177-4154-4a27-ae0c-d7828e141029','656130ae-d5e3-46f8-aa53-21bcc35c28a8','First Timers 🌟','First time on this route? Join us!','any',9,'public',true,2),
('3bc17acf-ead0-469d-bd96-2b4cae0c61f3','17061f6f-be50-44a0-af22-debf59b246b4','a8dc8480-38ba-4e2c-879d-61e888626bf3','Alumni Connect 🤝','Same college? Let''s catch up','all_girls',7,'public',false,5),
('32f74a0e-62d2-40c0-823c-09d191582b41','17061f6f-be50-44a0-af22-debf59b246b4','a8dc8480-38ba-4e2c-879d-61e888626bf3','Night Owls 🦉','For those traveling overnight — let''s make it fun','any',5,'public',false,4),
('b178a2e6-e266-42a5-9d78-10f9b80d2d0a','3658226f-91db-4ae4-b9d7-20b9d367ce58','2f6e2744-67bd-49f0-b2a6-dc104146a963','Girls Squad ✨','Safe space for girls to connect and coordinate','all_girls',15,'public',false,5),
('9b4123d0-ca38-4e2a-bb8e-b2a641304a9a','1e91aa35-5420-4017-a29d-9bff0b89f8e9','d9757067-5e1b-41f2-8343-fe980c4bd506','IIT Gang 🎓','Only IITians, represent!','mixed',13,'public',true,3),
('9a920c61-0681-4e2d-8756-38a792a125bd','9a11861f-0b94-4ec8-82f5-b35d2e1823a1','ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Delhi Crew 🏙️','All Delhi folks in one place','mixed',5,'private',false,2),
('723e7aef-8324-4802-b3f1-5527010e5ca5','9a11861f-0b94-4ec8-82f5-b35d2e1823a1','ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Night Shift ☀️','Connecting night travelers','any',14,'private',false,4),
('d0499ef1-3e75-4d96-a87d-46fa5ca3646d','13d543f1-0bbb-44c0-9af6-23c61449e892','b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','Study Group 📚','Final year students connect here','all_girls',7,'public',true,4),
('53851c19-3a81-40fc-bb2f-77ad8c3b7d34','adc7e753-0103-485c-9e47-f3046bc38d19','637e185c-f1fe-4afe-af7f-b7b7e9b60edc','Card Players ♠️','Anyone up for a game of cards?','any',12,'public',false,4),
('1e3fc87a-cc15-46fb-be31-1745394e1130','212f75e6-5329-4efd-b275-b11adc94abe0','287cffed-71ac-4b66-8552-4aadd6cbf3dc','Music Lovers 🎵','AirPods in, vibe together','any',5,'public',false,4),
('2a995f9a-2448-418c-8fb5-8baede01dc7f','212f75e6-5329-4efd-b275-b11adc94abe0','287cffed-71ac-4b66-8552-4aadd6cbf3dc','First Timers 🌟','First time on this route? Join us!','any',14,'private',true,6),
('2485b98a-3013-43e0-bd66-68cfccd069c9','674ed3e0-2f82-425e-a6c9-89c2df478bac','0412662f-98b9-4fda-a1b4-4173f2c27ad4','Backpackers 🎒','Minimal luggage, maximum experience','all_boys',13,'public',false,3),
('81c6e387-c3bc-4e32-9f01-516793a0fdaf','0a8a42df-47a3-4090-b4ac-48fc58102e8b','955b7867-3dfe-4a2a-91ce-600feb668284','Night Owls 🦉','For those traveling overnight — let''s make it fun','any',12,'public',false,3),
('8251f57d-95f4-45b5-9dac-f251087c0665','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a','43eaa843-55b6-44b9-943a-f28e2f552f1f','Boys Only 🚀','Just the guys, no filter','mixed',13,'public',true,3),
('2170616b-461e-4ae5-ae7a-e11e13e67bb4','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a','43eaa843-55b6-44b9-943a-f28e2f552f1f','IIT Gang 🎓','Only IITians, represent!','all_boys',6,'private',true,2),
('b9cefe96-66e3-405b-9da1-d85a2b0e47d3','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','Chill Vibes 😎','No drama, just good company','mixed',12,'public',true,2),
('6ffca139-039c-4e54-92d0-7c852ce86147','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','Delhi Crew 🏙️','All Delhi folks in one place','all_boys',15,'public',true,3),
('4e1f9690-3456-44ec-88f4-f250cfe1e5cc','33c0d80a-0479-424a-bfe3-6d9516b223c0','dd32fda6-6a98-4538-a5c5-c21092fd78e4','Night Shift ☀️','Connecting night travelers','all_boys',6,'private',true,5),
('9441e9c1-c153-4c43-b8f2-756b9e52dd3e','33c0d80a-0479-424a-bfe3-6d9516b223c0','dd32fda6-6a98-4538-a5c5-c21092fd78e4','Study Group 📚','Final year students connect here','all_boys',7,'public',false,4);

-- ── Group Members ───────────────────────────────────────────────────────
INSERT INTO public.group_members (id,group_id,user_id,status,approved_at,approved_by) VALUES
('4ef216a7-268e-4d1e-97d0-3ecc0f5be067','a53b89dd-262c-484f-a187-18dc15f313c4','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37','approved','2026-05-12T09:58:23.478Z','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37'),
('0aba6707-6e85-4fdc-b483-f628b3ce6113','a53b89dd-262c-484f-a187-18dc15f313c4','a25875b0-b6f7-4bed-8424-c5eac04a8691','approved','2026-05-13T09:58:23.478Z','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37'),
('9db7f3e8-903c-4391-bc1e-51e1df693cb5','a53b89dd-262c-484f-a187-18dc15f313c4','fa7f925a-d508-4c83-93f0-d7d43c39b7b5','approved','2026-05-13T09:58:23.478Z','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37'),
('76a3d452-0247-45dc-a0b3-284f4fb80944','a53b89dd-262c-484f-a187-18dc15f313c4','f8cce76e-7552-4d2b-bd11-af60602755d9','approved','2026-05-15T09:58:23.478Z','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37'),
('f5cae66f-8c89-40ab-9196-062dd0910b05','a53b89dd-262c-484f-a187-18dc15f313c4','4ddbcbb8-2be7-4a7d-a880-545cc2975bbc','approved','2026-05-11T09:58:23.478Z','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37'),
('a2a83840-cf44-459a-a696-a72652fdf585','a53b89dd-262c-484f-a187-18dc15f313c4','2b779edc-8e5e-40e9-859e-2e1cd1dde32a','approved','2026-05-12T09:58:23.478Z','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37'),
('165126e7-a705-49d1-888f-ee7ba0021133','e8d5a104-9919-45c6-8853-d6efd0a483b1','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','approved','2026-05-13T09:58:23.479Z','f462e61a-1e7f-48e6-919d-5b596e3ed0d6'),
('18e10fb1-504b-4e04-8069-da0a49139a39','e8d5a104-9919-45c6-8853-d6efd0a483b1','a77f8394-6c66-4d6d-a16b-5013cfd88385','approved','2026-05-14T09:58:23.479Z','f462e61a-1e7f-48e6-919d-5b596e3ed0d6'),
('c27cdefb-37d8-484a-aa68-31a2392e7582','e8d5a104-9919-45c6-8853-d6efd0a483b1','ee82a7e1-8708-4359-9763-095bde24e848','approved','2026-05-13T09:58:23.479Z','f462e61a-1e7f-48e6-919d-5b596e3ed0d6'),
('8e1d5c9b-8fd1-4948-a8d2-39daf9b33c48','a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','approved','2026-05-12T09:58:23.479Z','f462e61a-1e7f-48e6-919d-5b596e3ed0d6'),
('22d62130-a4a4-468e-a536-144df570fdb2','a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','a77f8394-6c66-4d6d-a16b-5013cfd88385','approved','2026-05-13T09:58:23.479Z','f462e61a-1e7f-48e6-919d-5b596e3ed0d6'),
('36ba837f-2aca-4f40-9afd-5040949847d8','14d9523b-ad69-4b52-8a91-464b78d35ed9','83b12a8b-8a08-4e95-af91-78cc1032cff1','approved','2026-05-15T09:58:23.479Z','83b12a8b-8a08-4e95-af91-78cc1032cff1'),
('6411ba0c-6332-4b94-b9da-ac0dca4fc67c','14d9523b-ad69-4b52-8a91-464b78d35ed9','50176064-54ea-44ae-89f7-b378fda2df85','approved','2026-05-15T09:58:23.479Z','83b12a8b-8a08-4e95-af91-78cc1032cff1'),
('d89e75b6-1037-4bee-b785-b77347f97b18','14d9523b-ad69-4b52-8a91-464b78d35ed9','8988ce23-8368-4981-9d43-27369de4a5f8','approved','2026-05-13T09:58:23.479Z','83b12a8b-8a08-4e95-af91-78cc1032cff1'),
('b19821cc-c3a5-4ebc-92d7-c586a13b1855','14d9523b-ad69-4b52-8a91-464b78d35ed9','d66070b8-f157-4df9-82e0-ff9aa4d67252','approved','2026-05-15T09:58:23.479Z','83b12a8b-8a08-4e95-af91-78cc1032cff1'),
('0cfb8491-3b0f-4342-b452-9bca70d2549e','14d9523b-ad69-4b52-8a91-464b78d35ed9','d9b37982-f6b2-4b30-b48e-bdd24b288731','approved','2026-05-14T09:58:23.479Z','83b12a8b-8a08-4e95-af91-78cc1032cff1'),
('81bd1995-da7f-4f52-b4ee-a9843a2356fb','39c9ca91-9823-4bfa-99f5-3eced6575baa','0adaf0ce-abec-421d-bb57-037f7b332e1d','approved','2026-05-15T09:58:23.479Z','0adaf0ce-abec-421d-bb57-037f7b332e1d'),
('95165f9f-7a83-4817-988b-d745796726b6','39c9ca91-9823-4bfa-99f5-3eced6575baa','6fcce34a-52e2-4bf7-b1cd-143821d54bc3','approved','2026-05-15T09:58:23.479Z','0adaf0ce-abec-421d-bb57-037f7b332e1d'),
('d2e148db-9bd7-4b70-a8d3-81fa01a00919','39c9ca91-9823-4bfa-99f5-3eced6575baa','2780e8f1-3f06-4674-9215-3cd2bad13c03','approved','2026-05-13T09:58:23.479Z','0adaf0ce-abec-421d-bb57-037f7b332e1d'),
('587ffb72-be68-4f21-ac09-f61a329725ca','4968d6e8-ec57-454d-be23-45b064c61a7d','0adaf0ce-abec-421d-bb57-037f7b332e1d','approved','2026-05-14T09:58:23.479Z','0adaf0ce-abec-421d-bb57-037f7b332e1d'),
('9b3c38d7-867b-45b6-b00b-eddd98fcbdbd','4968d6e8-ec57-454d-be23-45b064c61a7d','6fcce34a-52e2-4bf7-b1cd-143821d54bc3','approved','2026-05-14T09:58:23.479Z','0adaf0ce-abec-421d-bb57-037f7b332e1d'),
('00999e8d-dade-4c38-988e-cd5e978a5c52','4968d6e8-ec57-454d-be23-45b064c61a7d','2780e8f1-3f06-4674-9215-3cd2bad13c03','approved','2026-05-12T09:58:23.479Z','0adaf0ce-abec-421d-bb57-037f7b332e1d'),
('d02ee699-256b-4e62-8f38-d70ea01e5e95','a2f10238-59ac-49f3-94f2-11e20d60cb1f','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','approved','2026-05-15T09:58:23.479Z','13cbbc82-15fc-4d8e-9da1-5d3301ec9466'),
('124fe6be-4a85-4e5c-8b40-079e2417e5a3','a2f10238-59ac-49f3-94f2-11e20d60cb1f','40b935b5-0ffc-407e-bc76-af36d8053bc2','approved','2026-05-12T09:58:23.479Z','13cbbc82-15fc-4d8e-9da1-5d3301ec9466'),
('3554c76d-d5a5-4766-ae4d-c241ecb4676d','fff34913-5402-4a77-a757-bc11bbfa0337','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','approved','2026-05-15T09:58:23.479Z','13cbbc82-15fc-4d8e-9da1-5d3301ec9466'),
('9b684d22-c4ef-4287-9f2b-7b8f82338964','fff34913-5402-4a77-a757-bc11bbfa0337','40b935b5-0ffc-407e-bc76-af36d8053bc2','approved','2026-05-11T09:58:23.479Z','13cbbc82-15fc-4d8e-9da1-5d3301ec9466'),
('731cc194-0b90-405c-a934-200d08bb1da7','fff34913-5402-4a77-a757-bc11bbfa0337','0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','approved','2026-05-12T09:58:23.479Z','13cbbc82-15fc-4d8e-9da1-5d3301ec9466'),
('0d31f801-49f2-4a43-ab1e-726a8d7595d0','a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','approved','2026-05-15T09:58:23.479Z','f8164cc9-a372-45bf-b6f4-d1a5ad115c82'),
('1afcf584-6ad5-4be1-88ab-a89540190b6e','a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','66e43919-33bb-4434-999f-22a3086cb7f4','approved','2026-05-12T09:58:23.479Z','f8164cc9-a372-45bf-b6f4-d1a5ad115c82'),
('c6419211-4ecf-4400-903a-c69ac69e6b44','a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','95ff91b3-6c6a-41d7-ac38-471ac85422da','approved','2026-05-15T09:58:23.479Z','f8164cc9-a372-45bf-b6f4-d1a5ad115c82'),
('89a473b7-9e89-4bd0-8b89-a33c514e7903','a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','599561ff-7b0e-4659-9b96-eedcd5842f34','approved','2026-05-11T09:58:23.479Z','f8164cc9-a372-45bf-b6f4-d1a5ad115c82'),
('c479b5e4-41b2-42c0-9a9a-65d309d4bd15','a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','73e3a251-b873-433b-9ebf-ba9b9c3b712d','approved','2026-05-12T09:58:23.479Z','f8164cc9-a372-45bf-b6f4-d1a5ad115c82'),
('83225856-bbe8-469d-a033-c1d185ad1306','3e9c9f44-b99a-4c37-a15b-b0b303b1e657','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','approved','2026-05-15T09:58:23.479Z','f8164cc9-a372-45bf-b6f4-d1a5ad115c82'),
('cbfeb9da-e78b-4441-90f4-06228dcb4f27','3e9c9f44-b99a-4c37-a15b-b0b303b1e657','66e43919-33bb-4434-999f-22a3086cb7f4','approved','2026-05-13T09:58:23.479Z','f8164cc9-a372-45bf-b6f4-d1a5ad115c82'),
('5e09d3c9-d1d2-4384-9fad-1464537c8175','46faec95-6337-48a2-9ee6-6d3e4bc75347','656130ae-d5e3-46f8-aa53-21bcc35c28a8','approved','2026-05-12T09:58:23.479Z','656130ae-d5e3-46f8-aa53-21bcc35c28a8'),
('43a078e0-31f5-4c3b-862e-5c9b35d481ae','46faec95-6337-48a2-9ee6-6d3e4bc75347','cf6c3a10-8460-4f52-8ee2-7a029042c5d7','approved','2026-05-11T09:58:23.479Z','656130ae-d5e3-46f8-aa53-21bcc35c28a8'),
('721a1086-6c88-4456-9853-22e6ad9e869e','3bc17acf-ead0-469d-bd96-2b4cae0c61f3','a8dc8480-38ba-4e2c-879d-61e888626bf3','approved','2026-05-14T09:58:23.479Z','a8dc8480-38ba-4e2c-879d-61e888626bf3'),
('838e7b17-62d2-4173-802c-90c050ae98ec','3bc17acf-ead0-469d-bd96-2b4cae0c61f3','ea7cb6f3-8697-4cdc-9b14-2132a630b8c2','approved','2026-05-14T09:58:23.479Z','a8dc8480-38ba-4e2c-879d-61e888626bf3'),
('0ca3cb34-5d1d-410b-9a95-fd1cb0100c55','3bc17acf-ead0-469d-bd96-2b4cae0c61f3','f3883e6b-8190-42eb-b94b-84c6dad5e909','approved','2026-05-12T09:58:23.479Z','a8dc8480-38ba-4e2c-879d-61e888626bf3'),
('f1077b7d-6b29-42c9-bef1-5c0b5f6f4869','3bc17acf-ead0-469d-bd96-2b4cae0c61f3','0e52e760-d927-49d5-b3f7-568970536394','approved','2026-05-12T09:58:23.479Z','a8dc8480-38ba-4e2c-879d-61e888626bf3'),
('f5b1e701-d721-421c-a801-981db0c76f5d','3bc17acf-ead0-469d-bd96-2b4cae0c61f3','c21a9c50-33b1-4700-a705-778fc04434f5','approved','2026-05-15T09:58:23.479Z','a8dc8480-38ba-4e2c-879d-61e888626bf3'),
('a3f5bb54-bc3e-4cf8-b5b9-f6153b459ae8','32f74a0e-62d2-40c0-823c-09d191582b41','a8dc8480-38ba-4e2c-879d-61e888626bf3','approved','2026-05-12T09:58:23.480Z','a8dc8480-38ba-4e2c-879d-61e888626bf3'),
('2a1db4b7-3a0b-4e38-8e91-269480183e06','32f74a0e-62d2-40c0-823c-09d191582b41','ea7cb6f3-8697-4cdc-9b14-2132a630b8c2','approved','2026-05-13T09:58:23.480Z','a8dc8480-38ba-4e2c-879d-61e888626bf3'),
('5c30344a-06b2-4e49-803a-2ce4d0dfdfaf','32f74a0e-62d2-40c0-823c-09d191582b41','f3883e6b-8190-42eb-b94b-84c6dad5e909','approved','2026-05-14T09:58:23.480Z','a8dc8480-38ba-4e2c-879d-61e888626bf3'),
('8ef5feae-561c-4a75-a65b-71f8c824ad41','32f74a0e-62d2-40c0-823c-09d191582b41','0e52e760-d927-49d5-b3f7-568970536394','approved','2026-05-12T09:58:23.480Z','a8dc8480-38ba-4e2c-879d-61e888626bf3'),
('6a01d0c7-3e58-4a87-a77f-826c60824f64','b178a2e6-e266-42a5-9d78-10f9b80d2d0a','2f6e2744-67bd-49f0-b2a6-dc104146a963','approved','2026-05-15T09:58:23.480Z','2f6e2744-67bd-49f0-b2a6-dc104146a963'),
('08c00d0f-8f8a-4b04-9a81-0d2780e11b48','b178a2e6-e266-42a5-9d78-10f9b80d2d0a','f798196b-807b-48df-a7c7-16961e01b088','approved','2026-05-14T09:58:23.480Z','2f6e2744-67bd-49f0-b2a6-dc104146a963'),
('2235c4d2-d982-4d68-8062-daa80667b03f','b178a2e6-e266-42a5-9d78-10f9b80d2d0a','7508a61b-7926-4b0b-9741-92bdf0a5b801','approved','2026-05-15T09:58:23.480Z','2f6e2744-67bd-49f0-b2a6-dc104146a963'),
('5109bd69-e0e8-4660-9117-f092af8818f3','b178a2e6-e266-42a5-9d78-10f9b80d2d0a','2a397b4f-1650-428d-806e-a9c929655ca1','approved','2026-05-12T09:58:23.480Z','2f6e2744-67bd-49f0-b2a6-dc104146a963'),
('9a54e2f9-8a39-4329-84cc-e5d350009e52','b178a2e6-e266-42a5-9d78-10f9b80d2d0a','53f4a2aa-025f-4886-b165-363912f8e678','approved','2026-05-13T09:58:23.480Z','2f6e2744-67bd-49f0-b2a6-dc104146a963'),
('952dab6d-7c7d-4d6a-b774-370261fe225e','9b4123d0-ca38-4e2a-bb8e-b2a641304a9a','d9757067-5e1b-41f2-8343-fe980c4bd506','approved','2026-05-11T09:58:23.480Z','d9757067-5e1b-41f2-8343-fe980c4bd506'),
('14e20ae7-a8e3-4285-9716-70ca09c78b75','9b4123d0-ca38-4e2a-bb8e-b2a641304a9a','f40d0980-d059-4c82-ad90-a1e19b1adf33','approved','2026-05-12T09:58:23.480Z','d9757067-5e1b-41f2-8343-fe980c4bd506'),
('38137759-41ce-4a81-a012-c23a65a6b35c','9b4123d0-ca38-4e2a-bb8e-b2a641304a9a','7c0dc257-7e74-4bd8-a9ea-4d8ec8391be8','approved','2026-05-12T09:58:23.480Z','d9757067-5e1b-41f2-8343-fe980c4bd506'),
('7b75b5c0-823e-4651-bca8-c256e85d6f4c','9a920c61-0681-4e2d-8756-38a792a125bd','ee99aa6b-48e7-4074-a4ba-fb16d76249d1','approved','2026-05-13T09:58:23.481Z','ee99aa6b-48e7-4074-a4ba-fb16d76249d1'),
('c5fc9ac7-6a68-43cc-9808-27088d89679e','9a920c61-0681-4e2d-8756-38a792a125bd','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','approved','2026-05-14T09:58:23.481Z','ee99aa6b-48e7-4074-a4ba-fb16d76249d1'),
('2b87fed4-aab7-4d3e-b882-29acf63b5efb','723e7aef-8324-4802-b3f1-5527010e5ca5','ee99aa6b-48e7-4074-a4ba-fb16d76249d1','approved','2026-05-12T09:58:23.481Z','ee99aa6b-48e7-4074-a4ba-fb16d76249d1'),
('ada239be-9df2-4653-8bf3-8a0e66ea300c','723e7aef-8324-4802-b3f1-5527010e5ca5','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','approved','2026-05-15T09:58:23.481Z','ee99aa6b-48e7-4074-a4ba-fb16d76249d1'),
('376f0aae-e80f-44fa-88e7-53abe7c1011f','723e7aef-8324-4802-b3f1-5527010e5ca5','25ce2843-8039-420c-bf21-cd436c59195d','approved','2026-05-15T09:58:23.481Z','ee99aa6b-48e7-4074-a4ba-fb16d76249d1'),
('49afc303-16a6-4232-ba98-54b754b5561c','723e7aef-8324-4802-b3f1-5527010e5ca5','f88cf7f0-e103-4db9-897c-f70b5544e51f','approved','2026-05-15T09:58:23.481Z','ee99aa6b-48e7-4074-a4ba-fb16d76249d1'),
('a28f1b21-7764-476b-9b77-1746cf52b818','d0499ef1-3e75-4d96-a87d-46fa5ca3646d','b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','approved','2026-05-13T09:58:23.481Z','b35a7ca3-a89c-4cc6-b280-9a6a2f796d26'),
('86076d53-64e0-4a6a-8dd5-6bdcb7d81b85','d0499ef1-3e75-4d96-a87d-46fa5ca3646d','f91fbdcd-2c3b-4ad6-b653-3e323af41f79','approved','2026-05-11T09:58:23.481Z','b35a7ca3-a89c-4cc6-b280-9a6a2f796d26'),
('ed8abf84-b3df-473e-9db3-e52772caf92b','d0499ef1-3e75-4d96-a87d-46fa5ca3646d','424c8082-c736-4860-9e90-24be1565854e','approved','2026-05-11T09:58:23.481Z','b35a7ca3-a89c-4cc6-b280-9a6a2f796d26'),
('e345c500-02a1-4504-8ab7-7d8fbd203ea2','d0499ef1-3e75-4d96-a87d-46fa5ca3646d','02ccdcd8-e45a-435d-bc04-86f2bb129992','approved','2026-05-11T09:58:23.481Z','b35a7ca3-a89c-4cc6-b280-9a6a2f796d26'),
('4ea8a3cf-e2f5-465a-8a2e-c9a44d1f3147','53851c19-3a81-40fc-bb2f-77ad8c3b7d34','637e185c-f1fe-4afe-af7f-b7b7e9b60edc','approved','2026-05-13T09:58:23.481Z','637e185c-f1fe-4afe-af7f-b7b7e9b60edc'),
('d7298c91-cd0d-46a0-b5be-f767a2fb74b7','53851c19-3a81-40fc-bb2f-77ad8c3b7d34','eb2d91e8-f6ed-45da-a4ba-63e5765c05fe','approved','2026-05-13T09:58:23.481Z','637e185c-f1fe-4afe-af7f-b7b7e9b60edc'),
('b5c9b6bf-0761-4c7e-bbc3-4154544dd23b','53851c19-3a81-40fc-bb2f-77ad8c3b7d34','e6dc2b9c-600e-455a-a943-7eb328f05212','approved','2026-05-13T09:58:23.481Z','637e185c-f1fe-4afe-af7f-b7b7e9b60edc'),
('fe310a43-25a7-4dbe-a19c-ff909de80f57','53851c19-3a81-40fc-bb2f-77ad8c3b7d34','575e3b18-220a-4b1b-975e-fbdaebcb3f92','approved','2026-05-13T09:58:23.481Z','637e185c-f1fe-4afe-af7f-b7b7e9b60edc'),
('8ec52b52-2bf7-42fa-939c-95931011e240','1e3fc87a-cc15-46fb-be31-1745394e1130','287cffed-71ac-4b66-8552-4aadd6cbf3dc','approved','2026-05-13T09:58:23.481Z','287cffed-71ac-4b66-8552-4aadd6cbf3dc'),
('1ab1260f-8e8d-421c-a0ff-f48aecb934ef','1e3fc87a-cc15-46fb-be31-1745394e1130','72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','approved','2026-05-13T09:58:23.481Z','287cffed-71ac-4b66-8552-4aadd6cbf3dc'),
('fe509e52-7292-4e5f-8095-164da6940b38','1e3fc87a-cc15-46fb-be31-1745394e1130','a484a03b-1cb9-4790-835b-64245238bcda','approved','2026-05-14T09:58:23.481Z','287cffed-71ac-4b66-8552-4aadd6cbf3dc'),
('d0d1135f-d23e-4486-9add-5f95afa801ca','1e3fc87a-cc15-46fb-be31-1745394e1130','97b03499-1962-4087-b478-48102f464a91','approved','2026-05-11T09:58:23.481Z','287cffed-71ac-4b66-8552-4aadd6cbf3dc'),
('51b371ee-1474-4628-95aa-cb19318673fc','2a995f9a-2448-418c-8fb5-8baede01dc7f','287cffed-71ac-4b66-8552-4aadd6cbf3dc','approved','2026-05-13T09:58:23.481Z','287cffed-71ac-4b66-8552-4aadd6cbf3dc'),
('e152bb88-6700-42a8-8f2d-5b38d787d189','2a995f9a-2448-418c-8fb5-8baede01dc7f','72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','approved','2026-05-12T09:58:23.481Z','287cffed-71ac-4b66-8552-4aadd6cbf3dc'),
('6712c559-ed62-4181-8789-4bbea9ba1594','2a995f9a-2448-418c-8fb5-8baede01dc7f','a484a03b-1cb9-4790-835b-64245238bcda','approved','2026-05-13T09:58:23.481Z','287cffed-71ac-4b66-8552-4aadd6cbf3dc'),
('6ff3f389-cb13-4ca4-b13f-8fc98c973289','2a995f9a-2448-418c-8fb5-8baede01dc7f','97b03499-1962-4087-b478-48102f464a91','approved','2026-05-12T09:58:23.481Z','287cffed-71ac-4b66-8552-4aadd6cbf3dc'),
('77bd99ea-943a-4972-a843-03dd8fc34d48','2a995f9a-2448-418c-8fb5-8baede01dc7f','73250fab-0868-4148-a348-e1654293fbab','approved','2026-05-14T09:58:23.481Z','287cffed-71ac-4b66-8552-4aadd6cbf3dc'),
('1bb3f5f9-adbd-404d-8f8b-11d722ac9bac','2a995f9a-2448-418c-8fb5-8baede01dc7f','7a348d56-91d8-4610-959b-0fc29c14686e','approved','2026-05-15T09:58:23.481Z','287cffed-71ac-4b66-8552-4aadd6cbf3dc'),
('169b7e7f-29d3-4438-bd1c-31d332be7d8b','2485b98a-3013-43e0-bd66-68cfccd069c9','0412662f-98b9-4fda-a1b4-4173f2c27ad4','approved','2026-05-14T09:58:23.482Z','0412662f-98b9-4fda-a1b4-4173f2c27ad4'),
('80d11c03-3bbb-4b46-9606-16f713ddaf5b','2485b98a-3013-43e0-bd66-68cfccd069c9','c6cac135-7583-4250-a794-189b972b8fc9','approved','2026-05-14T09:58:23.482Z','0412662f-98b9-4fda-a1b4-4173f2c27ad4'),
('a1ccb0c7-e6fd-457e-8393-03b1ce7d3252','2485b98a-3013-43e0-bd66-68cfccd069c9','be8c4d41-4490-481c-a7f9-6cb6f65d9866','approved','2026-05-11T09:58:23.482Z','0412662f-98b9-4fda-a1b4-4173f2c27ad4'),
('7159a0e3-6d60-41d5-948b-c938b909079e','81c6e387-c3bc-4e32-9f01-516793a0fdaf','955b7867-3dfe-4a2a-91ce-600feb668284','approved','2026-05-13T09:58:23.482Z','955b7867-3dfe-4a2a-91ce-600feb668284'),
('526b1aa2-d24a-44a1-aa82-0150267e4628','81c6e387-c3bc-4e32-9f01-516793a0fdaf','d98aa471-cb45-4263-936f-87b6a955f196','approved','2026-05-12T09:58:23.482Z','955b7867-3dfe-4a2a-91ce-600feb668284'),
('b973d458-685f-44f6-82eb-ba24822aa712','81c6e387-c3bc-4e32-9f01-516793a0fdaf','0863b4e8-e752-4c04-837e-419f091fe3dd','approved','2026-05-12T09:58:23.482Z','955b7867-3dfe-4a2a-91ce-600feb668284'),
('8261a20d-1fad-4a39-a783-c73ef9119ae1','8251f57d-95f4-45b5-9dac-f251087c0665','43eaa843-55b6-44b9-943a-f28e2f552f1f','approved','2026-05-15T09:58:23.482Z','43eaa843-55b6-44b9-943a-f28e2f552f1f'),
('40f7f897-94f5-40e7-980d-a32be4c51ff2','8251f57d-95f4-45b5-9dac-f251087c0665','4d0a152e-ea34-4f15-a703-309516ee6b4d','approved','2026-05-15T09:58:23.482Z','43eaa843-55b6-44b9-943a-f28e2f552f1f'),
('557f7c8d-9f5e-423e-97b1-3efec4200272','8251f57d-95f4-45b5-9dac-f251087c0665','6a3f8cad-ce91-4c37-985c-2c2a2a6f5851','approved','2026-05-13T09:58:23.482Z','43eaa843-55b6-44b9-943a-f28e2f552f1f'),
('e7e1d767-1034-488d-ae37-28f5d6b44854','2170616b-461e-4ae5-ae7a-e11e13e67bb4','43eaa843-55b6-44b9-943a-f28e2f552f1f','approved','2026-05-12T09:58:23.482Z','43eaa843-55b6-44b9-943a-f28e2f552f1f'),
('227c4e1a-b90b-4875-b77c-cd89b8c0a910','2170616b-461e-4ae5-ae7a-e11e13e67bb4','4d0a152e-ea34-4f15-a703-309516ee6b4d','approved','2026-05-15T09:58:23.482Z','43eaa843-55b6-44b9-943a-f28e2f552f1f'),
('80498ad5-2793-4dbc-8e6d-166190b6c476','b9cefe96-66e3-405b-9da1-d85a2b0e47d3','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','approved','2026-05-12T09:58:23.482Z','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7'),
('e7925b4a-ddac-486c-982a-2a608c905879','b9cefe96-66e3-405b-9da1-d85a2b0e47d3','63a974f3-6530-40b4-892f-1a620b38563e','approved','2026-05-14T09:58:23.482Z','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7'),
('3db43050-f76b-48ea-8f32-2739918289e0','6ffca139-039c-4e54-92d0-7c852ce86147','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','approved','2026-05-15T09:58:23.482Z','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7'),
('b9269d32-3c1c-440f-8430-bad08a3a1916','6ffca139-039c-4e54-92d0-7c852ce86147','63a974f3-6530-40b4-892f-1a620b38563e','approved','2026-05-15T09:58:23.482Z','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7'),
('c0b872e2-64e1-441c-859f-85c2e03a4d7a','6ffca139-039c-4e54-92d0-7c852ce86147','2daa15f6-74b4-4c83-9153-edb6c92317e8','approved','2026-05-14T09:58:23.482Z','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7'),
('5630ba74-7403-4c9e-a353-a63272c371c7','4e1f9690-3456-44ec-88f4-f250cfe1e5cc','dd32fda6-6a98-4538-a5c5-c21092fd78e4','approved','2026-05-14T09:58:23.482Z','dd32fda6-6a98-4538-a5c5-c21092fd78e4'),
('8c27a583-dfae-4554-acc9-6fa807075544','4e1f9690-3456-44ec-88f4-f250cfe1e5cc','6125af0e-06f0-464b-b752-bbbe0d5b6b27','approved','2026-05-13T09:58:23.482Z','dd32fda6-6a98-4538-a5c5-c21092fd78e4'),
('18032fb8-d9fb-4954-a5a1-7b1755cc0ca4','4e1f9690-3456-44ec-88f4-f250cfe1e5cc','f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','approved','2026-05-12T09:58:23.482Z','dd32fda6-6a98-4538-a5c5-c21092fd78e4'),
('5b492156-d157-4502-8ae1-af950aab7603','4e1f9690-3456-44ec-88f4-f250cfe1e5cc','e7a41005-3e6d-434f-bd4d-b38fcaf970d1','approved','2026-05-12T09:58:23.482Z','dd32fda6-6a98-4538-a5c5-c21092fd78e4'),
('331f0f18-6879-45d5-b411-264cfcdaeed8','4e1f9690-3456-44ec-88f4-f250cfe1e5cc','4f270acd-505b-44ce-86ba-538743a770e5','approved','2026-05-15T09:58:23.482Z','dd32fda6-6a98-4538-a5c5-c21092fd78e4'),
('87cefef6-b237-4424-b087-f516ba87e2df','9441e9c1-c153-4c43-b8f2-756b9e52dd3e','dd32fda6-6a98-4538-a5c5-c21092fd78e4','approved','2026-05-11T09:58:23.483Z','dd32fda6-6a98-4538-a5c5-c21092fd78e4'),
('b6e3d0f2-f66d-487a-8dd3-cf41cef27d43','9441e9c1-c153-4c43-b8f2-756b9e52dd3e','6125af0e-06f0-464b-b752-bbbe0d5b6b27','approved','2026-05-15T09:58:23.483Z','dd32fda6-6a98-4538-a5c5-c21092fd78e4'),
('6ee064ca-5ef0-4a7f-8ff1-27c680d120aa','9441e9c1-c153-4c43-b8f2-756b9e52dd3e','f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','approved','2026-05-13T09:58:23.483Z','dd32fda6-6a98-4538-a5c5-c21092fd78e4'),
('ec16eeaf-8924-40ba-a04d-4b8f56a0ac6d','9441e9c1-c153-4c43-b8f2-756b9e52dd3e','e7a41005-3e6d-434f-bd4d-b38fcaf970d1','approved','2026-05-14T09:58:23.483Z','dd32fda6-6a98-4538-a5c5-c21092fd78e4');

-- ── Messages ────────────────────────────────────────────────────────────
INSERT INTO public.messages (id,room_id,group_id,sender_id,content,message_type,created_at) VALUES
('7cb929f2-fa6a-47d1-90d6-95570e46c337','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'f8cce76e-7552-4d2b-bd11-af60602755d9','Same batch! Which branch?','text','2026-05-13T18:46:31.812Z'),
('925316ac-5b54-45b3-818e-d1b65471440b','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'3eaf7eed-95d3-4881-933f-3d1c82fca8ff','Just saw a peacock from the window 😂','text','2026-05-16T01:31:19.781Z'),
('31b9525f-8e3d-45e0-adc8-8136550e83b9','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'a25875b0-b6f7-4bed-8424-c5eac04a8691','Which coach are you all in?','text','2026-05-15T01:16:41.146Z'),
('cd18641e-cdfb-4cbc-987b-5fdac33adb68','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'a25875b0-b6f7-4bed-8424-c5eac04a8691','Which hostel are you in?','text','2026-05-13T13:00:30.307Z'),
('a75ebd93-5b23-4d7a-9c2d-aea3f4982212','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'f994f2cc-f321-49fe-8d75-3b7982d875d0','Will we reach on time or is there a delay?','text','2026-05-13T11:49:42.562Z'),
('0c7d879a-29d2-43f1-b438-cbc617ec1145','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'4ddbcbb8-2be7-4a7d-a880-545cc2975bbc','The platform number is 4, confirmed on the app','text','2026-05-14T02:15:35.970Z'),
('4f4e9860-1b1f-4ade-b097-951b745bbb43','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'3e1f24fe-b192-4b2b-8272-4cc3f5c14d37','The WiFi here is surprisingly good','text','2026-05-13T21:17:39.350Z'),
('09b3e2ef-0111-450b-a900-549c69b082a3','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'3eaf7eed-95d3-4881-933f-3d1c82fca8ff','First time traveling alone, this group is a lifesaver!','text','2026-05-15T11:23:11.911Z'),
('a4d4dfa3-2dc9-472e-aba5-134c78fa5287','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'fa7f925a-d508-4c83-93f0-d7d43c39b7b5','Which coach are you all in?','text','2026-05-14T05:55:41.047Z'),
('c4a46bf5-d50e-4c31-bd86-044deb9f0e02','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'f994f2cc-f321-49fe-8d75-3b7982d875d0','The platform number is 4, confirmed on the app','text','2026-05-15T08:09:14.876Z'),
('792ac5fe-f2d1-4ad0-90a6-ecd48ad7f57a','564ec993-187e-4aef-9acd-8adbd6836cad',NULL,'3eaf7eed-95d3-4881-933f-3d1c82fca8ff','The train is running 30 min late btw','text','2026-05-16T06:23:15.911Z'),
('95cc27d7-fcb9-4dee-9011-5d57ef9ebba8',NULL,'a53b89dd-262c-484f-a187-18dc15f313c4','fa7f925a-d508-4c83-93f0-d7d43c39b7b5','Will we reach on time or is there a delay?','text','2026-05-15T17:35:02.328Z'),
('06490882-2bf3-4c1b-9c2a-87c18cb81a27',NULL,'a53b89dd-262c-484f-a187-18dc15f313c4','3e1f24fe-b192-4b2b-8272-4cc3f5c14d37','Hey everyone! Anyone need help with luggage?','text','2026-05-16T09:56:06.428Z'),
('6db81755-e395-41e3-9323-5bd0458e6f67',NULL,'a53b89dd-262c-484f-a187-18dc15f313c4','fa7f925a-d508-4c83-93f0-d7d43c39b7b5','Which hostel are you in?','text','2026-05-15T17:38:24.819Z'),
('5e3b58a9-99eb-46b7-80ff-197aa1f8a44f',NULL,'a53b89dd-262c-484f-a187-18dc15f313c4','a25875b0-b6f7-4bed-8424-c5eac04a8691','Pantry car food is decent today','text','2026-05-16T06:59:33.777Z'),
('ded14c2a-d89e-40f0-9acb-21d7c02e6081',NULL,'a53b89dd-262c-484f-a187-18dc15f313c4','a25875b0-b6f7-4bed-8424-c5eac04a8691','Anyone else nervous about the semester starting?','text','2026-05-16T08:50:54.813Z'),
('3a67f773-8e30-47fc-90af-474fe3db8e66',NULL,'a53b89dd-262c-484f-a187-18dc15f313c4','a25875b0-b6f7-4bed-8424-c5eac04a8691','First time traveling alone, this group is a lifesaver!','text','2026-05-14T13:01:41.559Z'),
('87ca72d3-aa65-4b43-ae65-581cdd125ca5',NULL,'a53b89dd-262c-484f-a187-18dc15f313c4','f8cce76e-7552-4d2b-bd11-af60602755d9','What time does this reach the destination?','text','2026-05-14T10:38:36.047Z'),
('9eb47040-cfc0-4741-a96d-d24150e19384','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'f462e61a-1e7f-48e6-919d-5b596e3ed0d6','There is a nice sunset view from the left side right now!','text','2026-05-15T16:52:59.539Z'),
('939bf20f-5f2d-40ef-8a6b-db1221ffef1a','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'ee82a7e1-8708-4359-9763-095bde24e848','Hey everyone! Anyone need help with luggage?','text','2026-05-15T14:15:10.231Z'),
('20c722c0-43ed-4a1e-ad75-d1c6d413b3b8','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'f462e61a-1e7f-48e6-919d-5b596e3ed0d6','There is a nice sunset view from the left side right now!','text','2026-05-14T00:52:25.872Z'),
('9a3f9d03-8157-4468-a91f-85d3b6a645b0','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'7ea642d5-8df7-4ae1-a624-5daa8af23a34','Just joined this group, hi everyone 👋','text','2026-05-13T15:57:25.319Z'),
('7790fe77-4cfa-46db-a52c-3552940a2643','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'ee82a7e1-8708-4359-9763-095bde24e848','Which coach are you all in?','text','2026-05-16T09:07:45.249Z'),
('83015b4e-9001-4017-ba92-7fb342d32a98','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'f462e61a-1e7f-48e6-919d-5b596e3ed0d6','There is a nice sunset view from the left side right now!','text','2026-05-16T04:50:22.560Z'),
('e90b5c84-4f56-4cdd-9b71-ad150e3b527f','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'a77f8394-6c66-4d6d-a16b-5013cfd88385','Anyone want to play cards?','text','2026-05-14T17:47:53.482Z'),
('d1c3ec58-aeaa-47f6-8ec6-10a4979ea2d3','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'ee82a7e1-8708-4359-9763-095bde24e848','Hey, are you a BITS student?','text','2026-05-14T19:31:42.111Z'),
('3e20ce6b-18b2-4f70-8f8b-524a1c2afbdc','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'f462e61a-1e7f-48e6-919d-5b596e3ed0d6','The train is running 30 min late btw','text','2026-05-16T07:12:46.154Z'),
('d8668050-52da-43b2-b522-8f347503f6fa','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'f462e61a-1e7f-48e6-919d-5b596e3ed0d6','Hey, are you a BITS student?','text','2026-05-14T21:52:17.918Z'),
('da825649-c191-4269-95e7-a2de359ef73f','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'7ea642d5-8df7-4ae1-a624-5daa8af23a34','What time does this reach the destination?','text','2026-05-14T22:26:27.199Z'),
('d184f34d-9f05-4e64-826e-5f2e24f03f32',NULL,'e8d5a104-9919-45c6-8853-d6efd0a483b1','ee82a7e1-8708-4359-9763-095bde24e848','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-15T05:24:04.684Z'),
('bdd5d765-9846-4856-b3c3-44fc03caf718',NULL,'e8d5a104-9919-45c6-8853-d6efd0a483b1','ee82a7e1-8708-4359-9763-095bde24e848','Pantry car food is decent today','text','2026-05-14T23:48:42.836Z'),
('1dd74bc2-7613-4a66-b9de-327c000014db',NULL,'e8d5a104-9919-45c6-8853-d6efd0a483b1','a77f8394-6c66-4d6d-a16b-5013cfd88385','Just saw a peacock from the window 😂','text','2026-05-15T21:03:58.784Z'),
('fbbe698d-f52f-4a9c-bcde-8d8535f5ed35',NULL,'e8d5a104-9919-45c6-8853-d6efd0a483b1','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','Anyone else nervous about the semester starting?','text','2026-05-15T03:29:45.493Z'),
('d52a23b4-4461-4fc4-900b-bf2a8e26dff3',NULL,'e8d5a104-9919-45c6-8853-d6efd0a483b1','ee82a7e1-8708-4359-9763-095bde24e848','We should plan a meetup once we reach!','text','2026-05-15T02:17:03.932Z'),
('4aa2cbd1-0c71-40be-bf18-35db8a017f19','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'ee82a7e1-8708-4359-9763-095bde24e848','Can someone save a seat? BRB getting water','text','2026-05-15T16:15:05.120Z'),
('f3230ed6-9709-43b6-ba96-b8c9610c34c0','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'f462e61a-1e7f-48e6-919d-5b596e3ed0d6','What time does this reach the destination?','text','2026-05-14T03:19:42.353Z'),
('b3a3d69e-f91c-4ee4-a3c8-e5d2c4048e5b','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'7ea642d5-8df7-4ae1-a624-5daa8af23a34','Confirmed — upper berth in coach B4','text','2026-05-15T00:50:00.108Z'),
('fa0e851b-ba3a-4a4e-934d-4d62a2bd253d','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'ee82a7e1-8708-4359-9763-095bde24e848','There is a nice sunset view from the left side right now!','text','2026-05-15T00:40:29.550Z'),
('b1fca2db-4dc6-4fcf-bdad-364dbd8a43ae','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'7ea642d5-8df7-4ae1-a624-5daa8af23a34','The train is running 30 min late btw','text','2026-05-15T06:11:38.720Z'),
('54f13df0-2382-41c2-8f68-8ec6aa72c951','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'f462e61a-1e7f-48e6-919d-5b596e3ed0d6','Do not forget to check your PNR status','text','2026-05-13T17:17:26.945Z'),
('e1020156-083c-4c8b-8454-f3735e9b64d9','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'a77f8394-6c66-4d6d-a16b-5013cfd88385','Confirmed — upper berth in coach B4','text','2026-05-13T15:52:28.414Z'),
('dc6cb250-5084-49a8-9bf0-9a60557baf6e','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'a77f8394-6c66-4d6d-a16b-5013cfd88385','Same batch! Which branch?','text','2026-05-13T18:00:09.669Z'),
('67f0c2c5-c8dc-498a-bbd6-ddb6c547e623','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'f462e61a-1e7f-48e6-919d-5b596e3ed0d6','Do not forget to check your PNR status','text','2026-05-15T11:36:08.884Z'),
('6963a346-9a5e-42ff-a4fa-0086ecd2e900','0044eb37-07f3-4329-afc0-e0142cd1e716',NULL,'ee82a7e1-8708-4359-9763-095bde24e848','What time does this reach the destination?','text','2026-05-14T01:48:04.841Z'),
('d4321791-ded2-4fe0-a3e1-b9a85d4a33c1',NULL,'a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','We can share a cab if you are going towards the same direction','text','2026-05-15T05:42:29.134Z'),
('dd722b5e-b2e8-4eea-8d29-6f22653bf35f',NULL,'a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','First time traveling alone, this group is a lifesaver!','text','2026-05-15T22:00:41.050Z'),
('efaea045-e0d7-4a85-90ab-f05162a14c45',NULL,'a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','Just saw a peacock from the window 😂','text','2026-05-16T05:20:48.467Z'),
('e68b1cca-7b13-49c0-babf-fe793cf7e8aa',NULL,'a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','We can share a cab if you are going towards the same direction','text','2026-05-15T06:04:49.446Z'),
('d78f4095-ae75-4063-a013-a5ed7f6a3c62',NULL,'a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','f462e61a-1e7f-48e6-919d-5b596e3ed0d6','The WiFi here is surprisingly good','text','2026-05-14T16:31:03.486Z'),
('00b413a4-f897-4fcc-a0de-acdbee78580a',NULL,'a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','a77f8394-6c66-4d6d-a16b-5013cfd88385','Will we reach on time or is there a delay?','text','2026-05-15T22:13:11.616Z'),
('87b19eac-4cc4-474d-aa77-c2692e83aba1',NULL,'a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','a77f8394-6c66-4d6d-a16b-5013cfd88385','Anyone else nervous about the semester starting?','text','2026-05-14T16:49:51.344Z'),
('07c01681-5527-4151-be3b-f3a0958810e4',NULL,'a9c89e4d-26c1-40cd-9f17-c85598c1d7e8','a77f8394-6c66-4d6d-a16b-5013cfd88385','We should plan a meetup once we reach!','text','2026-05-15T12:41:44.199Z'),
('c4b1bb66-672a-403a-8da7-8c6650076d91','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'f5884ea3-0f91-4a69-98b6-40d11702a6bd','Hey everyone! Anyone need help with luggage?','text','2026-05-14T22:41:53.226Z'),
('f69d0bd0-eded-4cae-b234-cab839ce9f0d','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'8988ce23-8368-4981-9d43-27369de4a5f8','Hey, are you a BITS student?','text','2026-05-14T14:28:30.208Z'),
('616223c7-6859-4742-a93c-cb3396b2c2a4','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'d66070b8-f157-4df9-82e0-ff9aa4d67252','The train is running 30 min late btw','text','2026-05-14T11:28:12.500Z'),
('b21a7a88-c1b4-479c-ac4a-4daeff874ef9','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'d66070b8-f157-4df9-82e0-ff9aa4d67252','Is the AC working in S4? Feels warm','text','2026-05-15T16:02:00.107Z'),
('2d0d6c01-3edb-423b-b224-b28fac1a990f','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'d9b37982-f6b2-4b30-b48e-bdd24b288731','Which coach are you all in?','text','2026-05-15T03:35:17.489Z'),
('1f339ce4-a3f8-4c87-9573-147c3b328ddb','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'8988ce23-8368-4981-9d43-27369de4a5f8','The WiFi here is surprisingly good','text','2026-05-13T23:09:15.702Z'),
('a575984c-ee4a-44ee-a2cc-2f7792b703bb','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'f5884ea3-0f91-4a69-98b6-40d11702a6bd','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-13T17:05:27.316Z'),
('6548451b-edcb-427e-bbd7-ed48503895b5','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'d9b37982-f6b2-4b30-b48e-bdd24b288731','The WiFi here is surprisingly good','text','2026-05-13T20:10:20.268Z'),
('56f05943-31ba-44f1-be86-6d751072878b','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'8988ce23-8368-4981-9d43-27369de4a5f8','Has anyone booked a cab from the station?','text','2026-05-13T20:17:04.182Z'),
('f5f261ec-fe49-451c-ad96-d8294790964a','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'d9b37982-f6b2-4b30-b48e-bdd24b288731','Anyone need a phone charger? I have a multi-port','text','2026-05-14T01:37:59.164Z'),
('ccb2ff91-d56f-40bc-ba93-983f479e112b','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'50176064-54ea-44ae-89f7-b378fda2df85','Anyone from Delhi NCR here?','text','2026-05-14T20:59:42.793Z'),
('effe6f77-57f8-4df7-9421-25777f5f5346','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'83b12a8b-8a08-4e95-af91-78cc1032cff1','I have extra snacks if anyone wants','text','2026-05-16T01:11:45.568Z'),
('e5b163be-4096-45b1-8c16-325adb9dd706','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'8ede2d73-0ca1-4412-8704-0a0144d56dc6','Same batch! Which branch?','text','2026-05-15T12:05:44.139Z'),
('44e407d2-d311-4d15-b3d8-803fe89f92b6','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'83b12a8b-8a08-4e95-af91-78cc1032cff1','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-15T15:35:44.339Z'),
('bffeee1f-94aa-49ae-bf72-f9fbd2e1e6cb','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'f5884ea3-0f91-4a69-98b6-40d11702a6bd','Just joined this group, hi everyone 👋','text','2026-05-16T02:08:17.148Z'),
('f04efc4e-e5d1-4f72-b227-7c13b4554dce','bdcf88d5-4c97-49d1-a3e4-17ca7362bea7',NULL,'f5884ea3-0f91-4a69-98b6-40d11702a6bd','There is a nice sunset view from the left side right now!','text','2026-05-13T18:44:12.509Z'),
('d61b325d-92db-4147-ab11-bb43242e73ae',NULL,'14d9523b-ad69-4b52-8a91-464b78d35ed9','8988ce23-8368-4981-9d43-27369de4a5f8','Anyone want to play cards?','text','2026-05-14T20:03:21.310Z'),
('5ece9aff-a4d3-41e5-ad61-dc3a8fcc9213',NULL,'14d9523b-ad69-4b52-8a91-464b78d35ed9','8988ce23-8368-4981-9d43-27369de4a5f8','Same batch! Which branch?','text','2026-05-14T23:04:01.877Z'),
('e3ed4100-f886-4a5a-b20a-4fd9f4827867',NULL,'14d9523b-ad69-4b52-8a91-464b78d35ed9','8988ce23-8368-4981-9d43-27369de4a5f8','Which coach are you all in?','text','2026-05-15T10:37:47.402Z'),
('4d08dd6a-fcf7-4c49-8bba-93269c072e0b',NULL,'14d9523b-ad69-4b52-8a91-464b78d35ed9','83b12a8b-8a08-4e95-af91-78cc1032cff1','Which hostel are you in?','text','2026-05-16T02:12:24.499Z'),
('4c0cca64-97a3-458d-ada7-60b696f5b69e',NULL,'14d9523b-ad69-4b52-8a91-464b78d35ed9','d66070b8-f157-4df9-82e0-ff9aa4d67252','Has anyone booked a cab from the station?','text','2026-05-16T05:32:07.929Z'),
('c4632181-b5be-41e3-a6c4-19a24e36edbd',NULL,'14d9523b-ad69-4b52-8a91-464b78d35ed9','83b12a8b-8a08-4e95-af91-78cc1032cff1','Anyone from Delhi NCR here?','text','2026-05-14T13:30:26.658Z'),
('56b2d2e6-f562-4b3b-bb8b-36b6e4a1007e',NULL,'14d9523b-ad69-4b52-8a91-464b78d35ed9','83b12a8b-8a08-4e95-af91-78cc1032cff1','Hey everyone! Anyone need help with luggage?','text','2026-05-14T21:41:01.793Z'),
('e3ae0d7d-0b56-4bae-9c1f-2071689426ee','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Anyone from Delhi NCR here?','text','2026-05-14T19:14:53.127Z'),
('beeb8d82-1af1-49a8-805e-d87c0c7bed82','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'6fcce34a-52e2-4bf7-b1cd-143821d54bc3','The train is running 30 min late btw','text','2026-05-13T20:14:22.593Z'),
('5cba7e93-c55a-4dbb-a7b5-a88558645310','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Hey everyone! Anyone need help with luggage?','text','2026-05-14T09:15:25.594Z'),
('bfbbc5e1-13d5-4d07-b325-2ef44ddc2188','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','What time does this reach the destination?','text','2026-05-14T23:29:03.025Z'),
('cfc6bb3b-3b79-48c3-92b3-0ed65bb8fe87','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-14T02:20:42.614Z'),
('685e668d-a187-474a-9a1a-797df8da100d','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'2780e8f1-3f06-4674-9215-3cd2bad13c03','Will we reach on time or is there a delay?','text','2026-05-14T11:38:13.674Z'),
('4c251c78-6826-4b83-8d75-196136ef269c','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'6fcce34a-52e2-4bf7-b1cd-143821d54bc3','Hey, are you a BITS student?','text','2026-05-15T13:54:58.724Z'),
('d7731ea4-782b-435e-8f0f-2d2dc1e3bfb5','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'2780e8f1-3f06-4674-9215-3cd2bad13c03','The WiFi here is surprisingly good','text','2026-05-16T08:34:49.242Z'),
('cef49c6b-fed9-43f6-b589-c0afe5e7a376','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'2780e8f1-3f06-4674-9215-3cd2bad13c03','First time traveling alone, this group is a lifesaver!','text','2026-05-15T16:37:41.970Z'),
('31e1b962-2da2-4145-9d04-ec6ea44bed95','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Will we reach on time or is there a delay?','text','2026-05-14T02:57:05.428Z'),
('0b3cde60-1da8-4bc6-8b01-4a31daa21302',NULL,'39c9ca91-9823-4bfa-99f5-3eced6575baa','2780e8f1-3f06-4674-9215-3cd2bad13c03','Has anyone booked a cab from the station?','text','2026-05-15T19:38:52.112Z'),
('8f1b9a48-3510-481b-8583-4679190e0bcb',NULL,'39c9ca91-9823-4bfa-99f5-3eced6575baa','6fcce34a-52e2-4bf7-b1cd-143821d54bc3','Anyone want to play cards?','text','2026-05-16T06:58:39.363Z'),
('6c1c38c6-6043-44ab-a4d4-5b3209a2f789',NULL,'39c9ca91-9823-4bfa-99f5-3eced6575baa','6fcce34a-52e2-4bf7-b1cd-143821d54bc3','There is a nice sunset view from the left side right now!','text','2026-05-15T05:44:04.512Z'),
('0e7ef0c9-8b72-4e63-9404-bcfd1000d0ec',NULL,'39c9ca91-9823-4bfa-99f5-3eced6575baa','0adaf0ce-abec-421d-bb57-037f7b332e1d','I have extra snacks if anyone wants','text','2026-05-14T18:51:33.295Z'),
('520523d5-7463-4259-b7b5-78c09e98a7ea',NULL,'39c9ca91-9823-4bfa-99f5-3eced6575baa','0adaf0ce-abec-421d-bb57-037f7b332e1d','Anyone want to play cards?','text','2026-05-15T17:40:08.116Z'),
('bbf1ce21-5af1-44d5-9109-836156f410e3','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-14T13:37:05.864Z'),
('7f1b9b41-8f59-41e2-a51c-df071f68922c','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'2780e8f1-3f06-4674-9215-3cd2bad13c03','Just joined this group, hi everyone 👋','text','2026-05-14T21:40:02.122Z'),
('ab46601b-22a6-4fde-99ec-b8677dfe4beb','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Has anyone booked a cab from the station?','text','2026-05-14T06:10:05.760Z'),
('4f881d26-f243-42d0-899f-0630a2e607ae','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'2780e8f1-3f06-4674-9215-3cd2bad13c03','The platform number is 4, confirmed on the app','text','2026-05-13T21:17:14.086Z'),
('2450d478-710d-4d0d-9e3a-427257be0ed0','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Is the AC working in S4? Feels warm','text','2026-05-15T04:06:37.189Z'),
('579ff5bd-cf75-4144-b97d-ce26b4a9669f','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Anyone else nervous about the semester starting?','text','2026-05-16T06:36:21.433Z'),
('07918d43-68fd-4ab6-876c-6096fb09e253','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','We should plan a meetup once we reach!','text','2026-05-15T10:45:57.408Z'),
('90be9b8e-7adb-4576-a188-867f65ddaf6e','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'2780e8f1-3f06-4674-9215-3cd2bad13c03','The platform number is 4, confirmed on the app','text','2026-05-14T14:07:07.268Z'),
('941658db-f446-49de-8dbc-9f6e33d19683','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'2780e8f1-3f06-4674-9215-3cd2bad13c03','Pantry car food is decent today','text','2026-05-16T03:13:02.016Z'),
('0e55c9d3-93fc-412d-a136-4c2dac79de28','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Which coach are you all in?','text','2026-05-15T15:30:26.641Z'),
('75cd75a9-25e3-44dc-8621-1946cab36793','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Same batch! Which branch?','text','2026-05-14T08:16:25.883Z'),
('80a42eb3-b9ab-46e3-97cd-ff8a6568de0f','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Which coach are you all in?','text','2026-05-14T16:22:45.128Z'),
('c5826463-7e59-49b2-84d9-3e053d97509f','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'2780e8f1-3f06-4674-9215-3cd2bad13c03','Hey, are you a BITS student?','text','2026-05-14T01:10:06.582Z'),
('5711d11d-7cdb-4a09-adc0-40c70b94f213','9b9b7cd6-4edd-4caf-bcac-8cbb79fb1137',NULL,'0adaf0ce-abec-421d-bb57-037f7b332e1d','Anyone else nervous about the semester starting?','text','2026-05-15T16:15:45.724Z'),
('463b7347-e54a-48e1-993f-ef3d931de921',NULL,'4968d6e8-ec57-454d-be23-45b064c61a7d','2780e8f1-3f06-4674-9215-3cd2bad13c03','Confirmed — upper berth in coach B4','text','2026-05-15T10:43:16.637Z'),
('f285b515-f34e-4477-b9d6-a0930e0bd21d',NULL,'4968d6e8-ec57-454d-be23-45b064c61a7d','0adaf0ce-abec-421d-bb57-037f7b332e1d','What time does this reach the destination?','text','2026-05-15T00:26:36.334Z'),
('2e4725fc-f227-4356-a896-66b8f90e9e0c',NULL,'4968d6e8-ec57-454d-be23-45b064c61a7d','6fcce34a-52e2-4bf7-b1cd-143821d54bc3','The train is running 30 min late btw','text','2026-05-16T01:04:18.311Z'),
('b4991c4f-b4f1-4bf9-8d0b-59746a01f8c7',NULL,'4968d6e8-ec57-454d-be23-45b064c61a7d','0adaf0ce-abec-421d-bb57-037f7b332e1d','We can share a cab if you are going towards the same direction','text','2026-05-15T21:20:30.805Z'),
('7530e84a-5551-4544-b495-085f8bdb8677',NULL,'4968d6e8-ec57-454d-be23-45b064c61a7d','2780e8f1-3f06-4674-9215-3cd2bad13c03','We should plan a meetup once we reach!','text','2026-05-14T14:55:12.030Z'),
('7dd2ea54-c04c-4d29-a2f3-8d858e114c08',NULL,'4968d6e8-ec57-454d-be23-45b064c61a7d','6fcce34a-52e2-4bf7-b1cd-143821d54bc3','Anyone want to play cards?','text','2026-05-15T11:29:22.544Z'),
('af8da3c5-9d45-4056-962d-7ccd48c62d1a',NULL,'4968d6e8-ec57-454d-be23-45b064c61a7d','6fcce34a-52e2-4bf7-b1cd-143821d54bc3','The platform number is 4, confirmed on the app','text','2026-05-15T18:17:52.410Z'),
('ab7c4111-c1bc-46fd-9905-e305db96b3fa',NULL,'4968d6e8-ec57-454d-be23-45b064c61a7d','0adaf0ce-abec-421d-bb57-037f7b332e1d','Same batch! Which branch?','text','2026-05-15T16:59:32.078Z'),
('fe11f327-bc71-4455-87ed-c63e35de0405',NULL,'4968d6e8-ec57-454d-be23-45b064c61a7d','2780e8f1-3f06-4674-9215-3cd2bad13c03','Pantry car food is decent today','text','2026-05-15T05:19:50.798Z'),
('90e9b342-5d6d-46ff-b4a0-c8b5a1ba15b1','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-14T14:49:29.589Z'),
('01d3b62c-8c35-4380-a026-46dc251e6930','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','Which coach are you all in?','text','2026-05-15T08:47:06.054Z'),
('37fb4a55-3dcf-4f1b-943f-f44cd4683b81','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Pantry car food is decent today','text','2026-05-13T10:58:26.061Z'),
('60f49a84-0de9-4c33-add8-80d0ca07b706','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'13cbbc82-15fc-4d8e-9da1-5d3301ec9466','We should plan a meetup once we reach!','text','2026-05-16T08:33:43.842Z'),
('3483d4b4-5d97-47e0-b145-90d542da881e','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'40b935b5-0ffc-407e-bc76-af36d8053bc2','There is a nice sunset view from the left side right now!','text','2026-05-13T16:24:13.069Z'),
('fba6c3f5-5f6e-4528-b332-c15dc4ace98a','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'40b935b5-0ffc-407e-bc76-af36d8053bc2','I have extra snacks if anyone wants','text','2026-05-15T00:18:55.993Z'),
('2eec702f-cb32-410f-8191-1fdf224719de','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'40b935b5-0ffc-407e-bc76-af36d8053bc2','Do not forget to check your PNR status','text','2026-05-14T07:01:57.992Z'),
('cb4f2da5-60ad-42bb-93ae-f739a1c95ac3','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Will we reach on time or is there a delay?','text','2026-05-13T20:50:58.465Z'),
('e4cf4c6e-2814-4955-8d7f-6af6be73bd9a','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'40b935b5-0ffc-407e-bc76-af36d8053bc2','Anyone from Delhi NCR here?','text','2026-05-13T10:39:12.004Z'),
('0b25fde7-b4b9-4aeb-8aaa-02ebda240605','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Anyone from Delhi NCR here?','text','2026-05-15T20:15:19.776Z'),
('a343579e-bad0-4403-b44e-90dfdaa9e60f',NULL,'a2f10238-59ac-49f3-94f2-11e20d60cb1f','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Anyone want to play cards?','text','2026-05-15T18:12:29.857Z'),
('fb38313b-5b5b-4d16-a8cb-c318cd8e7658',NULL,'a2f10238-59ac-49f3-94f2-11e20d60cb1f','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Confirmed — upper berth in coach B4','text','2026-05-14T18:41:12.517Z'),
('14c3536e-ab79-459c-8ad1-4e4f4154e8a4',NULL,'a2f10238-59ac-49f3-94f2-11e20d60cb1f','40b935b5-0ffc-407e-bc76-af36d8053bc2','Anyone want to play cards?','text','2026-05-15T22:07:33.923Z'),
('7a5cb661-1c1b-4ce0-b046-f12bdc62d480',NULL,'a2f10238-59ac-49f3-94f2-11e20d60cb1f','40b935b5-0ffc-407e-bc76-af36d8053bc2','There is a nice sunset view from the left side right now!','text','2026-05-15T11:33:43.042Z'),
('5501f625-d65d-474d-811f-1f371c9fb3af',NULL,'a2f10238-59ac-49f3-94f2-11e20d60cb1f','40b935b5-0ffc-407e-bc76-af36d8053bc2','We can share a cab if you are going towards the same direction','text','2026-05-14T20:30:41.386Z'),
('80dcc94d-45e2-4207-a509-ef140210105e',NULL,'a2f10238-59ac-49f3-94f2-11e20d60cb1f','40b935b5-0ffc-407e-bc76-af36d8053bc2','Is the AC working in S4? Feels warm','text','2026-05-15T00:07:00.694Z'),
('93286359-f75d-4fdc-a040-637653d639f0',NULL,'a2f10238-59ac-49f3-94f2-11e20d60cb1f','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','There is a nice sunset view from the left side right now!','text','2026-05-15T03:23:34.607Z'),
('58010ebd-6e9a-4562-8193-986f2140b406',NULL,'a2f10238-59ac-49f3-94f2-11e20d60cb1f','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Pantry car food is decent today','text','2026-05-16T00:54:44.425Z'),
('30f9cc72-27ac-4108-9d1c-ea66d66b53df',NULL,'a2f10238-59ac-49f3-94f2-11e20d60cb1f','40b935b5-0ffc-407e-bc76-af36d8053bc2','We should plan a meetup once we reach!','text','2026-05-14T11:37:40.842Z'),
('75bb81b9-9c3c-4d82-ad22-f92c4248e345','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'40b935b5-0ffc-407e-bc76-af36d8053bc2','Can someone save a seat? BRB getting water','text','2026-05-16T02:26:00.740Z'),
('c77e6ad7-d28c-499f-8940-6173142a6773','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','What time does this reach the destination?','text','2026-05-15T03:09:02.932Z'),
('c2ade8b4-c5ac-4168-bcb9-ee882c40a0e0','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'13cbbc82-15fc-4d8e-9da1-5d3301ec9466','The train is running 30 min late btw','text','2026-05-14T09:54:35.241Z'),
('ce799a9e-ebbb-4283-bbf1-6d625441e294','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'40b935b5-0ffc-407e-bc76-af36d8053bc2','Which coach are you all in?','text','2026-05-15T18:39:01.655Z'),
('c03bd8dc-4c39-487f-8f46-2b9880f473c1','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','Has anyone booked a cab from the station?','text','2026-05-15T05:51:07.676Z'),
('efbe0569-6bfc-48cf-817f-508bc0a1b979','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','We should plan a meetup once we reach!','text','2026-05-16T08:42:48.477Z'),
('129cd492-2dba-461a-bd03-2c38a1327c99','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','Has anyone booked a cab from the station?','text','2026-05-13T14:04:37.916Z'),
('d4179693-5155-4288-ac5c-0158c5c84dec','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'40b935b5-0ffc-407e-bc76-af36d8053bc2','We can share a cab if you are going towards the same direction','text','2026-05-14T01:20:35.932Z'),
('97defc4f-c471-4ea9-8ab6-665d558dea58','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'40b935b5-0ffc-407e-bc76-af36d8053bc2','Great trip so far, met some awesome people here!','text','2026-05-14T01:03:52.443Z'),
('b4d0bb0c-ae1d-4807-baa7-c1c5ae9edc3a','cab0c412-cd35-4876-8333-27cf971b1036',NULL,'0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','Just saw a peacock from the window 😂','text','2026-05-15T09:11:04.958Z'),
('d99b5f4b-d9fa-4137-b8d8-d5944fb5d549',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','40b935b5-0ffc-407e-bc76-af36d8053bc2','Great trip so far, met some awesome people here!','text','2026-05-15T12:29:46.737Z'),
('f19cb6ba-ddd9-4578-87a8-1c36fb2b02db',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','The platform number is 4, confirmed on the app','text','2026-05-16T05:04:20.120Z'),
('bc975e99-b653-40e7-897d-b5a49258b37c',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','40b935b5-0ffc-407e-bc76-af36d8053bc2','Is the AC working in S4? Feels warm','text','2026-05-16T07:35:01.866Z'),
('b0960ae6-19f6-48e9-aca3-5de61c6958d3',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Has anyone booked a cab from the station?','text','2026-05-14T12:07:51.488Z'),
('4e0d30b6-24e9-4e74-8d94-8bc9b1f75e7c',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','40b935b5-0ffc-407e-bc76-af36d8053bc2','Can someone save a seat? BRB getting water','text','2026-05-14T19:59:20.800Z'),
('7c8c194d-589d-40d1-8a37-478ca29e6d22',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','0458ec55-9b4e-4bc6-898c-3ea19dfacd2f','Confirmed — upper berth in coach B4','text','2026-05-14T20:05:07.027Z'),
('16a29a10-d350-4455-bc9d-50fc3ee55412',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','40b935b5-0ffc-407e-bc76-af36d8053bc2','There is a nice sunset view from the left side right now!','text','2026-05-14T23:29:24.132Z'),
('62706add-3e8b-4fff-8466-06b72597e0cc',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','40b935b5-0ffc-407e-bc76-af36d8053bc2','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-15T20:45:06.278Z'),
('a3d9f2a1-9de0-4359-99ad-96b06b0e098d',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Can someone save a seat? BRB getting water','text','2026-05-14T22:06:37.318Z'),
('aa3b2313-1735-41c5-b81c-46271390c4e9',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','We should plan a meetup once we reach!','text','2026-05-15T15:18:11.383Z'),
('dc78d905-7820-4c82-b1e2-2f558363c4c0',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','Hey everyone! Anyone need help with luggage?','text','2026-05-15T02:36:06.808Z'),
('64be9c15-8e61-494d-83c2-720ac156b942',NULL,'fff34913-5402-4a77-a757-bc11bbfa0337','13cbbc82-15fc-4d8e-9da1-5d3301ec9466','I have extra snacks if anyone wants','text','2026-05-16T02:33:18.798Z'),
('8fd98dd7-2da3-4017-9930-f9713f769dba','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'66e43919-33bb-4434-999f-22a3086cb7f4','Do not forget to check your PNR status','text','2026-05-16T08:49:45.660Z'),
('fc95e004-b23c-4c5e-97fc-f13a547ca048','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','Which coach are you all in?','text','2026-05-13T13:37:23.379Z'),
('4183c639-8fe2-4f32-8aee-215cccb01e56','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','There is a nice sunset view from the left side right now!','text','2026-05-14T01:45:13.666Z'),
('9bd5e65f-ea82-4827-9876-1514a37ef828','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Anyone need a phone charger? I have a multi-port','text','2026-05-15T21:01:23.841Z'),
('2b24a684-6d55-4568-8e1b-38f756ad8989','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'73e3a251-b873-433b-9ebf-ba9b9c3b712d','Same batch! Which branch?','text','2026-05-15T02:10:09.379Z'),
('7203ae69-f713-48ba-9f80-3bc97e801c70','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'599561ff-7b0e-4659-9b96-eedcd5842f34','Which coach are you all in?','text','2026-05-13T11:54:07.755Z'),
('68d3200b-5860-4bc7-975a-f3db712ac69b','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','Do not forget to check your PNR status','text','2026-05-16T04:00:42.077Z'),
('72492b55-693d-41c9-b4de-b9c0fe2f3000','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'73e3a251-b873-433b-9ebf-ba9b9c3b712d','We can share a cab if you are going towards the same direction','text','2026-05-14T12:17:24.148Z'),
('1fcb8500-5812-4f63-bb09-85c7fb099483','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'66e43919-33bb-4434-999f-22a3086cb7f4','Hey everyone! Anyone need help with luggage?','text','2026-05-13T10:05:03.598Z'),
('255d656c-733e-4bb3-94f5-e3ddefbde847','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','Which hostel are you in?','text','2026-05-16T02:54:11.060Z'),
('675f0676-81e3-44f5-8263-8d271e9c2c46','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','Hey everyone! Anyone need help with luggage?','text','2026-05-13T17:38:13.523Z'),
('a65ba9ba-134d-41a9-b036-899c9395563e','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'73e3a251-b873-433b-9ebf-ba9b9c3b712d','I have extra snacks if anyone wants','text','2026-05-15T18:29:43.892Z'),
('ceda91b8-73a4-46cd-9c02-fa79f42c3526','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'73e3a251-b873-433b-9ebf-ba9b9c3b712d','Just joined this group, hi everyone 👋','text','2026-05-13T22:41:46.845Z'),
('be1b4751-f03d-448c-aa01-41fb835f7497','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'73e3a251-b873-433b-9ebf-ba9b9c3b712d','What time does this reach the destination?','text','2026-05-14T22:24:08.537Z'),
('166a779f-3e7f-427f-8ce0-6f85f4b2bbb5','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'599561ff-7b0e-4659-9b96-eedcd5842f34','Same batch! Which branch?','text','2026-05-13T16:15:11.411Z'),
('86861af2-302b-437e-b5ae-7228b22853c7','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','Pantry car food is decent today','text','2026-05-14T08:28:36.498Z'),
('7456351e-b0b2-4f56-a5de-c58f67da0028','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'66e43919-33bb-4434-999f-22a3086cb7f4','We can share a cab if you are going towards the same direction','text','2026-05-14T01:02:19.503Z'),
('27156ed3-86df-4892-b097-0f1c11f58c54','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'599561ff-7b0e-4659-9b96-eedcd5842f34','Anyone doing their internship in Bangalore?','text','2026-05-14T23:02:28.092Z'),
('1b91e6ec-8e70-4287-85c4-56653292f43c',NULL,'a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','73e3a251-b873-433b-9ebf-ba9b9c3b712d','We should plan a meetup once we reach!','text','2026-05-14T15:06:32.380Z'),
('1acd981d-b34b-41f3-bc30-60ff85b74594',NULL,'a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','73e3a251-b873-433b-9ebf-ba9b9c3b712d','Just joined this group, hi everyone 👋','text','2026-05-14T16:42:06.752Z'),
('879a213f-e3f1-4c86-ad6b-5bb02cb3eb78',NULL,'a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','599561ff-7b0e-4659-9b96-eedcd5842f34','There is a nice sunset view from the left side right now!','text','2026-05-14T20:04:57.668Z'),
('8b16faa6-80e3-426b-96b8-0d1ac12d9316',NULL,'a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','66e43919-33bb-4434-999f-22a3086cb7f4','Anyone else nervous about the semester starting?','text','2026-05-16T08:50:18.973Z'),
('1ed78dbb-f193-44d0-ab91-5b34b5b73967',NULL,'a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','95ff91b3-6c6a-41d7-ac38-471ac85422da','Anyone from Delhi NCR here?','text','2026-05-16T02:00:04.288Z'),
('b744f1d3-75bf-4538-9651-bcbb12eb160a',NULL,'a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','I have extra snacks if anyone wants','text','2026-05-15T22:40:37.912Z'),
('af9e6ae8-98b3-4928-bf18-328dd3a049b9',NULL,'a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','73e3a251-b873-433b-9ebf-ba9b9c3b712d','Hey, are you a BITS student?','text','2026-05-14T12:27:00.979Z'),
('14eaa455-eaf1-45a2-a649-32845391aae8',NULL,'a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Just saw a peacock from the window 😂','text','2026-05-16T01:21:22.055Z'),
('d7b1cbf1-7b2d-4da8-8138-19c03f7e3d84',NULL,'a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','95ff91b3-6c6a-41d7-ac38-471ac85422da','I have extra snacks if anyone wants','text','2026-05-16T02:27:21.993Z'),
('144950c3-36ad-4920-b5d5-8e2b61e6566e',NULL,'a0469226-7ef4-4a2b-aa7e-5b7f09b6974c','73e3a251-b873-433b-9ebf-ba9b9c3b712d','Confirmed — upper berth in coach B4','text','2026-05-15T08:53:31.647Z'),
('4bf41cc0-d1b5-41ec-9b58-951e6276d288','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Which hostel are you in?','text','2026-05-16T05:04:28.103Z'),
('1f21906f-e9a2-44ae-bf90-3e48aecd6e3c','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','Same batch! Which branch?','text','2026-05-15T07:41:51.554Z'),
('1b4610f0-9f9a-444e-bef0-17cc4912c2cf','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'599561ff-7b0e-4659-9b96-eedcd5842f34','Great trip so far, met some awesome people here!','text','2026-05-15T19:40:58.751Z'),
('48495dc8-d8b1-463b-99a2-bcc3923b7998','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'66e43919-33bb-4434-999f-22a3086cb7f4','Can someone save a seat? BRB getting water','text','2026-05-16T06:11:25.724Z'),
('d8cd02e6-4cad-4d46-a9a0-29e3cd2358f8','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','What time does this reach the destination?','text','2026-05-14T03:08:40.781Z'),
('84613fa6-885e-4b91-aace-b33256873c23','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','We can share a cab if you are going towards the same direction','text','2026-05-14T09:56:51.938Z'),
('ab594740-666d-4d3c-9404-7213fb7087dd','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Just joined this group, hi everyone 👋','text','2026-05-16T09:44:37.964Z'),
('e5c3cef4-0448-43bc-b4a6-873b69a9b8f3','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'599561ff-7b0e-4659-9b96-eedcd5842f34','Anyone want to play cards?','text','2026-05-13T17:01:17.670Z'),
('d32e538c-2f0f-4cac-acfc-9f19f7f6994e','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Anyone want to play cards?','text','2026-05-14T19:56:32.956Z'),
('65d6c11f-843d-4f1c-bf4c-5f2450598a12','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'73e3a251-b873-433b-9ebf-ba9b9c3b712d','We should plan a meetup once we reach!','text','2026-05-16T02:27:08.493Z'),
('d52f1706-ff6c-489c-bf53-69a1b20e2382','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','Has anyone booked a cab from the station?','text','2026-05-14T04:15:19.715Z'),
('47a1621d-3ce0-4a8c-99c2-3bcfc973db06','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Anyone from Delhi NCR here?','text','2026-05-14T13:01:27.028Z'),
('8db69dfe-b322-4810-a39a-a71866606e70','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'66e43919-33bb-4434-999f-22a3086cb7f4','Is the AC working in S4? Feels warm','text','2026-05-13T10:09:20.609Z'),
('309685c7-bc79-4395-81e7-aefb3befe256','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'95ff91b3-6c6a-41d7-ac38-471ac85422da','Great trip so far, met some awesome people here!','text','2026-05-13T17:46:35.138Z'),
('cbad783f-5fac-4952-8fcc-1e4719374121','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'599561ff-7b0e-4659-9b96-eedcd5842f34','Has anyone booked a cab from the station?','text','2026-05-16T03:42:16.576Z'),
('f6fa8741-eff4-415c-a5a4-0c75e4b0fe2a','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'73e3a251-b873-433b-9ebf-ba9b9c3b712d','Anyone want to play cards?','text','2026-05-13T21:28:53.715Z'),
('3ad1d8f4-77ae-4542-b2ba-e853cf268370','29f22b79-ca71-4a72-a011-29f4fd992705',NULL,'599561ff-7b0e-4659-9b96-eedcd5842f34','Confirmed — upper berth in coach B4','text','2026-05-13T19:53:35.888Z'),
('8e796e92-6014-433c-91f0-92a2f8bd9228',NULL,'3e9c9f44-b99a-4c37-a15b-b0b303b1e657','66e43919-33bb-4434-999f-22a3086cb7f4','I have extra snacks if anyone wants','text','2026-05-16T09:52:30.093Z'),
('f1ffe6f1-4274-4ff2-a57c-81182294c771',NULL,'3e9c9f44-b99a-4c37-a15b-b0b303b1e657','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Will we reach on time or is there a delay?','text','2026-05-15T11:46:37.395Z'),
('a98cff39-2945-461d-907c-ec71a35ee2b5',NULL,'3e9c9f44-b99a-4c37-a15b-b0b303b1e657','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Same batch! Which branch?','text','2026-05-15T15:01:00.513Z'),
('a0df5417-0561-414b-aafd-2bde0e9cb459',NULL,'3e9c9f44-b99a-4c37-a15b-b0b303b1e657','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Can someone save a seat? BRB getting water','text','2026-05-15T05:36:25.393Z'),
('64996dd8-fa6e-4586-aeb3-4a4132491bd8',NULL,'3e9c9f44-b99a-4c37-a15b-b0b303b1e657','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','First time traveling alone, this group is a lifesaver!','text','2026-05-15T02:34:57.708Z'),
('dc62f66e-584f-4c71-b1ec-1312b0d2a787',NULL,'3e9c9f44-b99a-4c37-a15b-b0b303b1e657','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','Hey, are you a BITS student?','text','2026-05-15T21:24:47.495Z'),
('419ecfcd-95cf-479a-9bde-775de1e974a0',NULL,'3e9c9f44-b99a-4c37-a15b-b0b303b1e657','66e43919-33bb-4434-999f-22a3086cb7f4','Which hostel are you in?','text','2026-05-14T23:09:07.573Z'),
('67e7ed5e-ee59-489e-858e-8fc8e35d9311',NULL,'3e9c9f44-b99a-4c37-a15b-b0b303b1e657','66e43919-33bb-4434-999f-22a3086cb7f4','We can share a cab if you are going towards the same direction','text','2026-05-15T11:44:15.280Z'),
('7177de1c-1e2b-437b-bb36-201a55696674',NULL,'3e9c9f44-b99a-4c37-a15b-b0b303b1e657','f8164cc9-a372-45bf-b6f4-d1a5ad115c82','First time traveling alone, this group is a lifesaver!','text','2026-05-15T17:00:35.908Z'),
('fb41801f-21a7-45f7-a1bf-8660df6d1ff0','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'656130ae-d5e3-46f8-aa53-21bcc35c28a8','Has anyone booked a cab from the station?','text','2026-05-13T16:52:08.461Z'),
('34adaee3-98de-4fc2-86aa-f3907d383d3b','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'656130ae-d5e3-46f8-aa53-21bcc35c28a8','Anyone need a phone charger? I have a multi-port','text','2026-05-15T14:33:00.058Z'),
('04294d9a-18ba-4e87-8f5d-b21241b79de6','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'cf6c3a10-8460-4f52-8ee2-7a029042c5d7','There is a nice sunset view from the left side right now!','text','2026-05-13T23:52:42.411Z'),
('d8a66e33-31d7-4efe-85f9-2a31cce69107','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'cf6c3a10-8460-4f52-8ee2-7a029042c5d7','Anyone want to play cards?','text','2026-05-14T01:11:34.410Z'),
('f5d7fc9c-7721-4202-8892-0fb9c1c4e0d6','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'656130ae-d5e3-46f8-aa53-21bcc35c28a8','Same batch! Which branch?','text','2026-05-15T21:05:31.682Z'),
('bcc924ce-0e4d-4f28-91bc-0079216445b0','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'fadcce80-f0d7-4031-8233-fb8fc9e34e0f','The train is running 30 min late btw','text','2026-05-13T13:16:55.616Z'),
('dbc12168-43c5-4685-a066-0e8b326a3ae4','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'cf6c3a10-8460-4f52-8ee2-7a029042c5d7','The platform number is 4, confirmed on the app','text','2026-05-14T03:34:51.142Z'),
('5f135c1a-65e3-43a1-bca6-958a8ab11e0f','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'656130ae-d5e3-46f8-aa53-21bcc35c28a8','Has anyone booked a cab from the station?','text','2026-05-14T19:18:07.860Z'),
('d3c51a03-5a35-43a3-9949-94632f297bb1','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'656130ae-d5e3-46f8-aa53-21bcc35c28a8','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-15T15:40:47.059Z'),
('23706e3c-e78d-450b-9df4-0512924731eb','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'fadcce80-f0d7-4031-8233-fb8fc9e34e0f','Anyone want to play cards?','text','2026-05-15T22:10:46.564Z'),
('fd96a624-fced-40c4-a381-2e8e35b46f01','2a5ff177-4154-4a27-ae0c-d7828e141029',NULL,'656130ae-d5e3-46f8-aa53-21bcc35c28a8','I have extra snacks if anyone wants','text','2026-05-13T17:47:52.027Z'),
('e6d0f289-fc30-4608-9764-52e91787e40d',NULL,'46faec95-6337-48a2-9ee6-6d3e4bc75347','cf6c3a10-8460-4f52-8ee2-7a029042c5d7','Which coach are you all in?','text','2026-05-15T18:18:02.253Z'),
('6189010a-bdab-47c2-953b-1e4003378872',NULL,'46faec95-6337-48a2-9ee6-6d3e4bc75347','cf6c3a10-8460-4f52-8ee2-7a029042c5d7','Hey, are you a BITS student?','text','2026-05-14T13:46:59.519Z'),
('f521b0f8-4801-44fc-a642-ebb0a0e71282',NULL,'46faec95-6337-48a2-9ee6-6d3e4bc75347','656130ae-d5e3-46f8-aa53-21bcc35c28a8','Just saw a peacock from the window 😂','text','2026-05-14T18:31:00.843Z'),
('22e94228-0b29-46d0-a598-e24ef90fb325',NULL,'46faec95-6337-48a2-9ee6-6d3e4bc75347','656130ae-d5e3-46f8-aa53-21bcc35c28a8','Same batch! Which branch?','text','2026-05-16T09:02:57.174Z'),
('a3b905ff-a79e-42c2-85a1-095a6d82937e',NULL,'46faec95-6337-48a2-9ee6-6d3e4bc75347','cf6c3a10-8460-4f52-8ee2-7a029042c5d7','Which hostel are you in?','text','2026-05-15T23:31:44.728Z'),
('27f9a689-ebae-4c37-bd77-26a4de53f7de',NULL,'46faec95-6337-48a2-9ee6-6d3e4bc75347','656130ae-d5e3-46f8-aa53-21bcc35c28a8','I have extra snacks if anyone wants','text','2026-05-14T16:36:57.650Z'),
('4cd35f49-2f5d-4d8e-9d01-5cba6ee78578',NULL,'46faec95-6337-48a2-9ee6-6d3e4bc75347','cf6c3a10-8460-4f52-8ee2-7a029042c5d7','We should plan a meetup once we reach!','text','2026-05-15T15:11:50.980Z'),
('dc7aaf77-ba8c-41f3-a854-1b29495bcb45',NULL,'46faec95-6337-48a2-9ee6-6d3e4bc75347','cf6c3a10-8460-4f52-8ee2-7a029042c5d7','Which coach are you all in?','text','2026-05-16T01:11:20.819Z'),
('041d7a53-e46d-44b6-80c4-593c41ad79af',NULL,'46faec95-6337-48a2-9ee6-6d3e4bc75347','656130ae-d5e3-46f8-aa53-21bcc35c28a8','Anyone need a phone charger? I have a multi-port','text','2026-05-14T12:02:23.571Z'),
('22149665-25af-4de9-801f-fa0192803202',NULL,'46faec95-6337-48a2-9ee6-6d3e4bc75347','cf6c3a10-8460-4f52-8ee2-7a029042c5d7','Anyone doing their internship in Bangalore?','text','2026-05-14T22:01:50.956Z'),
('f030242e-1502-4240-b689-eaed120804a2','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'ea7cb6f3-8697-4cdc-9b14-2132a630b8c2','Anyone need a phone charger? I have a multi-port','text','2026-05-14T23:02:27.490Z'),
('43901218-7b49-4cc3-872c-e21df78ae69b','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'a8dc8480-38ba-4e2c-879d-61e888626bf3','Hey everyone! Anyone need help with luggage?','text','2026-05-14T02:57:41.937Z'),
('1cb95bfe-9c40-4ac4-9183-724ef946bf02','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'c21a9c50-33b1-4700-a705-778fc04434f5','Great trip so far, met some awesome people here!','text','2026-05-13T19:59:11.987Z'),
('0d1d1088-1761-4179-9997-a8d5e3b2e470','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'0e52e760-d927-49d5-b3f7-568970536394','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-13T15:47:35.369Z'),
('88c165ae-6b22-40f8-97e9-e689fb63b339','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'c21a9c50-33b1-4700-a705-778fc04434f5','Hey everyone! Anyone need help with luggage?','text','2026-05-14T10:17:08.330Z'),
('e5aaba24-387f-4935-95aa-e31910731d3c','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'c21a9c50-33b1-4700-a705-778fc04434f5','Will we reach on time or is there a delay?','text','2026-05-16T06:11:35.341Z'),
('38675d24-2fbf-4315-8e17-6fd5c9031ed0','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'a8dc8480-38ba-4e2c-879d-61e888626bf3','Is the AC working in S4? Feels warm','text','2026-05-14T17:10:45.744Z'),
('8313ffeb-7eab-477f-9be7-b4a7d5642ae3','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'c21a9c50-33b1-4700-a705-778fc04434f5','Which hostel are you in?','text','2026-05-14T21:44:39.907Z'),
('6a0bc6cc-d2a0-47af-b648-e02c062273cc','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'a8dc8480-38ba-4e2c-879d-61e888626bf3','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-14T05:12:23.404Z'),
('d99c9201-d7d2-4b64-9422-6f542408a63e','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'a8dc8480-38ba-4e2c-879d-61e888626bf3','Anyone from Delhi NCR here?','text','2026-05-14T20:13:54.132Z'),
('b1d1db51-3182-4474-bfdf-d34c750cf3e4','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'a8dc8480-38ba-4e2c-879d-61e888626bf3','There is a nice sunset view from the left side right now!','text','2026-05-15T19:32:24.091Z'),
('c7e5a708-bb17-4371-b6ba-213612cad5f8',NULL,'3bc17acf-ead0-469d-bd96-2b4cae0c61f3','c21a9c50-33b1-4700-a705-778fc04434f5','Anyone from Delhi NCR here?','text','2026-05-15T02:09:00.718Z'),
('6925688b-d6a6-42c4-a7da-8213797f8d4f',NULL,'3bc17acf-ead0-469d-bd96-2b4cae0c61f3','c21a9c50-33b1-4700-a705-778fc04434f5','Is the AC working in S4? Feels warm','text','2026-05-15T12:20:42.910Z'),
('986e6b5c-3d79-4e63-90ce-4b7350d237a3',NULL,'3bc17acf-ead0-469d-bd96-2b4cae0c61f3','a8dc8480-38ba-4e2c-879d-61e888626bf3','Anyone from Delhi NCR here?','text','2026-05-15T01:45:13.654Z'),
('3ad34317-30f4-413a-a337-b36532f4ae2e',NULL,'3bc17acf-ead0-469d-bd96-2b4cae0c61f3','ea7cb6f3-8697-4cdc-9b14-2132a630b8c2','Anyone from Delhi NCR here?','text','2026-05-15T04:15:54.811Z'),
('9ad9fadb-cc10-4d26-8ee8-a85ca2ae1c72',NULL,'3bc17acf-ead0-469d-bd96-2b4cae0c61f3','0e52e760-d927-49d5-b3f7-568970536394','Can someone save a seat? BRB getting water','text','2026-05-15T22:59:05.071Z'),
('850c46e5-e66f-4c8c-919d-848e8f128a4f',NULL,'3bc17acf-ead0-469d-bd96-2b4cae0c61f3','a8dc8480-38ba-4e2c-879d-61e888626bf3','Will we reach on time or is there a delay?','text','2026-05-15T07:22:35.672Z'),
('eb774702-6edb-428d-aeb2-e747b52b4438',NULL,'3bc17acf-ead0-469d-bd96-2b4cae0c61f3','c21a9c50-33b1-4700-a705-778fc04434f5','The train is running 30 min late btw','text','2026-05-15T16:12:48.576Z'),
('826eea60-3637-4b34-97d5-c37649ca19d3',NULL,'3bc17acf-ead0-469d-bd96-2b4cae0c61f3','c21a9c50-33b1-4700-a705-778fc04434f5','Anyone doing their internship in Bangalore?','text','2026-05-15T14:10:01.736Z'),
('67663a7a-38c2-4c7a-aa32-c32a2b3c7865',NULL,'3bc17acf-ead0-469d-bd96-2b4cae0c61f3','a8dc8480-38ba-4e2c-879d-61e888626bf3','Has anyone booked a cab from the station?','text','2026-05-14T20:04:00.229Z'),
('cdcfd913-f4da-4a30-a203-dd760dd6bd84','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'f3883e6b-8190-42eb-b94b-84c6dad5e909','What time does this reach the destination?','text','2026-05-13T20:16:26.415Z'),
('0d733a93-858b-4c8e-baa1-3d26906459fe','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'0e52e760-d927-49d5-b3f7-568970536394','We can share a cab if you are going towards the same direction','text','2026-05-16T08:05:35.367Z'),
('975aa266-62ec-46cd-affc-68371fc909c0','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'c21a9c50-33b1-4700-a705-778fc04434f5','Confirmed — upper berth in coach B4','text','2026-05-13T21:31:46.923Z'),
('66949a46-e920-4e1c-a9c6-972a09aa33ae','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'0e52e760-d927-49d5-b3f7-568970536394','Hey, are you a BITS student?','text','2026-05-14T12:57:46.016Z'),
('09d7167c-0090-4b06-a6d1-6b1eaae10d92','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'0e52e760-d927-49d5-b3f7-568970536394','Same batch! Which branch?','text','2026-05-15T20:10:01.283Z'),
('122dd88c-14d0-47bd-80d7-885dbb5013fe','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'a8dc8480-38ba-4e2c-879d-61e888626bf3','Can someone save a seat? BRB getting water','text','2026-05-13T11:51:10.833Z'),
('855f3465-314f-4d58-abfb-7e2b5d0c46f1','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'ea7cb6f3-8697-4cdc-9b14-2132a630b8c2','Hey everyone! Anyone need help with luggage?','text','2026-05-15T02:58:05.359Z'),
('1239aa7c-beb9-4a6f-8ef2-e20d026d2949','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'ea7cb6f3-8697-4cdc-9b14-2132a630b8c2','Confirmed — upper berth in coach B4','text','2026-05-14T18:43:18.205Z'),
('37ba38ed-a088-4811-9d0b-75e9e59e26ff','17061f6f-be50-44a0-af22-debf59b246b4',NULL,'f3883e6b-8190-42eb-b94b-84c6dad5e909','Confirmed — upper berth in coach B4','text','2026-05-16T04:50:08.906Z'),
('bb8cbdfe-63a8-4dcf-aab4-7cf12b44373c',NULL,'32f74a0e-62d2-40c0-823c-09d191582b41','0e52e760-d927-49d5-b3f7-568970536394','Just saw a peacock from the window 😂','text','2026-05-14T18:18:46.993Z'),
('0b3581c4-15a6-462e-9fcf-500a7cc976ca',NULL,'32f74a0e-62d2-40c0-823c-09d191582b41','0e52e760-d927-49d5-b3f7-568970536394','Do not forget to check your PNR status','text','2026-05-15T07:03:33.962Z'),
('b83f21e6-5a10-4018-9d39-134bd9b16c94',NULL,'32f74a0e-62d2-40c0-823c-09d191582b41','a8dc8480-38ba-4e2c-879d-61e888626bf3','Just saw a peacock from the window 😂','text','2026-05-14T11:18:36.621Z'),
('c3f6f7f0-d669-416a-92ac-d272dfcc00b5',NULL,'32f74a0e-62d2-40c0-823c-09d191582b41','a8dc8480-38ba-4e2c-879d-61e888626bf3','I have extra snacks if anyone wants','text','2026-05-15T09:23:37.749Z'),
('772cc2f2-c0d3-41b3-9a40-394c521daa1e',NULL,'32f74a0e-62d2-40c0-823c-09d191582b41','f3883e6b-8190-42eb-b94b-84c6dad5e909','We should plan a meetup once we reach!','text','2026-05-14T16:42:50.714Z'),
('0447c0f4-1706-4ea2-a600-e97ca53ffb40',NULL,'32f74a0e-62d2-40c0-823c-09d191582b41','0e52e760-d927-49d5-b3f7-568970536394','Confirmed — upper berth in coach B4','text','2026-05-15T20:37:18.127Z'),
('0f9d610a-5823-487c-829f-374bdbd9289e',NULL,'32f74a0e-62d2-40c0-823c-09d191582b41','f3883e6b-8190-42eb-b94b-84c6dad5e909','Anyone need a phone charger? I have a multi-port','text','2026-05-16T05:19:56.774Z'),
('97d95610-e6b0-4876-a59a-fff835e2b5b4',NULL,'32f74a0e-62d2-40c0-823c-09d191582b41','f3883e6b-8190-42eb-b94b-84c6dad5e909','The train is running 30 min late btw','text','2026-05-14T19:58:16.269Z'),
('8fb8261e-b4b9-4140-99c5-5c76931df2ad','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'2a397b4f-1650-428d-806e-a9c929655ca1','Just joined this group, hi everyone 👋','text','2026-05-15T19:06:57.566Z'),
('4e75e38d-e136-47ff-bbeb-4a58414bb87d','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'2f6e2744-67bd-49f0-b2a6-dc104146a963','Just joined this group, hi everyone 👋','text','2026-05-14T00:17:50.271Z'),
('80fef326-08b1-44bd-8aaa-ed2be0f6ab16','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'2f6e2744-67bd-49f0-b2a6-dc104146a963','Which coach are you all in?','text','2026-05-14T18:13:04.290Z'),
('76983d76-878b-437f-bead-23c6740c1846','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'7508a61b-7926-4b0b-9741-92bdf0a5b801','Hey, are you a BITS student?','text','2026-05-14T14:46:46.908Z'),
('67de8583-a4e6-4c86-bb57-350ed5b86575','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'2f6e2744-67bd-49f0-b2a6-dc104146a963','Hey everyone! Anyone need help with luggage?','text','2026-05-14T10:40:36.021Z'),
('a10167f8-129f-4abb-9f32-2f6fdde0c8f7','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'7508a61b-7926-4b0b-9741-92bdf0a5b801','Do not forget to check your PNR status','text','2026-05-14T22:05:21.104Z'),
('8d881120-ab10-48e1-a7ea-74d7fd08f2ec','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'2f6e2744-67bd-49f0-b2a6-dc104146a963','Which hostel are you in?','text','2026-05-14T07:04:11.288Z'),
('bae13876-c080-40ea-94ac-79200dd235d7','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'2a397b4f-1650-428d-806e-a9c929655ca1','Anyone else nervous about the semester starting?','text','2026-05-16T05:13:34.797Z'),
('f3ead8f8-69ee-4702-8926-df8fb851e417','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'7508a61b-7926-4b0b-9741-92bdf0a5b801','There is a nice sunset view from the left side right now!','text','2026-05-14T17:53:34.515Z'),
('ee373b96-727a-4aad-ab1c-674e878ab69e','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'f798196b-807b-48df-a7c7-16961e01b088','Same batch! Which branch?','text','2026-05-15T18:23:05.586Z'),
('54263997-9220-4bc0-8f45-136f0cfc5f8c','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'53f4a2aa-025f-4886-b165-363912f8e678','Just saw a peacock from the window 😂','text','2026-05-15T16:33:05.482Z'),
('1aaae8ac-f7f3-485d-b9a4-0ff230c8ed9b','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'7508a61b-7926-4b0b-9741-92bdf0a5b801','Which hostel are you in?','text','2026-05-14T08:10:12.250Z'),
('b80c85d4-440a-4336-9ffc-7329b6699db5','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'2f6e2744-67bd-49f0-b2a6-dc104146a963','Which hostel are you in?','text','2026-05-13T12:07:00.544Z'),
('d26de15c-ff15-46ea-a9c3-807d000eba1f','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'2a397b4f-1650-428d-806e-a9c929655ca1','Hey, are you a BITS student?','text','2026-05-15T05:43:07.006Z'),
('c5779812-3a4b-490b-9a0a-8695232a4b57','3658226f-91db-4ae4-b9d7-20b9d367ce58',NULL,'f798196b-807b-48df-a7c7-16961e01b088','First time traveling alone, this group is a lifesaver!','text','2026-05-15T13:52:17.979Z'),
('5da6d83c-93a1-4e03-b158-de2f94a41494',NULL,'b178a2e6-e266-42a5-9d78-10f9b80d2d0a','f798196b-807b-48df-a7c7-16961e01b088','We should plan a meetup once we reach!','text','2026-05-15T09:39:04.287Z'),
('d9bb2db3-29e4-4072-bab2-8f870780207d',NULL,'b178a2e6-e266-42a5-9d78-10f9b80d2d0a','7508a61b-7926-4b0b-9741-92bdf0a5b801','The train is running 30 min late btw','text','2026-05-14T11:31:30.119Z'),
('1d704e01-d42a-4f6d-85fc-e42024fbb836',NULL,'b178a2e6-e266-42a5-9d78-10f9b80d2d0a','53f4a2aa-025f-4886-b165-363912f8e678','Confirmed — upper berth in coach B4','text','2026-05-14T12:44:16.045Z'),
('753caff4-caa3-4cb3-9b9e-37140a10a79b',NULL,'b178a2e6-e266-42a5-9d78-10f9b80d2d0a','2a397b4f-1650-428d-806e-a9c929655ca1','What time does this reach the destination?','text','2026-05-14T21:35:41.589Z'),
('0d1c493b-6219-49f1-8ff0-6b0ce67922af',NULL,'b178a2e6-e266-42a5-9d78-10f9b80d2d0a','2a397b4f-1650-428d-806e-a9c929655ca1','Same batch! Which branch?','text','2026-05-14T14:49:25.392Z'),
('32e93cc6-c62a-40a6-8798-a9116f48653d',NULL,'b178a2e6-e266-42a5-9d78-10f9b80d2d0a','f798196b-807b-48df-a7c7-16961e01b088','Hey, are you a BITS student?','text','2026-05-15T18:12:38.388Z'),
('6b1b9481-bb0d-4b1c-be6d-17b161d617cb',NULL,'b178a2e6-e266-42a5-9d78-10f9b80d2d0a','53f4a2aa-025f-4886-b165-363912f8e678','Same batch! Which branch?','text','2026-05-14T15:40:59.145Z'),
('9b3e34d2-ff96-4dfa-b858-fbe42c0dadf0','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'9b70939f-08cc-4e07-80cb-06b8a7584ddf','First time traveling alone, this group is a lifesaver!','text','2026-05-14T10:22:37.353Z'),
('93d65bbb-39b5-484c-9bae-d41c4a2ce73c','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'9a994052-6788-48cc-9240-6a26c8d32c35','What time does this reach the destination?','text','2026-05-16T09:08:31.037Z'),
('351ad6d8-1164-4b6c-aed3-bef6dc8acc63','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'b255e0d1-47f5-47e2-b7fa-3682b9c70ef5','There is a nice sunset view from the left side right now!','text','2026-05-16T09:00:33.253Z'),
('0f0b5799-b833-48ad-bf9a-e8898f7c585a','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'f40d0980-d059-4c82-ad90-a1e19b1adf33','Which hostel are you in?','text','2026-05-14T23:18:48.505Z'),
('1f41ae17-6c48-428a-8c23-46bdc3cbf69d','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'9a994052-6788-48cc-9240-6a26c8d32c35','Pantry car food is decent today','text','2026-05-15T09:13:06.463Z'),
('552e28f9-8e13-44c7-a117-639d206f10b1','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'b255e0d1-47f5-47e2-b7fa-3682b9c70ef5','Can someone save a seat? BRB getting water','text','2026-05-13T21:02:38.650Z'),
('4b790d71-faff-4924-af3a-1b321a4e3972','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'f40d0980-d059-4c82-ad90-a1e19b1adf33','The WiFi here is surprisingly good','text','2026-05-15T09:11:29.903Z'),
('4cf5f27c-4eb7-4941-b75f-7a558b9b9cba','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'f40d0980-d059-4c82-ad90-a1e19b1adf33','The WiFi here is surprisingly good','text','2026-05-14T06:13:45.106Z'),
('b0b02bb5-7efc-4732-80d6-e588b8dd0c11','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'b255e0d1-47f5-47e2-b7fa-3682b9c70ef5','Which coach are you all in?','text','2026-05-16T05:40:32.734Z'),
('2e0a1124-0fe0-428f-ae9b-3cea274e58d5','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'f40d0980-d059-4c82-ad90-a1e19b1adf33','Confirmed — upper berth in coach B4','text','2026-05-14T13:54:48.709Z'),
('c9378691-147f-48f5-9889-b6743ab511b9','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'9b70939f-08cc-4e07-80cb-06b8a7584ddf','First time traveling alone, this group is a lifesaver!','text','2026-05-15T22:31:54.729Z'),
('3beeac35-ad00-47b6-a050-e55f7427677c','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'d9757067-5e1b-41f2-8343-fe980c4bd506','Which hostel are you in?','text','2026-05-14T13:22:18.423Z'),
('430b56a9-3b6d-49d7-9922-120854d3005a','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'d9757067-5e1b-41f2-8343-fe980c4bd506','Is the AC working in S4? Feels warm','text','2026-05-15T15:28:08.130Z'),
('bd85ef98-3f22-4ee2-9ad3-13953396802a','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'b255e0d1-47f5-47e2-b7fa-3682b9c70ef5','Anyone else nervous about the semester starting?','text','2026-05-15T13:47:39.698Z'),
('131d5f25-a3a1-4686-9be2-0ed1794e9e10','1e91aa35-5420-4017-a29d-9bff0b89f8e9',NULL,'9a994052-6788-48cc-9240-6a26c8d32c35','First time traveling alone, this group is a lifesaver!','text','2026-05-16T00:53:33.647Z'),
('c4ede702-c7c2-4d3d-a3f8-9278941da7ec',NULL,'9b4123d0-ca38-4e2a-bb8e-b2a641304a9a','d9757067-5e1b-41f2-8343-fe980c4bd506','Anyone want to play cards?','text','2026-05-15T08:53:42.500Z'),
('478ea7eb-d3d8-42ed-a1d9-47db5414bfcc',NULL,'9b4123d0-ca38-4e2a-bb8e-b2a641304a9a','d9757067-5e1b-41f2-8343-fe980c4bd506','Do not forget to check your PNR status','text','2026-05-14T21:31:50.795Z'),
('13a40e7a-5d28-4a8b-a2a0-85039ee22ee6',NULL,'9b4123d0-ca38-4e2a-bb8e-b2a641304a9a','f40d0980-d059-4c82-ad90-a1e19b1adf33','Just joined this group, hi everyone 👋','text','2026-05-15T19:41:13.632Z'),
('25542412-bd24-43e8-86f0-bdc4a9e6fdc5',NULL,'9b4123d0-ca38-4e2a-bb8e-b2a641304a9a','7c0dc257-7e74-4bd8-a9ea-4d8ec8391be8','Anyone from Delhi NCR here?','text','2026-05-15T11:12:54.291Z'),
('1c118ef4-7f7e-4eaa-8d32-b967e986a1d6',NULL,'9b4123d0-ca38-4e2a-bb8e-b2a641304a9a','f40d0980-d059-4c82-ad90-a1e19b1adf33','Great trip so far, met some awesome people here!','text','2026-05-15T17:30:42.725Z'),
('8fbabbb2-123f-434e-ac97-775b447ab4dc','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','Will we reach on time or is there a delay?','text','2026-05-14T14:44:07.230Z'),
('98099362-3393-44aa-8c0c-e85987ce2a0c','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'f88cf7f0-e103-4db9-897c-f70b5544e51f','Pantry car food is decent today','text','2026-05-14T04:54:52.605Z'),
('25a0a4a2-35a6-4c5b-9e05-bd3d494236f9','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-15T21:01:32.600Z'),
('41226cd6-6b23-409d-b21e-7fdcd4d03b03','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Hey, are you a BITS student?','text','2026-05-14T15:51:18.426Z'),
('89d7ca70-6b21-4861-9131-f1496dd45550','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','We should plan a meetup once we reach!','text','2026-05-13T11:51:13.016Z'),
('0901c552-66a9-4281-ad48-715d89e33764','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','Can someone save a seat? BRB getting water','text','2026-05-16T04:04:32.913Z'),
('a91d8642-2c1b-4871-8c53-2e73a083e4e4','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'f88cf7f0-e103-4db9-897c-f70b5544e51f','Anyone else nervous about the semester starting?','text','2026-05-15T02:09:34.372Z'),
('20b6734f-fc9c-484f-8f85-ca2b5303030e','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'f88cf7f0-e103-4db9-897c-f70b5544e51f','Will we reach on time or is there a delay?','text','2026-05-13T12:12:39.923Z'),
('3db04e15-b2ce-4b51-8fcb-4172f1bd8ef5','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'25ce2843-8039-420c-bf21-cd436c59195d','There is a nice sunset view from the left side right now!','text','2026-05-13T20:50:18.431Z'),
('48045460-60dd-4c6b-b4ed-71e04ef24acb','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Confirmed — upper berth in coach B4','text','2026-05-15T11:12:35.450Z'),
('abaeed0a-fffe-4e97-bf3a-247c5902f236','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'25ce2843-8039-420c-bf21-cd436c59195d','Anyone else nervous about the semester starting?','text','2026-05-13T16:40:11.531Z'),
('66adf03f-839b-4f09-afa2-7edfc22b6b4b','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'f88cf7f0-e103-4db9-897c-f70b5544e51f','Hey everyone! Anyone need help with luggage?','text','2026-05-15T02:32:29.769Z'),
('8d6fb2d0-319d-4bfa-8880-332e8b3fe74e','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Same batch! Which branch?','text','2026-05-15T00:26:19.381Z'),
('5ac3d8f7-b0b2-43cf-874e-00614cd92c2f','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Confirmed — upper berth in coach B4','text','2026-05-14T20:00:21.194Z'),
('d5002ce2-8eb2-410e-97dd-616372c0d946','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'f88cf7f0-e103-4db9-897c-f70b5544e51f','Which hostel are you in?','text','2026-05-16T05:49:48.381Z'),
('a5967993-f751-4129-a0e1-e4980ddfd758','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','The train is running 30 min late btw','text','2026-05-14T04:02:53.482Z'),
('27b72a26-3fdf-496b-af06-2c1feb87aa15','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','I have extra snacks if anyone wants','text','2026-05-15T05:44:06.271Z'),
('22c15761-1953-4cf2-9134-1cc840ffdb50','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'25ce2843-8039-420c-bf21-cd436c59195d','Is the AC working in S4? Feels warm','text','2026-05-14T07:17:58.857Z'),
('f2b2f33a-470c-4b98-b0df-43a418f86807',NULL,'9a920c61-0681-4e2d-8756-38a792a125bd','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','We can share a cab if you are going towards the same direction','text','2026-05-15T14:51:58.167Z'),
('1a38edab-ee12-4165-9db0-c0214279875b',NULL,'9a920c61-0681-4e2d-8756-38a792a125bd','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-14T18:48:41.193Z'),
('285604c8-85fb-4a51-b332-a92a98716631',NULL,'9a920c61-0681-4e2d-8756-38a792a125bd','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','Just saw a peacock from the window 😂','text','2026-05-14T19:44:52.211Z'),
('440d7bcc-7548-41b6-92ea-f60ef851f296',NULL,'9a920c61-0681-4e2d-8756-38a792a125bd','ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Has anyone booked a cab from the station?','text','2026-05-14T14:49:31.937Z'),
('a404b262-d497-4ddd-9599-8608fe19e286',NULL,'9a920c61-0681-4e2d-8756-38a792a125bd','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','Pantry car food is decent today','text','2026-05-14T12:42:38.708Z'),
('cd355d8e-c248-4230-bd15-ed42488026b9',NULL,'9a920c61-0681-4e2d-8756-38a792a125bd','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-16T05:12:32.088Z'),
('cba281b8-afee-4bf0-8421-796c9859be24',NULL,'9a920c61-0681-4e2d-8756-38a792a125bd','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','Has anyone booked a cab from the station?','text','2026-05-15T16:55:57.213Z'),
('5a5e3779-7c3f-4dad-9763-ad55e8d5a5d8','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'25ce2843-8039-420c-bf21-cd436c59195d','Can someone save a seat? BRB getting water','text','2026-05-15T05:53:39.560Z'),
('fcddecd2-8de7-4721-98f4-c1ad299f1a4d','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'f88cf7f0-e103-4db9-897c-f70b5544e51f','Is the AC working in S4? Feels warm','text','2026-05-15T00:34:57.274Z'),
('eebee2ae-3472-4d1c-b523-c753fec5a6f8','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'ee99aa6b-48e7-4074-a4ba-fb16d76249d1','The train is running 30 min late btw','text','2026-05-13T11:28:58.594Z'),
('cbcd8198-edd3-41fb-8d5e-0cf7be8c4c60','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'25ce2843-8039-420c-bf21-cd436c59195d','Will we reach on time or is there a delay?','text','2026-05-13T19:03:30.068Z'),
('8eff9a1b-41c4-4935-8f94-b9510b01f094','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'25ce2843-8039-420c-bf21-cd436c59195d','Hey everyone! Anyone need help with luggage?','text','2026-05-14T11:50:00.086Z'),
('cba9f903-b086-4ee4-9e8f-b37f8b14be29','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'25ce2843-8039-420c-bf21-cd436c59195d','The WiFi here is surprisingly good','text','2026-05-14T01:03:33.350Z'),
('0b93e656-4f99-4229-8988-7b7bfbdd5f2f','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'ee99aa6b-48e7-4074-a4ba-fb16d76249d1','First time traveling alone, this group is a lifesaver!','text','2026-05-15T09:23:52.321Z'),
('81c98ad6-7f12-463d-a88a-679b24927d12','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','Hey everyone! Anyone need help with luggage?','text','2026-05-13T16:22:16.752Z'),
('4ded6cf4-17b8-443a-a3c8-dea0bd20999c','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Anyone need a phone charger? I have a multi-port','text','2026-05-15T12:51:30.996Z'),
('1d07eb65-bfaa-4956-a08a-acde683610f7','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'f88cf7f0-e103-4db9-897c-f70b5544e51f','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-16T00:33:21.324Z'),
('2de7101e-7469-4516-a609-ab74e0737e33','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','Anyone else nervous about the semester starting?','text','2026-05-15T18:21:15.304Z'),
('5053650e-297a-4da5-abc9-b37403392ecf','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Great trip so far, met some awesome people here!','text','2026-05-16T04:16:53.777Z'),
('f5a84dae-0c16-4aec-beb9-34da6a770881','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','Anyone want to play cards?','text','2026-05-15T18:31:33.504Z'),
('bcbf8590-bcd6-4dca-88a9-693962aedc65','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'f88cf7f0-e103-4db9-897c-f70b5544e51f','Hey everyone! Anyone need help with luggage?','text','2026-05-15T13:56:14.049Z'),
('ec5a0f94-70f9-44b2-aefb-1234371406bd','9a11861f-0b94-4ec8-82f5-b35d2e1823a1',NULL,'f88cf7f0-e103-4db9-897c-f70b5544e51f','I have extra snacks if anyone wants','text','2026-05-14T07:47:56.395Z'),
('df8f1c55-137e-4ec2-9e16-d39aab2148f6',NULL,'723e7aef-8324-4802-b3f1-5527010e5ca5','ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Anyone from Delhi NCR here?','text','2026-05-15T00:02:49.667Z'),
('95dfea2e-4100-4372-b9c6-b24547079da8',NULL,'723e7aef-8324-4802-b3f1-5527010e5ca5','f88cf7f0-e103-4db9-897c-f70b5544e51f','We should plan a meetup once we reach!','text','2026-05-15T12:58:33.010Z'),
('7fc88ec3-6dbc-41e8-b8b9-95fbdd4fc5d4',NULL,'723e7aef-8324-4802-b3f1-5527010e5ca5','25ce2843-8039-420c-bf21-cd436c59195d','Hey, are you a BITS student?','text','2026-05-14T13:28:55.195Z'),
('0f914c0f-056e-4e9a-9569-af063489c25e',NULL,'723e7aef-8324-4802-b3f1-5527010e5ca5','f88cf7f0-e103-4db9-897c-f70b5544e51f','Same batch! Which branch?','text','2026-05-16T01:20:15.766Z'),
('f296124f-0ed4-4aa0-81ae-b5fe92c03818',NULL,'723e7aef-8324-4802-b3f1-5527010e5ca5','f88cf7f0-e103-4db9-897c-f70b5544e51f','Great trip so far, met some awesome people here!','text','2026-05-14T17:08:36.635Z'),
('a0dcc349-e45c-49a9-9b84-94f84e3cb137',NULL,'723e7aef-8324-4802-b3f1-5527010e5ca5','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','What time does this reach the destination?','text','2026-05-15T18:54:05.451Z'),
('af1af6b2-b4b9-4ba1-b473-86f5e42ad115',NULL,'723e7aef-8324-4802-b3f1-5527010e5ca5','ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-14T10:51:15.907Z'),
('eb92e54f-9045-4713-85b5-fc10285b36ba',NULL,'723e7aef-8324-4802-b3f1-5527010e5ca5','323d3dc0-4b6b-4fc4-8212-08a9c9c1475d','We can share a cab if you are going towards the same direction','text','2026-05-15T00:55:33.705Z'),
('c2f380c1-b3f5-46ab-9151-c7b0c2c39cab',NULL,'723e7aef-8324-4802-b3f1-5527010e5ca5','ee99aa6b-48e7-4074-a4ba-fb16d76249d1','Just joined this group, hi everyone 👋','text','2026-05-15T21:38:25.587Z'),
('dce054a2-91a3-4665-b243-f35e83c7089e','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'424c8082-c736-4860-9e90-24be1565854e','We should plan a meetup once we reach!','text','2026-05-14T18:01:25.539Z'),
('9228c2d8-2ed0-4037-bf54-ddd69831cb21','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'424c8082-c736-4860-9e90-24be1565854e','First time traveling alone, this group is a lifesaver!','text','2026-05-15T18:16:32.389Z'),
('173b9cda-ce0b-497b-8415-fc7bb7633525','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'424c8082-c736-4860-9e90-24be1565854e','Anyone from Delhi NCR here?','text','2026-05-16T07:18:04.988Z'),
('58f977c9-84e7-46bb-9102-4ef5a7946611','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'f91fbdcd-2c3b-4ad6-b653-3e323af41f79','Great trip so far, met some awesome people here!','text','2026-05-16T00:24:55.045Z'),
('da913358-22f3-4018-bf83-ba7f3c155023','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'f91fbdcd-2c3b-4ad6-b653-3e323af41f79','Do not forget to check your PNR status','text','2026-05-15T10:05:44.230Z'),
('c25667ef-f042-4b2e-babd-7d319deb8ef5','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'424c8082-c736-4860-9e90-24be1565854e','Anyone want to play cards?','text','2026-05-13T22:55:57.304Z'),
('fe59e615-4389-4267-91fe-1d627bac98f4','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'424c8082-c736-4860-9e90-24be1565854e','The WiFi here is surprisingly good','text','2026-05-15T16:07:02.296Z'),
('df2829f3-95e1-4b9f-997a-fcce785acd67','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'424c8082-c736-4860-9e90-24be1565854e','Which coach are you all in?','text','2026-05-14T17:50:01.175Z'),
('092f8630-2da5-4b79-a0c4-bcfd15663b6f','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','Hey, are you a BITS student?','text','2026-05-14T23:51:06.659Z'),
('eb6c7e0a-dc62-4284-b43c-4b478e0c85bc','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'f91fbdcd-2c3b-4ad6-b653-3e323af41f79','Pantry car food is decent today','text','2026-05-14T15:53:12.577Z'),
('c2960005-06f6-459a-870a-d74c47c2260c','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'02ccdcd8-e45a-435d-bc04-86f2bb129992','Do not forget to check your PNR status','text','2026-05-13T19:46:30.084Z'),
('b78113cd-5b2b-4ccb-8c72-2049fcb6ab98','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','Just joined this group, hi everyone 👋','text','2026-05-16T02:56:25.061Z'),
('bed2738b-918c-4518-af86-a59c31f293ac','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'f91fbdcd-2c3b-4ad6-b653-3e323af41f79','Anyone want to play cards?','text','2026-05-14T05:29:31.079Z'),
('f3e98e57-e893-4257-84c7-33a898fab619','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','First time traveling alone, this group is a lifesaver!','text','2026-05-13T14:19:51.045Z'),
('dd005320-b8b8-4d6b-bff1-579a6c132cae','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'02ccdcd8-e45a-435d-bc04-86f2bb129992','Do not forget to check your PNR status','text','2026-05-14T17:21:38.241Z'),
('269d3695-5586-437b-a67a-2dc33dc3a757','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','We can share a cab if you are going towards the same direction','text','2026-05-14T13:57:50.012Z'),
('b334b67d-57c6-4ddd-935a-46d3f6e63248','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','Confirmed — upper berth in coach B4','text','2026-05-16T00:27:45.518Z'),
('41936507-f2b7-4ccd-973b-ff9f674bfea6','13d543f1-0bbb-44c0-9af6-23c61449e892',NULL,'b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','Great trip so far, met some awesome people here!','text','2026-05-14T02:40:05.919Z'),
('aaa1ebd3-01ea-4722-823f-9bff7fdfb2e5',NULL,'d0499ef1-3e75-4d96-a87d-46fa5ca3646d','424c8082-c736-4860-9e90-24be1565854e','Has anyone booked a cab from the station?','text','2026-05-14T11:31:26.352Z'),
('4a8ee4e6-9e91-4169-b153-74222b4522a7',NULL,'d0499ef1-3e75-4d96-a87d-46fa5ca3646d','f91fbdcd-2c3b-4ad6-b653-3e323af41f79','Hey everyone! Anyone need help with luggage?','text','2026-05-15T21:37:52.645Z'),
('4d38857b-b9f3-4016-9cdb-8242ac06298a',NULL,'d0499ef1-3e75-4d96-a87d-46fa5ca3646d','b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','Just joined this group, hi everyone 👋','text','2026-05-15T06:13:40.388Z'),
('830e6d1c-d938-4bf9-9e6e-aae6af60123d',NULL,'d0499ef1-3e75-4d96-a87d-46fa5ca3646d','424c8082-c736-4860-9e90-24be1565854e','Do not forget to check your PNR status','text','2026-05-14T12:52:03.755Z'),
('81f5f3a3-565b-442f-b630-48a83c2c8db5',NULL,'d0499ef1-3e75-4d96-a87d-46fa5ca3646d','f91fbdcd-2c3b-4ad6-b653-3e323af41f79','Same batch! Which branch?','text','2026-05-14T13:18:22.781Z'),
('591d6f31-c1f7-4ecd-8836-9dc1dfbe3093',NULL,'d0499ef1-3e75-4d96-a87d-46fa5ca3646d','02ccdcd8-e45a-435d-bc04-86f2bb129992','Will we reach on time or is there a delay?','text','2026-05-14T12:49:26.359Z'),
('dc326a3b-eb4a-42ac-b3e2-ac12090b46d7',NULL,'d0499ef1-3e75-4d96-a87d-46fa5ca3646d','f91fbdcd-2c3b-4ad6-b653-3e323af41f79','Anyone want to play cards?','text','2026-05-16T04:09:25.357Z'),
('df768d95-38e8-4704-b675-a67a9e9af30c',NULL,'d0499ef1-3e75-4d96-a87d-46fa5ca3646d','b35a7ca3-a89c-4cc6-b280-9a6a2f796d26','I have extra snacks if anyone wants','text','2026-05-15T17:47:46.566Z'),
('fd0e1155-9547-49be-b4bb-edb71655d270','adc7e753-0103-485c-9e47-f3046bc38d19',NULL,'bc44693f-6524-49c9-a6d8-06a3ca4d61d8','Which coach are you all in?','text','2026-05-14T13:50:18.617Z'),
('eadbfaa4-1dff-4490-be49-e814e81d000e','adc7e753-0103-485c-9e47-f3046bc38d19',NULL,'660fb29d-479e-40f5-95a2-81f045db5c69','Hey, are you a BITS student?','text','2026-05-15T00:15:58.577Z'),
('06186e65-0dd9-43ff-8f5a-773ca2750c4e','adc7e753-0103-485c-9e47-f3046bc38d19',NULL,'575e3b18-220a-4b1b-975e-fbdaebcb3f92','We can share a cab if you are going towards the same direction','text','2026-05-15T06:20:48.183Z'),
('d72f18dd-6f6a-4b84-94ca-a49644cd6faf','adc7e753-0103-485c-9e47-f3046bc38d19',NULL,'bc44693f-6524-49c9-a6d8-06a3ca4d61d8','Will we reach on time or is there a delay?','text','2026-05-15T19:44:35.416Z'),
('b37c9196-bdbb-4aed-bfbe-3cb403ef7572','adc7e753-0103-485c-9e47-f3046bc38d19',NULL,'637e185c-f1fe-4afe-af7f-b7b7e9b60edc','We should plan a meetup once we reach!','text','2026-05-14T12:59:29.653Z'),
('d3e16640-0553-4c71-a9a4-085eab011bb4','adc7e753-0103-485c-9e47-f3046bc38d19',NULL,'eb2d91e8-f6ed-45da-a4ba-63e5765c05fe','Anyone from Delhi NCR here?','text','2026-05-13T20:04:38.526Z'),
('038b4594-dc6a-454f-bc4f-49bd2181aaff','adc7e753-0103-485c-9e47-f3046bc38d19',NULL,'660fb29d-479e-40f5-95a2-81f045db5c69','Do not forget to check your PNR status','text','2026-05-14T18:23:54.039Z'),
('2923c3f1-1674-4ddb-8649-1fbf8e60826b','adc7e753-0103-485c-9e47-f3046bc38d19',NULL,'660fb29d-479e-40f5-95a2-81f045db5c69','Is the AC working in S4? Feels warm','text','2026-05-15T05:26:19.142Z'),
('26d51875-8f5b-4a9c-9993-69d63af89ef3','adc7e753-0103-485c-9e47-f3046bc38d19',NULL,'bc44693f-6524-49c9-a6d8-06a3ca4d61d8','The train is running 30 min late btw','text','2026-05-16T00:42:46.133Z'),
('7dd0a0c1-6fc6-4d8e-aa94-70c86c70cc8d',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','637e185c-f1fe-4afe-af7f-b7b7e9b60edc','Has anyone booked a cab from the station?','text','2026-05-15T16:56:11.870Z'),
('5f31369c-92d2-4859-b11c-27df065caccd',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','e6dc2b9c-600e-455a-a943-7eb328f05212','Will we reach on time or is there a delay?','text','2026-05-16T05:17:56.476Z'),
('06bca0e1-924f-419b-8824-b32aea685117',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','eb2d91e8-f6ed-45da-a4ba-63e5765c05fe','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-14T10:13:58.165Z'),
('31ec6b33-0a51-4da4-bbc8-74fb23142416',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','e6dc2b9c-600e-455a-a943-7eb328f05212','We can share a cab if you are going towards the same direction','text','2026-05-14T14:18:22.282Z'),
('8d39af2f-6b84-42c1-962a-861db968e2e2',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','575e3b18-220a-4b1b-975e-fbdaebcb3f92','What time does this reach the destination?','text','2026-05-14T12:07:46.700Z'),
('331a651e-d5ab-4c94-bd75-8036d9a1020c',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','575e3b18-220a-4b1b-975e-fbdaebcb3f92','Hey, are you a BITS student?','text','2026-05-14T22:07:10.247Z'),
('7ff18a2d-961a-4542-aaf6-86767ce20905',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','e6dc2b9c-600e-455a-a943-7eb328f05212','Will we reach on time or is there a delay?','text','2026-05-14T22:19:32.599Z'),
('25c11316-fcf1-4c01-a5b0-7a844982707a',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','e6dc2b9c-600e-455a-a943-7eb328f05212','Anyone need a phone charger? I have a multi-port','text','2026-05-14T10:27:56.121Z'),
('2ff87e5c-410f-473f-93f8-37ecc9d3df4f',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','575e3b18-220a-4b1b-975e-fbdaebcb3f92','Is the AC working in S4? Feels warm','text','2026-05-15T03:07:40.828Z'),
('a6c00847-f53d-400c-84ac-0211f27534fb',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','575e3b18-220a-4b1b-975e-fbdaebcb3f92','Anyone doing their internship in Bangalore?','text','2026-05-15T01:03:56.044Z'),
('ebf38855-7f91-49b9-9984-25e7ba2bb0bc',NULL,'53851c19-3a81-40fc-bb2f-77ad8c3b7d34','eb2d91e8-f6ed-45da-a4ba-63e5765c05fe','Anyone need a phone charger? I have a multi-port','text','2026-05-15T06:47:21.222Z'),
('0e0fe915-066b-4a39-b0d9-c24586704df2','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'a484a03b-1cb9-4790-835b-64245238bcda','Anyone from Delhi NCR here?','text','2026-05-15T11:12:44.606Z'),
('531641b4-20ac-4761-8f99-fa4fe1061454','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','Which hostel are you in?','text','2026-05-13T20:05:25.913Z'),
('a8294491-d1b6-4280-a885-2ef0836ced31','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'73250fab-0868-4148-a348-e1654293fbab','We can share a cab if you are going towards the same direction','text','2026-05-14T05:58:42.175Z'),
('b2ec6aa5-c358-476a-8190-938309d59f36','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','Anyone need a phone charger? I have a multi-port','text','2026-05-14T16:00:04.756Z'),
('7fcc8161-f4b8-4a11-93da-cf2434e41416','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','Pantry car food is decent today','text','2026-05-15T21:55:57.850Z'),
('9fdb8e56-a6dd-4399-8989-a32189a0fac3','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'287cffed-71ac-4b66-8552-4aadd6cbf3dc','Great trip so far, met some awesome people here!','text','2026-05-14T17:20:29.948Z'),
('97490e15-65fc-403a-a8a2-b907d28c4474','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'287cffed-71ac-4b66-8552-4aadd6cbf3dc','First time traveling alone, this group is a lifesaver!','text','2026-05-15T22:18:26.145Z'),
('e004a04e-f044-4b74-91fc-b7045ea5ffaa','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'380997d4-59cd-41f2-9f95-a97b1a65c25b','Which hostel are you in?','text','2026-05-14T19:19:13.120Z'),
('9e867ded-bc6f-4c5b-be7d-1f93cd5bdc5b','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','Anyone want to play cards?','text','2026-05-16T04:02:14.458Z'),
('c4c86473-c5e7-410b-a4a7-560c2c0fbf35','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'287cffed-71ac-4b66-8552-4aadd6cbf3dc','We can share a cab if you are going towards the same direction','text','2026-05-13T10:35:35.928Z'),
('42327135-b759-484f-b298-b132e6c01d51','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'380997d4-59cd-41f2-9f95-a97b1a65c25b','Hey everyone! Anyone need help with luggage?','text','2026-05-15T09:11:50.360Z'),
('fe37738d-e888-4363-9092-ca3e80e32dda','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'8f1072d4-86dd-40b5-8521-0db5b9f305a2','Anyone from Delhi NCR here?','text','2026-05-15T17:04:31.912Z'),
('b9ef8275-b9eb-4f67-bacc-a625b7f0daad','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'97b03499-1962-4087-b478-48102f464a91','There is a nice sunset view from the left side right now!','text','2026-05-16T05:26:49.850Z'),
('27475e94-ecb7-4ac3-8b94-73868b39c8cb','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'8f1072d4-86dd-40b5-8521-0db5b9f305a2','Will we reach on time or is there a delay?','text','2026-05-14T15:03:39.743Z'),
('65faedbc-c6b0-4c1d-8801-e25297fd8dd6','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'287cffed-71ac-4b66-8552-4aadd6cbf3dc','Which hostel are you in?','text','2026-05-15T21:06:38.417Z'),
('f9a1bc09-e036-4878-9621-3de93d084317','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'7a348d56-91d8-4610-959b-0fc29c14686e','Anyone doing their internship in Bangalore?','text','2026-05-14T16:14:02.926Z'),
('091c7229-abbd-4a1b-a46e-9274402b7fc3',NULL,'1e3fc87a-cc15-46fb-be31-1745394e1130','a484a03b-1cb9-4790-835b-64245238bcda','Anyone else nervous about the semester starting?','text','2026-05-16T00:18:18.880Z'),
('293cbf0d-e346-4363-a99e-42cc8d73a88b',NULL,'1e3fc87a-cc15-46fb-be31-1745394e1130','72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','Which coach are you all in?','text','2026-05-15T23:23:21.591Z'),
('e4d65d14-9ac2-49f4-8a96-16f792583621',NULL,'1e3fc87a-cc15-46fb-be31-1745394e1130','287cffed-71ac-4b66-8552-4aadd6cbf3dc','Hey, are you a BITS student?','text','2026-05-16T06:58:47.000Z'),
('c3f67e17-c79e-49c7-8ef4-ef33f7e4d8df',NULL,'1e3fc87a-cc15-46fb-be31-1745394e1130','a484a03b-1cb9-4790-835b-64245238bcda','Anyone need a phone charger? I have a multi-port','text','2026-05-15T18:36:48.473Z'),
('57a81a55-3a9f-4b1b-8a06-dfae14bebad3',NULL,'1e3fc87a-cc15-46fb-be31-1745394e1130','287cffed-71ac-4b66-8552-4aadd6cbf3dc','Just saw a peacock from the window 😂','text','2026-05-15T18:33:20.516Z'),
('463e0026-f56e-4e73-aeb0-df319282e565',NULL,'1e3fc87a-cc15-46fb-be31-1745394e1130','287cffed-71ac-4b66-8552-4aadd6cbf3dc','Just saw a peacock from the window 😂','text','2026-05-15T03:41:27.675Z'),
('765a7ae6-e50e-45d3-a2f9-a72cce27e581',NULL,'1e3fc87a-cc15-46fb-be31-1745394e1130','97b03499-1962-4087-b478-48102f464a91','Just joined this group, hi everyone 👋','text','2026-05-14T22:49:31.470Z'),
('98b551ee-b657-455e-bff5-64a5ae68bcf8','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'380997d4-59cd-41f2-9f95-a97b1a65c25b','The WiFi here is surprisingly good','text','2026-05-15T07:28:28.003Z'),
('d7706ca6-f53f-47ea-8b47-51ee70057d4d','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'a484a03b-1cb9-4790-835b-64245238bcda','We should plan a meetup once we reach!','text','2026-05-14T08:39:00.308Z'),
('d1ea5950-7c0d-4f13-b645-b5156d56c7a5','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','Hey, are you a BITS student?','text','2026-05-16T02:29:52.812Z'),
('9c192b0a-153f-405d-a886-6fc8d0066509','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'73250fab-0868-4148-a348-e1654293fbab','Which coach are you all in?','text','2026-05-15T00:41:06.780Z'),
('c6f77345-e1bc-47c8-9fab-3c0a9bd6424f','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'a484a03b-1cb9-4790-835b-64245238bcda','I have extra snacks if anyone wants','text','2026-05-14T11:28:44.164Z'),
('009c8d3c-5698-4b90-baac-6fd3643f1b28','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'7a348d56-91d8-4610-959b-0fc29c14686e','Which hostel are you in?','text','2026-05-14T12:10:14.271Z'),
('732fb6d1-1ef8-4c49-acac-90ebbd5fd735','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'a484a03b-1cb9-4790-835b-64245238bcda','Just joined this group, hi everyone 👋','text','2026-05-13T16:29:44.034Z'),
('a4f85337-2f29-4c1d-a087-d986481f1a2b','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'73250fab-0868-4148-a348-e1654293fbab','Anyone need a phone charger? I have a multi-port','text','2026-05-13T11:30:11.240Z'),
('691412c7-3ace-4eaf-aa67-9c0825a19467','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'73250fab-0868-4148-a348-e1654293fbab','Anyone else nervous about the semester starting?','text','2026-05-14T03:51:13.083Z'),
('aab1baf6-10c2-46e2-a2a5-a2dd718bed51','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'a484a03b-1cb9-4790-835b-64245238bcda','Has anyone booked a cab from the station?','text','2026-05-14T03:30:49.154Z'),
('ed8c4bd3-e0be-4b6b-afc6-363d386db7ac','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'97b03499-1962-4087-b478-48102f464a91','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-15T06:30:37.742Z'),
('5b6380c6-3df6-452e-b65c-6cc68a9d6ed8','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','What time does this reach the destination?','text','2026-05-13T13:06:30.331Z'),
('9b83639e-09c9-4eef-87cc-3f383d7913d2','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','The platform number is 4, confirmed on the app','text','2026-05-13T23:50:09.292Z'),
('765a1002-e43a-40ad-9e36-62c9dc475e19','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'73250fab-0868-4148-a348-e1654293fbab','Confirmed — upper berth in coach B4','text','2026-05-13T20:24:01.664Z'),
('a136f556-71a7-4781-b875-2c804a5b69e4','212f75e6-5329-4efd-b275-b11adc94abe0',NULL,'97b03499-1962-4087-b478-48102f464a91','Anyone want to play cards?','text','2026-05-13T12:36:44.667Z'),
('0db22b95-537a-4b30-a9b9-34665dff45d1',NULL,'2a995f9a-2448-418c-8fb5-8baede01dc7f','73250fab-0868-4148-a348-e1654293fbab','Will we reach on time or is there a delay?','text','2026-05-16T01:30:17.781Z'),
('36b7d1a4-1b57-4669-9804-94d4e2a86b1e',NULL,'2a995f9a-2448-418c-8fb5-8baede01dc7f','72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','There is a nice sunset view from the left side right now!','text','2026-05-15T13:51:51.948Z'),
('62233193-5d96-4efa-9c80-86d9ef94b451',NULL,'2a995f9a-2448-418c-8fb5-8baede01dc7f','72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','The platform number is 4, confirmed on the app','text','2026-05-14T15:27:59.541Z'),
('3c25f404-d7d7-4dd8-8adc-7e115b80a72e',NULL,'2a995f9a-2448-418c-8fb5-8baede01dc7f','a484a03b-1cb9-4790-835b-64245238bcda','Anyone from Delhi NCR here?','text','2026-05-14T21:36:37.100Z'),
('8bc82da8-59bd-4cd2-b67b-4131a0576faf',NULL,'2a995f9a-2448-418c-8fb5-8baede01dc7f','97b03499-1962-4087-b478-48102f464a91','Anyone want to play cards?','text','2026-05-14T15:15:56.822Z'),
('9364f32e-1a95-42a7-88fe-5af163091860',NULL,'2a995f9a-2448-418c-8fb5-8baede01dc7f','287cffed-71ac-4b66-8552-4aadd6cbf3dc','Pantry car food is decent today','text','2026-05-15T08:49:24.889Z'),
('fe4a7356-7c4e-4372-9ad7-3725f3c2e732',NULL,'2a995f9a-2448-418c-8fb5-8baede01dc7f','287cffed-71ac-4b66-8552-4aadd6cbf3dc','Has anyone booked a cab from the station?','text','2026-05-16T03:49:49.733Z'),
('f574d8d8-78c4-426b-8b85-79337a20df17',NULL,'2a995f9a-2448-418c-8fb5-8baede01dc7f','72afeabc-2913-4a6d-b0c0-5ad7bb25e71b','Can someone save a seat? BRB getting water','text','2026-05-15T16:17:57.627Z'),
('83c5a1a2-697f-40ee-9580-3c2546961ddf',NULL,'2a995f9a-2448-418c-8fb5-8baede01dc7f','a484a03b-1cb9-4790-835b-64245238bcda','Anyone doing their internship in Bangalore?','text','2026-05-15T06:33:10.454Z'),
('d7e1dd8e-0c75-482c-ab4c-e0386c61d614','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'9340edc8-05a5-4c4a-8c73-2a35ad4bfec6','Anyone from Delhi NCR here?','text','2026-05-14T21:06:38.086Z'),
('2ad6b533-4ee3-45e5-bc59-d9a9008ea9b9','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'c6cac135-7583-4250-a794-189b972b8fc9','Anyone from Delhi NCR here?','text','2026-05-14T13:40:58.746Z'),
('5bc79ed0-6b4d-4c51-a03c-dd100eaec705','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'c6cac135-7583-4250-a794-189b972b8fc9','Anyone need a phone charger? I have a multi-port','text','2026-05-16T09:12:57.726Z'),
('24c5687a-ac10-4052-9f83-4799823ee84d','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'c6cac135-7583-4250-a794-189b972b8fc9','Just joined this group, hi everyone 👋','text','2026-05-15T22:35:51.743Z'),
('e089f4b1-a583-4933-bbf0-814660fc9048','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'9340edc8-05a5-4c4a-8c73-2a35ad4bfec6','Pantry car food is decent today','text','2026-05-16T00:30:29.938Z'),
('3afc7e75-3b51-462b-85a8-6defae5b611a','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'c6cac135-7583-4250-a794-189b972b8fc9','Anyone want to play cards?','text','2026-05-13T16:39:54.423Z'),
('a7719b30-db59-492f-879d-be2044409bc2','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'be8c4d41-4490-481c-a7f9-6cb6f65d9866','Great trip so far, met some awesome people here!','text','2026-05-14T19:52:33.279Z'),
('6c714762-a7b5-420b-883f-b60cee10720d','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'be8c4d41-4490-481c-a7f9-6cb6f65d9866','There is a nice sunset view from the left side right now!','text','2026-05-15T19:31:56.052Z'),
('e77b7f83-2d65-4891-b0c9-1bc63f2ce6a9','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'9340edc8-05a5-4c4a-8c73-2a35ad4bfec6','Will we reach on time or is there a delay?','text','2026-05-14T06:52:43.177Z'),
('904924d3-a0ea-436f-a05a-287dcda841f0','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'c6cac135-7583-4250-a794-189b972b8fc9','What time does this reach the destination?','text','2026-05-14T22:59:35.210Z'),
('966c7c93-fb4e-42e2-9f6f-7a5971c4ab16','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'0412662f-98b9-4fda-a1b4-4173f2c27ad4','Confirmed — upper berth in coach B4','text','2026-05-16T06:36:53.829Z'),
('69a5632f-0e99-4a6f-8e88-da49289d0284','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'be8c4d41-4490-481c-a7f9-6cb6f65d9866','Which coach are you all in?','text','2026-05-15T00:24:04.577Z'),
('3e3482e9-6a67-40c0-936f-915695e38431','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'be8c4d41-4490-481c-a7f9-6cb6f65d9866','Anyone doing their internship in Bangalore?','text','2026-05-14T14:00:51.476Z'),
('d598c6df-1df8-4240-87e7-ffce0d863da9','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'c6cac135-7583-4250-a794-189b972b8fc9','Can someone save a seat? BRB getting water','text','2026-05-15T03:04:43.473Z'),
('8b354384-476f-4459-b83a-381197df8537','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'be8c4d41-4490-481c-a7f9-6cb6f65d9866','We should plan a meetup once we reach!','text','2026-05-13T17:25:55.260Z'),
('5a0e9339-84a6-443c-bdd3-7be039b9d582','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'0412662f-98b9-4fda-a1b4-4173f2c27ad4','There is a nice sunset view from the left side right now!','text','2026-05-15T15:02:48.510Z'),
('394e0a7f-b094-44d3-b873-41ae14372ca0','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'9340edc8-05a5-4c4a-8c73-2a35ad4bfec6','Anyone from Delhi NCR here?','text','2026-05-15T19:22:26.834Z'),
('60417b45-2b89-4964-9937-18f45ff95a4c','674ed3e0-2f82-425e-a6c9-89c2df478bac',NULL,'be8c4d41-4490-481c-a7f9-6cb6f65d9866','Hey everyone! Anyone need help with luggage?','text','2026-05-15T16:24:48.772Z'),
('579df2bb-7cc0-4830-99ff-777ee944a5a1',NULL,'2485b98a-3013-43e0-bd66-68cfccd069c9','be8c4d41-4490-481c-a7f9-6cb6f65d9866','Great trip so far, met some awesome people here!','text','2026-05-16T09:44:33.155Z'),
('451d8f44-b08e-4a4a-86c4-b2b46b73f8c7',NULL,'2485b98a-3013-43e0-bd66-68cfccd069c9','be8c4d41-4490-481c-a7f9-6cb6f65d9866','Anyone from Delhi NCR here?','text','2026-05-16T05:52:55.295Z'),
('8cdb0506-1cd5-41cc-b96e-cec5c57da8c4',NULL,'2485b98a-3013-43e0-bd66-68cfccd069c9','be8c4d41-4490-481c-a7f9-6cb6f65d9866','Anyone need a phone charger? I have a multi-port','text','2026-05-15T09:39:42.056Z'),
('a8ff1900-e23d-4ead-b5f5-d0dbff916be6',NULL,'2485b98a-3013-43e0-bd66-68cfccd069c9','c6cac135-7583-4250-a794-189b972b8fc9','First time traveling alone, this group is a lifesaver!','text','2026-05-15T03:01:29.857Z'),
('1a6098f9-5037-491f-a3b5-2affcacd66e1',NULL,'2485b98a-3013-43e0-bd66-68cfccd069c9','c6cac135-7583-4250-a794-189b972b8fc9','Hey everyone! Anyone need help with luggage?','text','2026-05-16T08:39:56.268Z'),
('58f39e30-7b45-49d6-8316-cf01b7e9a043','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'955b7867-3dfe-4a2a-91ce-600feb668284','Has anyone booked a cab from the station?','text','2026-05-13T23:39:23.703Z'),
('b3902abd-467e-4c30-9538-00e5d6c28b68','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'955b7867-3dfe-4a2a-91ce-600feb668284','Can someone save a seat? BRB getting water','text','2026-05-14T23:48:08.912Z'),
('b32358e8-0e40-4e14-a17f-c404f7854992','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'955b7867-3dfe-4a2a-91ce-600feb668284','Is the AC working in S4? Feels warm','text','2026-05-16T08:25:41.272Z'),
('59cfdf99-ac99-49c0-893c-503a8d4cc87a','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'955b7867-3dfe-4a2a-91ce-600feb668284','The platform number is 4, confirmed on the app','text','2026-05-14T07:47:00.804Z'),
('e9fcdf20-9a7c-4de1-82fc-88749c37c80e','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'d98aa471-cb45-4263-936f-87b6a955f196','Hey everyone! Anyone need help with luggage?','text','2026-05-15T12:15:13.969Z'),
('e61ee856-72c0-40f9-8c73-4eaf32408757','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'d98aa471-cb45-4263-936f-87b6a955f196','There is a nice sunset view from the left side right now!','text','2026-05-16T00:24:00.567Z'),
('a54b8f37-dd39-4894-bb98-33b06c3b692b','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'955b7867-3dfe-4a2a-91ce-600feb668284','Anyone from Delhi NCR here?','text','2026-05-14T00:00:28.371Z'),
('10129586-db57-4da6-aba2-4c023c10b802','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'955b7867-3dfe-4a2a-91ce-600feb668284','Just saw a peacock from the window 😂','text','2026-05-14T15:23:58.628Z'),
('2e17adc1-5953-465e-bdb3-90b17d113180','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'0863b4e8-e752-4c04-837e-419f091fe3dd','Will we reach on time or is there a delay?','text','2026-05-14T19:38:08.562Z'),
('ec02ebb7-4bb0-415f-93d1-f774233b4be3','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'955b7867-3dfe-4a2a-91ce-600feb668284','The train is running 30 min late btw','text','2026-05-13T19:34:32.288Z'),
('09db1585-1957-4522-acde-7802efc6601e','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'d98aa471-cb45-4263-936f-87b6a955f196','The train is running 30 min late btw','text','2026-05-14T20:36:08.498Z'),
('d37e6b05-cd02-44ff-8eca-e708dbb9f7f3','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'d98aa471-cb45-4263-936f-87b6a955f196','The train is running 30 min late btw','text','2026-05-16T06:51:27.737Z'),
('ae9c48f8-ea72-43d7-acbc-1b47a5087964','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'0863b4e8-e752-4c04-837e-419f091fe3dd','Great trip so far, met some awesome people here!','text','2026-05-16T08:35:57.861Z'),
('52052d80-fda3-4d43-8c50-a395992902eb','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'955b7867-3dfe-4a2a-91ce-600feb668284','We should plan a meetup once we reach!','text','2026-05-14T16:55:36.403Z'),
('9971559b-dbe3-408f-830f-6509b4537159','0a8a42df-47a3-4090-b4ac-48fc58102e8b',NULL,'d98aa471-cb45-4263-936f-87b6a955f196','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-14T05:11:28.056Z'),
('13015d6e-e1f8-45da-8529-f5bb599e27f8',NULL,'81c6e387-c3bc-4e32-9f01-516793a0fdaf','955b7867-3dfe-4a2a-91ce-600feb668284','The WiFi here is surprisingly good','text','2026-05-14T14:39:37.236Z'),
('4521b7c1-b6fb-4a67-b4b6-32df69a3829a',NULL,'81c6e387-c3bc-4e32-9f01-516793a0fdaf','955b7867-3dfe-4a2a-91ce-600feb668284','The WiFi here is surprisingly good','text','2026-05-15T00:14:55.243Z'),
('30394c08-c901-431b-b3bc-f7ee1d28ed59',NULL,'81c6e387-c3bc-4e32-9f01-516793a0fdaf','955b7867-3dfe-4a2a-91ce-600feb668284','Will we reach on time or is there a delay?','text','2026-05-15T03:15:04.697Z'),
('2d387a2a-9b1f-4ad8-8b10-0974dd47582a',NULL,'81c6e387-c3bc-4e32-9f01-516793a0fdaf','d98aa471-cb45-4263-936f-87b6a955f196','Anyone need a phone charger? I have a multi-port','text','2026-05-14T14:14:44.719Z'),
('835e6a32-53fb-408a-99e0-76a321f47485',NULL,'81c6e387-c3bc-4e32-9f01-516793a0fdaf','955b7867-3dfe-4a2a-91ce-600feb668284','Hey everyone! Anyone need help with luggage?','text','2026-05-14T13:43:35.637Z'),
('1779aefe-f9b3-4214-8d39-7ffa7b9097bb',NULL,'81c6e387-c3bc-4e32-9f01-516793a0fdaf','955b7867-3dfe-4a2a-91ce-600feb668284','Is the AC working in S4? Feels warm','text','2026-05-14T10:56:56.952Z'),
('c8e5fee8-f4e7-45c9-9b03-dc2d06408d5e',NULL,'81c6e387-c3bc-4e32-9f01-516793a0fdaf','955b7867-3dfe-4a2a-91ce-600feb668284','Which hostel are you in?','text','2026-05-15T00:21:48.118Z'),
('07519f32-e7cb-45d0-8271-18b473975205',NULL,'81c6e387-c3bc-4e32-9f01-516793a0fdaf','0863b4e8-e752-4c04-837e-419f091fe3dd','Is the AC working in S4? Feels warm','text','2026-05-16T06:36:11.517Z'),
('0ff2e39c-b1be-40f9-b223-1250345d73d4',NULL,'81c6e387-c3bc-4e32-9f01-516793a0fdaf','955b7867-3dfe-4a2a-91ce-600feb668284','The platform number is 4, confirmed on the app','text','2026-05-16T04:35:43.152Z'),
('cedd99ca-3606-4fcf-8203-271868702c43',NULL,'81c6e387-c3bc-4e32-9f01-516793a0fdaf','d98aa471-cb45-4263-936f-87b6a955f196','Just joined this group, hi everyone 👋','text','2026-05-14T14:43:46.704Z'),
('89280b28-24b5-48e0-9b6b-f094ddb009d4','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'ee94d5e1-b558-4c66-bc3e-7d603dfb21e1','Just joined this group, hi everyone 👋','text','2026-05-13T11:07:03.067Z'),
('7d602520-f3ca-4762-9525-e095c2da5f23','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'b6ac128c-ca95-438e-b6e5-e1b850f78352','We should plan a meetup once we reach!','text','2026-05-15T18:21:03.567Z'),
('1071010c-8b04-45d5-ba03-91ee6033daa9','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'6a3f8cad-ce91-4c37-985c-2c2a2a6f5851','We can share a cab if you are going towards the same direction','text','2026-05-16T00:50:03.799Z'),
('157380d8-c32c-43f2-aca5-43ad8273017c','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'8645c745-a0a1-4ea7-89ff-ca7cd6a9074f','Same batch! Which branch?','text','2026-05-16T01:40:48.186Z'),
('19317642-0084-4f6d-bd2a-b7f9062d4a5e','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'bfa15c31-e6cb-4704-a3fe-ecb67862c1ed','Anyone want to play cards?','text','2026-05-15T10:50:08.653Z'),
('07ad023e-29f7-4a2d-a343-97e7f917b178','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'b6ac128c-ca95-438e-b6e5-e1b850f78352','We should plan a meetup once we reach!','text','2026-05-15T07:20:52.058Z'),
('77015686-24b4-44c5-bdf4-0ff76d643109','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'ee94d5e1-b558-4c66-bc3e-7d603dfb21e1','First time traveling alone, this group is a lifesaver!','text','2026-05-13T20:35:36.834Z'),
('c88f7c18-d12a-41c9-8d9c-c471d2cfa399','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'8645c745-a0a1-4ea7-89ff-ca7cd6a9074f','Just saw a peacock from the window 😂','text','2026-05-15T23:53:24.636Z'),
('37228b74-093f-40b1-935d-a56019c75da1','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'b6ac128c-ca95-438e-b6e5-e1b850f78352','The WiFi here is surprisingly good','text','2026-05-14T19:12:11.062Z'),
('34928345-306e-4bc3-b7d6-483050f8252f','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'8645c745-a0a1-4ea7-89ff-ca7cd6a9074f','Anyone from Delhi NCR here?','text','2026-05-14T15:48:38.913Z'),
('a6064d03-ace9-4e39-8b18-5abdeaac4c68','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'ee94d5e1-b558-4c66-bc3e-7d603dfb21e1','Anyone need a phone charger? I have a multi-port','text','2026-05-15T04:28:24.861Z'),
('5affaa6d-443d-457f-9e93-fcf3101fa718','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'8645c745-a0a1-4ea7-89ff-ca7cd6a9074f','Pantry car food is decent today','text','2026-05-14T11:45:12.691Z'),
('9172bc8b-a5f3-4909-94dd-18f5768cf9ab','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'4d0a152e-ea34-4f15-a703-309516ee6b4d','Has anyone booked a cab from the station?','text','2026-05-14T12:12:30.447Z'),
('bbe6be44-3c01-415e-84fa-ef5379ec257b','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'ee94d5e1-b558-4c66-bc3e-7d603dfb21e1','Is the AC working in S4? Feels warm','text','2026-05-15T00:58:52.062Z'),
('442ce8ff-24fb-4b87-9105-b4441c2d57c0','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'ee94d5e1-b558-4c66-bc3e-7d603dfb21e1','The train is running 30 min late btw','text','2026-05-16T01:04:40.620Z'),
('0fdfa395-7ae9-494a-9fb5-a852c0947fe8',NULL,'8251f57d-95f4-45b5-9dac-f251087c0665','43eaa843-55b6-44b9-943a-f28e2f552f1f','Will we reach on time or is there a delay?','text','2026-05-16T04:38:03.027Z'),
('a4962fb5-b71f-4fff-9e09-629a7c623b27',NULL,'8251f57d-95f4-45b5-9dac-f251087c0665','43eaa843-55b6-44b9-943a-f28e2f552f1f','Can someone save a seat? BRB getting water','text','2026-05-15T13:02:42.978Z'),
('43321ef1-9a81-4773-9b61-a163cfa23855',NULL,'8251f57d-95f4-45b5-9dac-f251087c0665','43eaa843-55b6-44b9-943a-f28e2f552f1f','Same batch! Which branch?','text','2026-05-14T15:50:49.104Z'),
('a9650bfc-38c5-4369-b750-df36e5b58810',NULL,'8251f57d-95f4-45b5-9dac-f251087c0665','6a3f8cad-ce91-4c37-985c-2c2a2a6f5851','Hey, are you a BITS student?','text','2026-05-14T19:30:04.279Z'),
('b4487601-e777-4f04-8b8e-e34b92247c5d',NULL,'8251f57d-95f4-45b5-9dac-f251087c0665','43eaa843-55b6-44b9-943a-f28e2f552f1f','Is the AC working in S4? Feels warm','text','2026-05-15T09:28:09.466Z'),
('91ca90e3-92cd-47b9-a91c-8ce2d2618875','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'43eaa843-55b6-44b9-943a-f28e2f552f1f','The train is running 30 min late btw','text','2026-05-14T03:15:16.250Z'),
('2220a483-fef5-4460-950c-f10557c19989','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'bfa15c31-e6cb-4704-a3fe-ecb67862c1ed','Anyone need a phone charger? I have a multi-port','text','2026-05-14T22:13:09.348Z'),
('0def4a43-4c6f-4917-b77b-19177039ef25','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'8645c745-a0a1-4ea7-89ff-ca7cd6a9074f','There is a nice sunset view from the left side right now!','text','2026-05-14T03:29:31.329Z'),
('bd44450c-6b80-4535-b98c-a8cc9b8e8b1f','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'43eaa843-55b6-44b9-943a-f28e2f552f1f','Anyone from Delhi NCR here?','text','2026-05-14T15:36:20.693Z'),
('df96e426-2611-405b-b643-f03c0475faad','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'ee94d5e1-b558-4c66-bc3e-7d603dfb21e1','We can share a cab if you are going towards the same direction','text','2026-05-15T02:31:22.135Z'),
('078c89f5-db45-4d73-a868-0d3de04c401a','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'6a3f8cad-ce91-4c37-985c-2c2a2a6f5851','Just saw a peacock from the window 😂','text','2026-05-15T15:37:29.570Z'),
('768603e1-1d8d-4738-b665-98cba96cf059','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'bfa15c31-e6cb-4704-a3fe-ecb67862c1ed','Anyone doing their internship in Bangalore?','text','2026-05-15T06:50:52.692Z'),
('c70f669b-6bf1-4fe3-a70b-d02c40528ce2','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'4d0a152e-ea34-4f15-a703-309516ee6b4d','Will we reach on time or is there a delay?','text','2026-05-15T16:08:34.792Z'),
('4dfeb74a-d02b-446a-8d7e-73a9d0834791','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'b6ac128c-ca95-438e-b6e5-e1b850f78352','The platform number is 4, confirmed on the app','text','2026-05-16T00:14:31.026Z'),
('bf3ffd62-ad03-4ce0-866e-8c8514f83b0d','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'ee94d5e1-b558-4c66-bc3e-7d603dfb21e1','Pantry car food is decent today','text','2026-05-14T11:31:27.894Z'),
('8e304f1f-ee5f-4b9c-a464-81325338ea5b','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'b6ac128c-ca95-438e-b6e5-e1b850f78352','Has anyone booked a cab from the station?','text','2026-05-14T09:25:31.661Z'),
('f0dbe9b4-ca50-416e-9e30-2e85ed281bb0','70fe2452-f1f6-4e8b-aa08-e93f67b1eb5a',NULL,'43eaa843-55b6-44b9-943a-f28e2f552f1f','Hey everyone! Anyone need help with luggage?','text','2026-05-14T03:56:00.424Z'),
('aa81246f-5f81-4dec-bb15-8ed0f233540f',NULL,'2170616b-461e-4ae5-ae7a-e11e13e67bb4','43eaa843-55b6-44b9-943a-f28e2f552f1f','Anyone doing their internship in Bangalore?','text','2026-05-14T14:13:17.988Z'),
('ae4de7b1-abdd-4d2c-8217-84d787fecdad',NULL,'2170616b-461e-4ae5-ae7a-e11e13e67bb4','4d0a152e-ea34-4f15-a703-309516ee6b4d','Same batch! Which branch?','text','2026-05-14T23:46:07.143Z'),
('79f46f32-0e9c-4a58-acb6-354f72656ef0',NULL,'2170616b-461e-4ae5-ae7a-e11e13e67bb4','43eaa843-55b6-44b9-943a-f28e2f552f1f','We should plan a meetup once we reach!','text','2026-05-15T16:34:15.445Z'),
('22afa289-2465-4d55-b634-90562306b44e',NULL,'2170616b-461e-4ae5-ae7a-e11e13e67bb4','43eaa843-55b6-44b9-943a-f28e2f552f1f','There is a nice sunset view from the left side right now!','text','2026-05-14T10:29:39.946Z'),
('53a8f3bc-eed3-427b-8f4f-9a2e5f5a5bba',NULL,'2170616b-461e-4ae5-ae7a-e11e13e67bb4','4d0a152e-ea34-4f15-a703-309516ee6b4d','Will we reach on time or is there a delay?','text','2026-05-15T14:27:24.464Z'),
('d4c0ceef-9da5-4caa-b4af-40e4cf12c922',NULL,'2170616b-461e-4ae5-ae7a-e11e13e67bb4','4d0a152e-ea34-4f15-a703-309516ee6b4d','Great trip so far, met some awesome people here!','text','2026-05-14T23:58:10.095Z'),
('642088d8-a83c-49f9-93ed-87aae18a71a2','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'63a974f3-6530-40b4-892f-1a620b38563e','Which coach are you all in?','text','2026-05-16T04:08:39.184Z'),
('3d961a74-4ff9-484c-91e8-dc4d0c2da61d','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'2daa15f6-74b4-4c83-9153-edb6c92317e8','The platform number is 4, confirmed on the app','text','2026-05-16T07:29:57.879Z'),
('31d032c0-41da-462b-b3cf-40567b6f6f7a','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','I have extra snacks if anyone wants','text','2026-05-14T01:56:19.070Z'),
('86f3865c-ea66-4a9a-9562-03e32820e619','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','Do not forget to check your PNR status','text','2026-05-15T06:17:24.565Z'),
('949ec312-7d3c-4c1c-b2c8-95a3c4dc79a1','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'2daa15f6-74b4-4c83-9153-edb6c92317e8','Anyone else nervous about the semester starting?','text','2026-05-14T12:00:45.530Z'),
('b805dbc9-ca05-4ab5-931f-59684fef7535','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','Anyone want to play cards?','text','2026-05-16T00:41:47.864Z'),
('ec7f54d3-5697-4370-b721-c723d0472dc9','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'2daa15f6-74b4-4c83-9153-edb6c92317e8','Anyone want to play cards?','text','2026-05-16T08:06:06.596Z'),
('a019c765-a532-4f5c-b91b-d8654d1d3641','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'63a974f3-6530-40b4-892f-1a620b38563e','We should plan a meetup once we reach!','text','2026-05-13T15:39:30.754Z'),
('8428b3f2-821f-4dad-bdcd-97d974016044',NULL,'b9cefe96-66e3-405b-9da1-d85a2b0e47d3','63a974f3-6530-40b4-892f-1a620b38563e','Anyone doing their internship in Bangalore?','text','2026-05-14T10:38:00.341Z'),
('b0abed9d-0463-46d1-97ac-568e4c45c922',NULL,'b9cefe96-66e3-405b-9da1-d85a2b0e47d3','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','We should plan a meetup once we reach!','text','2026-05-15T22:07:13.569Z'),
('f94260de-76c1-4d0e-b58e-f9ab6ef0cccd',NULL,'b9cefe96-66e3-405b-9da1-d85a2b0e47d3','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','Do not forget to check your PNR status','text','2026-05-14T19:32:24.914Z'),
('bfbc868b-1c8a-468c-a289-2a0691315cef',NULL,'b9cefe96-66e3-405b-9da1-d85a2b0e47d3','63a974f3-6530-40b4-892f-1a620b38563e','Do not forget to check your PNR status','text','2026-05-15T08:24:38.547Z'),
('9191e820-d7dc-46d0-b96d-cdaa99a147fd',NULL,'b9cefe96-66e3-405b-9da1-d85a2b0e47d3','63a974f3-6530-40b4-892f-1a620b38563e','Hey everyone! Anyone need help with luggage?','text','2026-05-16T09:44:05.602Z'),
('0c1f225f-351a-4b24-aefd-794404f281da',NULL,'b9cefe96-66e3-405b-9da1-d85a2b0e47d3','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','The WiFi here is surprisingly good','text','2026-05-14T14:54:35.124Z'),
('0670a1e5-1f43-48b2-90b9-06d877b7739e',NULL,'b9cefe96-66e3-405b-9da1-d85a2b0e47d3','63a974f3-6530-40b4-892f-1a620b38563e','Great trip so far, met some awesome people here!','text','2026-05-16T08:11:47.933Z'),
('3183fef3-a593-453d-aeb1-132a303444b5',NULL,'b9cefe96-66e3-405b-9da1-d85a2b0e47d3','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','Confirmed — upper berth in coach B4','text','2026-05-15T20:11:57.288Z'),
('dc865bda-b9bb-42f7-a0b6-28e602f4eded',NULL,'b9cefe96-66e3-405b-9da1-d85a2b0e47d3','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','Just joined this group, hi everyone 👋','text','2026-05-15T12:47:48.225Z'),
('d9b84496-1889-45a1-b3de-f2a896c75882','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','What time does this reach the destination?','text','2026-05-14T09:52:01.836Z'),
('da67feb9-0ac9-42aa-b2cb-554f9ed7bc47','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','We should plan a meetup once we reach!','text','2026-05-13T13:36:38.129Z'),
('1c36d241-06f0-43fd-8151-cce5cf72311d','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','Confirmed — upper berth in coach B4','text','2026-05-14T09:12:55.828Z'),
('ea24c6ee-2f80-453d-97a3-b123851e73b3','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'2daa15f6-74b4-4c83-9153-edb6c92317e8','There is a nice sunset view from the left side right now!','text','2026-05-13T17:58:20.583Z'),
('8b8f572a-d717-4bdd-9c96-1fd9f124c808','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'63a974f3-6530-40b4-892f-1a620b38563e','Anyone doing their internship in Bangalore?','text','2026-05-14T06:26:43.297Z'),
('5ab4cb38-08b3-4856-b1bf-2c69a18da517','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','The platform number is 4, confirmed on the app','text','2026-05-16T03:18:58.508Z'),
('9b23ab48-202c-4ed2-852a-cb93045d4c4c','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','Hey, are you a BITS student?','text','2026-05-13T17:34:13.795Z'),
('58287921-8c81-4691-841f-f61db9b891da','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','Which hostel are you in?','text','2026-05-15T08:06:04.843Z'),
('a4bb1674-c793-4e5b-aa51-cd604792d7e7','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'f889eee5-8ed8-434c-8a5e-7e8c161bfbf7','The platform number is 4, confirmed on the app','text','2026-05-14T14:04:07.595Z'),
('dc0db984-0da6-40d9-938e-c7a4a09657e1','2c056cd6-a81f-4d20-96c9-8c5e4e2fc34b',NULL,'a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','The WiFi here is surprisingly good','text','2026-05-14T05:21:16.188Z'),
('dbae3fd1-2aa7-4ea8-abbf-277f7b6d602b',NULL,'6ffca139-039c-4e54-92d0-7c852ce86147','63a974f3-6530-40b4-892f-1a620b38563e','Has anyone booked a cab from the station?','text','2026-05-15T08:44:13.875Z'),
('1a01f0e4-98db-4b71-9d37-d809ae6d9983',NULL,'6ffca139-039c-4e54-92d0-7c852ce86147','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','Same batch! Which branch?','text','2026-05-14T11:50:19.005Z'),
('8cdc66a9-e5bd-4b7f-b303-c26433a0d1ca',NULL,'6ffca139-039c-4e54-92d0-7c852ce86147','63a974f3-6530-40b4-892f-1a620b38563e','Just joined this group, hi everyone 👋','text','2026-05-16T00:55:57.334Z'),
('5b355fd7-07b1-4290-b51a-d7c2bba54ff7',NULL,'6ffca139-039c-4e54-92d0-7c852ce86147','2daa15f6-74b4-4c83-9153-edb6c92317e8','Anyone doing their internship in Bangalore?','text','2026-05-14T19:06:53.051Z'),
('54d95dd5-8a04-4fb2-a52d-163564a77ab8',NULL,'6ffca139-039c-4e54-92d0-7c852ce86147','63a974f3-6530-40b4-892f-1a620b38563e','Anyone from Delhi NCR here?','text','2026-05-14T12:04:31.754Z'),
('5f940d76-39c7-4311-a16c-f7847762bed3',NULL,'6ffca139-039c-4e54-92d0-7c852ce86147','2daa15f6-74b4-4c83-9153-edb6c92317e8','What time does this reach the destination?','text','2026-05-15T11:57:42.427Z'),
('2046d2f1-1d20-4ffe-ac18-88444c23c2e5',NULL,'6ffca139-039c-4e54-92d0-7c852ce86147','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','What time does this reach the destination?','text','2026-05-14T17:38:30.958Z'),
('1209cf64-0cac-48a1-a727-9fd2b8aebd35',NULL,'6ffca139-039c-4e54-92d0-7c852ce86147','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','Is the AC working in S4? Feels warm','text','2026-05-15T00:08:29.509Z'),
('d32ebbd6-e100-4d9a-8a66-44459cc97ea5',NULL,'6ffca139-039c-4e54-92d0-7c852ce86147','a2840441-c60d-48fd-aa4f-a5c7ce7b22b7','Pantry car food is decent today','text','2026-05-15T15:36:22.525Z'),
('87db502d-7b39-4634-bc70-6a36fc3b3330',NULL,'6ffca139-039c-4e54-92d0-7c852ce86147','2daa15f6-74b4-4c83-9153-edb6c92317e8','Can someone save a seat? BRB getting water','text','2026-05-15T01:17:59.110Z'),
('69a0c8d9-f89c-4b61-9125-0cc314245148','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'d0ff8ce3-8f3a-4afb-b2c7-c28b13651a84','Anyone need a phone charger? I have a multi-port','text','2026-05-15T17:16:51.062Z'),
('dba7054c-c31b-4bf2-8a02-e82f7d83b83b','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','Great trip so far, met some awesome people here!','text','2026-05-13T23:20:18.119Z'),
('b776c234-82f3-4b05-9e39-f234a67ace69','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'dd32fda6-6a98-4538-a5c5-c21092fd78e4','I have extra snacks if anyone wants','text','2026-05-14T04:28:59.810Z'),
('129456a5-5c6a-49e3-8c69-dbbca697b7b7','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'6125af0e-06f0-464b-b752-bbbe0d5b6b27','Hey, are you a BITS student?','text','2026-05-13T20:57:03.148Z'),
('8269cc01-ed1e-4853-b16c-5b1d0adce8dc','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','Great trip so far, met some awesome people here!','text','2026-05-15T00:22:39.520Z'),
('cc266290-395b-41ef-b28a-d11f0d9a8a60','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'6125af0e-06f0-464b-b752-bbbe0d5b6b27','Anyone from Delhi NCR here?','text','2026-05-13T21:16:21.100Z'),
('d5052adb-20bd-477e-8278-2f0552e2a06b','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'dd32fda6-6a98-4538-a5c5-c21092fd78e4','Has anyone booked a cab from the station?','text','2026-05-14T08:10:36.213Z'),
('127aad3f-1210-4583-8e99-a0af240a5457','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'d0ff8ce3-8f3a-4afb-b2c7-c28b13651a84','The platform number is 4, confirmed on the app','text','2026-05-16T00:27:49.954Z'),
('70424ab8-9a98-4a7a-b599-0d04a3c83c2d','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'d0ff8ce3-8f3a-4afb-b2c7-c28b13651a84','Great trip so far, met some awesome people here!','text','2026-05-16T08:55:45.681Z'),
('7589cf7b-20ac-431d-a87b-a204189d8dfc','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','Is the AC working in S4? Feels warm','text','2026-05-15T11:43:13.302Z'),
('258fbd36-f5cb-4e5b-b787-91b69552dd2a','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-16T04:18:52.686Z'),
('339a137b-81ff-485f-b57d-4aafec6f6a04',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','e7a41005-3e6d-434f-bd4d-b38fcaf970d1','Confirmed — upper berth in coach B4','text','2026-05-14T18:10:51.899Z'),
('bed8de9d-299f-4c11-9770-3498b56ce021',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','dd32fda6-6a98-4538-a5c5-c21092fd78e4','Anyone doing their internship in Bangalore?','text','2026-05-15T04:12:47.146Z'),
('83629621-33cc-45de-9903-ff5b15a26c2e',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','Do not forget to check your PNR status','text','2026-05-15T03:38:58.413Z'),
('4301d15b-78ed-44a0-bdb8-901af829b1a7',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','4f270acd-505b-44ce-86ba-538743a770e5','Is the AC working in S4? Feels warm','text','2026-05-14T11:38:31.051Z'),
('87633ce6-238a-47b8-95fa-bdeb6a57141c',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','e7a41005-3e6d-434f-bd4d-b38fcaf970d1','I have extra snacks if anyone wants','text','2026-05-15T22:41:39.286Z'),
('a27ba61e-69a9-4652-94d6-25a1bc7b617d',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','Is the AC working in S4? Feels warm','text','2026-05-14T21:22:50.728Z'),
('640e877c-8159-4f2b-bc6b-18ec763a56a4',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','e7a41005-3e6d-434f-bd4d-b38fcaf970d1','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-14T19:08:08.989Z'),
('db657a84-5e13-499f-a58c-54b6ecd14b53',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','4f270acd-505b-44ce-86ba-538743a770e5','Hey everyone! Anyone need help with luggage?','text','2026-05-15T02:11:10.727Z'),
('ffe92d03-7ff3-4229-b1f8-4e487f2b8666',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','dd32fda6-6a98-4538-a5c5-c21092fd78e4','The train is running 30 min late btw','text','2026-05-15T18:49:07.479Z'),
('3c01d6ab-6b3b-4e4f-a2d0-0c8a40c37dc7',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','4f270acd-505b-44ce-86ba-538743a770e5','Hey everyone! Anyone need help with luggage?','text','2026-05-15T09:47:38.507Z'),
('56ce58c8-7ddf-47f1-893a-5d69612976aa',NULL,'4e1f9690-3456-44ec-88f4-f250cfe1e5cc','f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','Confirmed — upper berth in coach B4','text','2026-05-15T04:42:13.588Z'),
('a4482700-b24a-46e4-bc31-f01bc01aded3','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'d0ff8ce3-8f3a-4afb-b2c7-c28b13651a84','The WiFi here is surprisingly good','text','2026-05-13T21:11:55.744Z'),
('79fbab86-945f-4a0d-b0c7-c14754d59d65','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'e7a41005-3e6d-434f-bd4d-b38fcaf970d1','Same batch! Which branch?','text','2026-05-15T20:02:29.606Z'),
('67798e42-7fc7-4b70-b7c2-346812ade674','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'e7a41005-3e6d-434f-bd4d-b38fcaf970d1','Same batch! Which branch?','text','2026-05-15T10:40:51.017Z'),
('22574dcf-bbb1-4351-9e42-906252e80e5d','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'dd32fda6-6a98-4538-a5c5-c21092fd78e4','First time traveling alone, this group is a lifesaver!','text','2026-05-16T04:53:23.121Z'),
('5834e5d5-6f8c-46b7-9e34-ce8c2e8267ee','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'d0ff8ce3-8f3a-4afb-b2c7-c28b13651a84','Anyone need a phone charger? I have a multi-port','text','2026-05-14T16:22:19.385Z'),
('9bb55256-177c-49d3-8156-70aaed714e26','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'d0ff8ce3-8f3a-4afb-b2c7-c28b13651a84','Has anyone booked a cab from the station?','text','2026-05-13T21:29:56.235Z'),
('031944a0-905d-4ceb-bf18-b63d8e137b2d','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'dd32fda6-6a98-4538-a5c5-c21092fd78e4','Which coach are you all in?','text','2026-05-15T03:23:38.071Z'),
('65c8a60b-722d-46dd-bb73-54a401b66aab','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'6125af0e-06f0-464b-b752-bbbe0d5b6b27','Hey, are you a BITS student?','text','2026-05-15T04:09:05.012Z'),
('79f563ec-71ab-4245-aa10-9a5ec55ddbb8','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','Just saw a peacock from the window 😂','text','2026-05-14T15:17:44.048Z'),
('b9ac3e17-80a6-457d-8d50-769ad977c145','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','The train is running 30 min late btw','text','2026-05-15T17:07:30.560Z'),
('c160b72a-5ae4-489a-91ce-bb48d8006433','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'dd32fda6-6a98-4538-a5c5-c21092fd78e4','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-15T20:34:24.471Z'),
('014d85ea-484e-4e4f-abd1-6bf258c73e32','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','The WiFi here is surprisingly good','text','2026-05-14T15:17:06.696Z'),
('1d16f945-ac61-44ac-8988-a7f6e882a376','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'4f270acd-505b-44ce-86ba-538743a770e5','Will we reach on time or is there a delay?','text','2026-05-14T17:15:24.124Z'),
('b198f760-92b3-4a02-9150-a8d9a6ab201c','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'6125af0e-06f0-464b-b752-bbbe0d5b6b27','Hey, are you a BITS student?','text','2026-05-14T13:20:18.335Z'),
('10a609db-6456-44dc-93f5-a0e3b1bab978','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'dd32fda6-6a98-4538-a5c5-c21092fd78e4','Do not forget to check your PNR status','text','2026-05-15T10:33:58.010Z'),
('a3a4f9ea-3ad4-4bd0-8ddd-c4c4cce49ed5','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'6125af0e-06f0-464b-b752-bbbe0d5b6b27','Great trip so far, met some awesome people here!','text','2026-05-14T07:48:21.847Z'),
('82836d2a-739f-4dc2-bc16-976cd9017dae','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'6125af0e-06f0-464b-b752-bbbe0d5b6b27','Hey everyone! Anyone need help with luggage?','text','2026-05-13T14:32:27.657Z'),
('99a8add8-168c-48fc-8638-bc90ebe7a99e','33c0d80a-0479-424a-bfe3-6d9516b223c0',NULL,'dd32fda6-6a98-4538-a5c5-c21092fd78e4','Has anyone booked a cab from the station?','text','2026-05-14T09:08:52.283Z'),
('b1584851-898e-47bd-9b96-3e17e4204543',NULL,'9441e9c1-c153-4c43-b8f2-756b9e52dd3e','e7a41005-3e6d-434f-bd4d-b38fcaf970d1','Pantry car food is decent today','text','2026-05-14T14:50:40.415Z'),
('b2b34960-9e1d-454a-9e4c-5d3a555305d8',NULL,'9441e9c1-c153-4c43-b8f2-756b9e52dd3e','dd32fda6-6a98-4538-a5c5-c21092fd78e4','We should plan a meetup once we reach!','text','2026-05-15T20:46:43.952Z'),
('e2f85a2b-916c-4348-846d-c0255043ce53',NULL,'9441e9c1-c153-4c43-b8f2-756b9e52dd3e','dd32fda6-6a98-4538-a5c5-c21092fd78e4','Is the AC working in S4? Feels warm','text','2026-05-16T05:04:21.583Z'),
('0207ae6b-0bda-4074-86c5-2dc29c8647c2',NULL,'9441e9c1-c153-4c43-b8f2-756b9e52dd3e','dd32fda6-6a98-4538-a5c5-c21092fd78e4','The WiFi here is surprisingly good','text','2026-05-14T14:34:06.171Z'),
('33b3887e-f39a-4831-8fe9-01a55934ff37',NULL,'9441e9c1-c153-4c43-b8f2-756b9e52dd3e','e7a41005-3e6d-434f-bd4d-b38fcaf970d1','Will we reach on time or is there a delay?','text','2026-05-15T17:55:47.102Z'),
('fd8a1728-185e-4575-a784-3b78d4dfdeb1',NULL,'9441e9c1-c153-4c43-b8f2-756b9e52dd3e','6125af0e-06f0-464b-b752-bbbe0d5b6b27','Anyone up for dinner together? There is a good dhaba at the next stop.','text','2026-05-15T00:39:57.256Z'),
('14c20bfe-e5ed-44e7-8d67-ca0d0a04dd08',NULL,'9441e9c1-c153-4c43-b8f2-756b9e52dd3e','f398e25d-ddea-4ced-bbaf-0a0cd0b414cb','There is a nice sunset view from the left side right now!','text','2026-05-16T00:33:47.581Z'),
('9e2ea60e-974b-464c-9729-33f5bac87994',NULL,'9441e9c1-c153-4c43-b8f2-756b9e52dd3e','dd32fda6-6a98-4538-a5c5-c21092fd78e4','What time does this reach the destination?','text','2026-05-16T07:02:19.631Z'),
('03dc6bb0-4af4-46d7-b525-b19bdf89898b',NULL,'9441e9c1-c153-4c43-b8f2-756b9e52dd3e','6125af0e-06f0-464b-b752-bbbe0d5b6b27','What time does this reach the destination?','text','2026-05-14T18:04:48.876Z');

-- Done!