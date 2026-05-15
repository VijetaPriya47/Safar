import { Hono } from 'hono'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { supabase } from '../lib/supabase'

const app = new Hono()

const syncProfileSchema = z.object({
  name: z.string().min(1),
  email: z.string().email(),
  avatar_url: z.string().url().optional(),
  google_id: z.string().min(1),
})

// Called immediately after Google OAuth completes on the frontend
app.post('/sync-profile', requireAuth, async (c) => {
  const user = c.get('user')
  let body: unknown
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON' }, 400)
  }

  const parsed = syncProfileSchema.safeParse(body)
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400)

  const { name, email, avatar_url, google_id } = parsed.data

  const { data, error } = await supabase
    .from('users')
    .upsert(
      { id: user.id, email, name, avatar_url: avatar_url ?? null, google_id },
      { onConflict: 'id' }
    )
    .select()
    .single()

  if (error) return c.json({ error: error.message }, 500)
  return c.json({ user: data })
})

app.get('/me', requireAuth, async (c) => {
  const user = c.get('user')
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .eq('id', user.id)
    .single()

  if (error || !data) return c.json({ error: 'User not found' }, 404)
  return c.json({ user: data })
})

export default app
