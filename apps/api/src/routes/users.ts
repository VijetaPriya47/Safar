import { Hono } from 'hono'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { supabase } from '../lib/supabase'

const app = new Hono()

const PUBLIC_USER_FIELDS =
  'id,name,avatar_url,bio,gender,college_name,college_verified,pnr_verified,created_at'

const updateProfileSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  bio: z.string().max(300).optional(),
  gender: z.enum(['male', 'female', 'other', 'prefer_not_to_say']).optional(),
  college_name: z.string().max(200).optional(),
})

app.get('/me/journeys', requireAuth, async (c) => {
  const user = c.get('user')
  const { data, error } = await supabase
    .from('journeys')
    .select('*')
    .eq('user_id', user.id)
    .eq('is_active', true)
    .order('journey_date', { ascending: false })

  if (error) return c.json({ error: error.message }, 500)
  return c.json({ journeys: data })
})

app.get('/:id', requireAuth, async (c) => {
  const { id } = c.req.param()
  const requesterId = c.get('user').id

  const { data: profile, error } = await supabase
    .from('users')
    .select(PUBLIC_USER_FIELDS)
    .eq('id', id)
    .single()

  if (error || !profile) return c.json({ error: 'User not found' }, 404)

  // Check if requester is blocked by or has blocked this user
  const { data: block } = await supabase
    .from('blocks')
    .select('id')
    .or(`blocker_id.eq.${requesterId},blocked_id.eq.${requesterId}`)
    .or(`blocker_id.eq.${id},blocked_id.eq.${id}`)
    .maybeSingle()

  if (block) return c.json({ error: 'User not found' }, 404)

  return c.json({ user: profile })
})

app.put('/me', requireAuth, async (c) => {
  const user = c.get('user')
  let body: unknown
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON' }, 400)
  }

  const parsed = updateProfileSchema.safeParse(body)
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400)

  const { data, error } = await supabase
    .from('users')
    .update(parsed.data)
    .eq('id', user.id)
    .select()
    .single()

  if (error) return c.json({ error: error.message }, 500)
  return c.json({ user: data })
})

app.post('/:id/block', requireAuth, async (c) => {
  const { id: blockedId } = c.req.param()
  const blockerId = c.get('user').id

  if (blockerId === blockedId) return c.json({ error: 'Cannot block yourself' }, 400)

  const { error } = await supabase
    .from('blocks')
    .upsert({ blocker_id: blockerId, blocked_id: blockedId }, { onConflict: 'blocker_id,blocked_id', ignoreDuplicates: true })

  if (error) return c.json({ error: error.message }, 500)
  return c.json({ success: true })
})

app.delete('/:id/block', requireAuth, async (c) => {
  const { id: blockedId } = c.req.param()
  const blockerId = c.get('user').id

  const { error } = await supabase
    .from('blocks')
    .delete()
    .eq('blocker_id', blockerId)
    .eq('blocked_id', blockedId)

  if (error) return c.json({ error: error.message }, 500)
  return c.json({ success: true })
})

export default app
