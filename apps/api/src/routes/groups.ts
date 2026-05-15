import { Hono } from 'hono'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { supabase } from '../lib/supabase'
import { isRoomMember, isGroupMember, isGroupCreator, approveMember, rejectMember } from '../services/groupService'

const app = new Hono()

const PUBLIC_USER_FIELDS = 'id,name,avatar_url,bio,gender,college_name,college_verified,pnr_verified,created_at'

const createGroupSchema = z.object({
  name: z.string().min(1).max(100),
  description: z.string().max(500).optional(),
  gender_filter: z.enum(['all_boys', 'all_girls', 'mixed', 'any']).default('any'),
  batch_filter: z.string().default('any'),
  max_members: z.number().int().min(2).max(50).default(10),
  visibility: z.enum(['public', 'private']).default('public'),
  requires_approval: z.boolean().default(false),
})

// Create group inside a room
app.post('/rooms/:roomId/groups', requireAuth, async (c) => {
  const { roomId } = c.req.param()
  const userId = c.get('user').id

  const isMember = await isRoomMember(roomId, userId)
  if (!isMember) return c.json({ error: 'Must be a room member to create a group' }, 403)

  let body: unknown
  try { body = await c.req.json() } catch { return c.json({ error: 'Invalid JSON' }, 400) }

  const parsed = createGroupSchema.safeParse(body)
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400)

  const { data: group, error } = await supabase
    .from('groups')
    .insert({ room_id: roomId, creator_id: userId, ...parsed.data })
    .select()
    .single()

  if (error) return c.json({ error: error.message }, 500)

  // Auto-add creator as approved member
  await supabase.from('group_members').insert({
    group_id: group.id,
    user_id: userId,
    status: 'approved',
    approved_at: new Date().toISOString(),
    approved_by: userId,
  })

  return c.json({ group }, 201)
})

// List groups in a room
app.get('/rooms/:roomId/groups', requireAuth, async (c) => {
  const { roomId } = c.req.param()
  const { gender_filter, visibility = 'public' } = c.req.query()

  let query = supabase
    .from('groups')
    .select('*')
    .eq('room_id', roomId)

  if (visibility !== 'all') query = query.eq('visibility', visibility)
  if (gender_filter) query = query.eq('gender_filter', gender_filter)

  const { data, error } = await query.order('member_count', { ascending: false })
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ groups: data })
})

// Get group detail
app.get('/groups/:id', requireAuth, async (c) => {
  const { id: groupId } = c.req.param()
  const userId = c.get('user').id

  const { data: group, error } = await supabase.from('groups').select('*').eq('id', groupId).single()
  if (error || !group) return c.json({ error: 'Group not found' }, 404)

  const isMember = await isGroupMember(groupId, userId)
  const isCreator = await isGroupCreator(groupId, userId)

  // Members visible only if user is a member or creator
  let members: unknown[] = []
  if (isMember || isCreator) {
    const { data } = await supabase
      .from('group_members')
      .select(`*, user:users!user_id(${PUBLIC_USER_FIELDS})`)
      .eq('group_id', groupId)
      .in('status', isMember ? ['approved'] : ['approved', 'pending'])
    members = data ?? []
  }

  return c.json({ group, members, isMember, isCreator })
})

// Join group (auto-approve if open, else pending)
app.post('/groups/:id/join', requireAuth, async (c) => {
  const { id: groupId } = c.req.param()
  const userId = c.get('user').id

  const { data: group } = await supabase.from('groups').select('*').eq('id', groupId).single()
  if (!group) return c.json({ error: 'Group not found' }, 404)

  if (group.member_count >= group.max_members) return c.json({ error: 'Group is full' }, 400)

  const isMember = await isRoomMember(group.room_id, userId)
  if (!isMember) return c.json({ error: 'Must join the room first' }, 403)

  const status = group.requires_approval ? 'pending' : 'approved'
  const now = new Date().toISOString()

  const { data, error } = await supabase
    .from('group_members')
    .upsert(
      {
        group_id: groupId,
        user_id: userId,
        status,
        ...(status === 'approved' ? { approved_at: now, approved_by: userId } : {}),
      },
      { onConflict: 'group_id,user_id', ignoreDuplicates: true }
    )
    .select()
    .single()

  if (error) return c.json({ error: error.message }, 500)

  if (status === 'approved') {
    await supabase.rpc('increment_group_member_count', { group_id: groupId })
  }

  return c.json({ member: data, status })
})

// Approve or reject a join request (creator only)
app.put('/groups/:id/members/:userId', requireAuth, async (c) => {
  const { id: groupId, userId: targetUserId } = c.req.param()
  const requesterId = c.get('user').id

  const isCreator = await isGroupCreator(groupId, requesterId)
  if (!isCreator) return c.json({ error: 'Only group creator can manage members' }, 403)

  let body: unknown
  try { body = await c.req.json() } catch { return c.json({ error: 'Invalid JSON' }, 400) }

  const parsed = z.object({ action: z.enum(['approve', 'reject']) }).safeParse(body)
  if (!parsed.success) return c.json({ error: 'action must be approve or reject' }, 400)

  if (parsed.data.action === 'approve') {
    const member = await approveMember(groupId, targetUserId, requesterId)
    return c.json({ member })
  } else {
    await rejectMember(groupId, targetUserId)
    return c.json({ success: true })
  }
})

// Remove member or self-leave
app.delete('/groups/:id/members/:userId', requireAuth, async (c) => {
  const { id: groupId, userId: targetUserId } = c.req.param()
  const requesterId = c.get('user').id

  const isCreator = await isGroupCreator(groupId, requesterId)
  const isSelf = requesterId === targetUserId

  if (!isCreator && !isSelf) return c.json({ error: 'Forbidden' }, 403)

  const { error } = await supabase
    .from('group_members')
    .delete()
    .eq('group_id', groupId)
    .eq('user_id', targetUserId)

  if (error) return c.json({ error: error.message }, 500)

  await supabase.rpc('decrement_group_member_count', { group_id: groupId })
  return c.json({ success: true })
})

// Group message history
app.get('/groups/:id/messages', requireAuth, async (c) => {
  const { id: groupId } = c.req.param()
  const userId = c.get('user').id
  const { before, limit = '50' } = c.req.query()
  const limitNum = Math.min(100, parseInt(limit, 10))

  const isMember = await isGroupMember(groupId, userId)
  if (!isMember) return c.json({ error: 'Not a group member' }, 403)

  let query = supabase
    .from('messages')
    .select(`*, sender:users!sender_id(${PUBLIC_USER_FIELDS})`)
    .eq('group_id', groupId)
    .eq('is_deleted', false)
    .order('created_at', { ascending: false })
    .limit(limitNum)

  if (before) query = query.lt('id', before)

  const { data, error } = await query
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ messages: (data ?? []).reverse() })
})

export default app
