import { Hono } from 'hono'
import { requireAuth } from '../middleware/auth'
import { supabase } from '../lib/supabase'
import { isRoomMember } from '../services/groupService'

const app = new Hono()

const PUBLIC_USER_FIELDS = 'id,name,avatar_url,bio,gender,college_name,college_verified,pnr_verified,created_at'

app.get('/', requireAuth, async (c) => {
  const { type, date, source, destination, page = '1', limit = '20' } = c.req.query()
  const pageNum = Math.max(1, parseInt(page, 10))
  const limitNum = Math.min(50, parseInt(limit, 10))
  const offset = (pageNum - 1) * limitNum

  let query = supabase.from('rooms').select('*', { count: 'exact' })

  if (type) query = query.eq('room_type', type)
  if (date) query = query.eq('journey_date', date)
  if (source) query = query.ilike('source', `%${source}%`)
  if (destination) query = query.ilike('destination', `%${destination}%`)

  const { data, error, count } = await query
    .order('member_count', { ascending: false })
    .range(offset, offset + limitNum - 1)

  if (error) return c.json({ error: error.message }, 500)
  return c.json({ rooms: data, total: count ?? 0, page: pageNum, limit: limitNum })
})

app.get('/:id', requireAuth, async (c) => {
  const { id } = c.req.param()

  const [{ data: room, error: roomErr }, { data: membersData, error: membersErr }, { data: groups, error: groupsErr }] =
    await Promise.all([
      supabase.from('rooms').select('*').eq('id', id).single(),
      supabase
        .from('room_members')
        .select(`user:users!inner(${PUBLIC_USER_FIELDS})`)
        .eq('room_id', id)
        .limit(50),
      supabase.from('groups').select('*').eq('room_id', id).eq('visibility', 'public').order('member_count', { ascending: false }),
    ])

  if (roomErr || !room) return c.json({ error: 'Room not found' }, 404)

  const members = (membersData ?? []).map((m: any) => m.user)
  return c.json({ room, members, groups: groups ?? [] })
})

app.post('/:id/join', requireAuth, async (c) => {
  const { id: roomId } = c.req.param()
  const userId = c.get('user').id

  // Verify room exists
  const { data: room } = await supabase.from('rooms').select('id').eq('id', roomId).single()
  if (!room) return c.json({ error: 'Room not found' }, 404)

  // Upsert membership
  const { error } = await supabase
    .from('room_members')
    .upsert({ room_id: roomId, user_id: userId, journey_id: null }, { onConflict: 'room_id,user_id', ignoreDuplicates: true })

  if (error) return c.json({ error: error.message }, 500)

  await supabase.rpc('increment_room_member_count', { room_id: roomId })
  return c.json({ success: true })
})

app.delete('/:id/leave', requireAuth, async (c) => {
  const { id: roomId } = c.req.param()
  const userId = c.get('user').id

  const { error } = await supabase
    .from('room_members')
    .delete()
    .eq('room_id', roomId)
    .eq('user_id', userId)

  if (error) return c.json({ error: error.message }, 500)

  await supabase.rpc('decrement_room_member_count', { room_id: roomId })
  return c.json({ success: true })
})

app.get('/:id/messages', requireAuth, async (c) => {
  const { id: roomId } = c.req.param()
  const userId = c.get('user').id
  const { before, limit = '50' } = c.req.query()
  const limitNum = Math.min(100, parseInt(limit, 10))

  const isMember = await isRoomMember(roomId, userId)
  if (!isMember) return c.json({ error: 'Not a room member' }, 403)

  let query = supabase
    .from('messages')
    .select(`*, sender:users!sender_id(${PUBLIC_USER_FIELDS})`)
    .eq('room_id', roomId)
    .eq('is_deleted', false)
    .order('created_at', { ascending: false })
    .limit(limitNum)

  if (before) query = query.lt('id', before)

  const { data, error } = await query
  if (error) return c.json({ error: error.message }, 500)
  return c.json({ messages: (data ?? []).reverse() })
})

export default app
