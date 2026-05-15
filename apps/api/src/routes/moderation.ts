import { Hono } from 'hono'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { rateLimit } from '../middleware/rateLimit'
import { supabase } from '../lib/supabase'

const app = new Hono()

const createReportSchema = z.object({
  reported_user_id: z.string().uuid(),
  reason: z.string().min(1).max(200),
  description: z.string().max(1000).optional(),
  room_id: z.string().uuid().optional(),
  group_id: z.string().uuid().optional(),
})

app.post('/reports', requireAuth, rateLimit(10, 60_000), async (c) => {
  const reporterId = c.get('user').id
  let body: unknown
  try { body = await c.req.json() } catch { return c.json({ error: 'Invalid JSON' }, 400) }

  const parsed = createReportSchema.safeParse(body)
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400)

  if (reporterId === parsed.data.reported_user_id) {
    return c.json({ error: 'Cannot report yourself' }, 400)
  }

  const { data, error } = await supabase
    .from('reports')
    .insert({ reporter_id: reporterId, ...parsed.data })
    .select()
    .single()

  if (error) return c.json({ error: error.message }, 500)
  return c.json({ report: data }, 201)
})

export default app
