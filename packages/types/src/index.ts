// ── Database row types ────────────────────────────────────────────────────────

export type Gender = 'male' | 'female' | 'other' | 'prefer_not_to_say'
export type JourneyType = 'train' | 'flight' | 'route'
export type RoomType = 'train' | 'flight' | 'route'
export type GroupVisibility = 'public' | 'private'
export type GenderFilter = 'all_boys' | 'all_girls' | 'mixed' | 'any'
export type MemberStatus = 'pending' | 'approved' | 'rejected'
export type MessageType = 'text' | 'system'
export type ReportStatus = 'pending' | 'reviewed' | 'resolved'
export type VerificationType = 'pnr' | 'college'
export type VerificationStatus = 'pending' | 'verified' | 'rejected'

export interface User {
  id: string
  email: string
  name: string
  avatar_url: string | null
  google_id: string
  bio: string | null
  gender: Gender | null
  college_name: string | null
  college_verified: boolean
  pnr_verified: boolean
  is_blocked: boolean
  created_at: string
}

export interface Journey {
  id: string
  user_id: string
  journey_type: JourneyType
  train_number: string | null
  flight_number: string | null
  source: string
  destination: string
  journey_date: string
  pnr_number: string | null
  is_active: boolean
  created_at: string
}

export interface Room {
  id: string
  room_key: string
  room_type: RoomType
  identifier: string | null
  source: string
  destination: string
  journey_date: string
  member_count: number
  created_at: string
}

export interface RoomMember {
  id: string
  room_id: string
  user_id: string
  journey_id: string
  joined_at: string
}

export interface Group {
  id: string
  room_id: string
  creator_id: string
  name: string
  description: string | null
  gender_filter: GenderFilter
  batch_filter: string
  max_members: number
  visibility: GroupVisibility
  requires_approval: boolean
  member_count: number
  created_at: string
}

export interface GroupMember {
  id: string
  group_id: string
  user_id: string
  status: MemberStatus
  joined_at: string
  approved_at: string | null
  approved_by: string | null
}

export interface Message {
  id: string
  room_id: string | null
  group_id: string | null
  sender_id: string
  content: string
  message_type: MessageType
  is_deleted: boolean
  created_at: string
}

export interface Report {
  id: string
  reporter_id: string
  reported_user_id: string
  room_id: string | null
  group_id: string | null
  reason: string
  description: string | null
  status: ReportStatus
  created_at: string
}

export interface Block {
  id: string
  blocker_id: string
  blocked_id: string
  created_at: string
}

export interface Verification {
  id: string
  user_id: string
  type: VerificationType
  document_url: string | null
  status: VerificationStatus
  created_at: string
}

// ── API response shapes ────────────────────────────────────────────────────────

export type PublicUser = Pick<
  User,
  'id' | 'name' | 'avatar_url' | 'bio' | 'gender' | 'college_name' | 'college_verified' | 'pnr_verified' | 'created_at'
>

export interface RoomDetail extends Room {
  members: PublicUser[]
  groups: Group[]
}

export interface GroupDetail extends Group {
  members: (GroupMember & { user: PublicUser })[]
}

export interface MessageWithSender extends Message {
  sender: PublicUser
}

// ── API request body types ─────────────────────────────────────────────────────

export interface CreateJourneyBody {
  journey_type: JourneyType
  train_number?: string
  flight_number?: string
  source: string
  destination: string
  journey_date: string
  pnr_number?: string
}

export interface UpdateProfileBody {
  name?: string
  bio?: string
  gender?: Gender
  college_name?: string
}

export interface CreateGroupBody {
  name: string
  description?: string
  gender_filter?: GenderFilter
  batch_filter?: string
  max_members?: number
  visibility?: GroupVisibility
  requires_approval?: boolean
}

export interface CreateReportBody {
  reported_user_id: string
  reason: string
  description?: string
  room_id?: string
  group_id?: string
}

export interface ApproveMemberBody {
  action: 'approve' | 'reject'
}

// ── Paginated response wrapper ─────────────────────────────────────────────────

export interface Paginated<T> {
  data: T[]
  total: number
  page: number
  limit: number
}
