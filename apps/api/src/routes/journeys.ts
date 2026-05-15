import { Hono } from 'hono'
import { z } from 'zod'
import { requireAuth } from '../middleware/auth'
import { supabase } from '../lib/supabase'
import { upsertRoom } from '../services/roomService'

const app = new Hono()

const createJourneySchema = z.object({
  journey_type: z.enum(['train', 'flight', 'route']),
  train_number: z.string().min(1).optional(),
  flight_number: z.string().min(1).optional(),
  source: z.string().min(1).max(200),
  destination: z.string().min(1).max(200),
  journey_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD format'),
  pnr_number: z.string().optional(),
}).refine(
  (d) => {
    if (d.journey_type === 'train' && !d.train_number) return false
    if (d.journey_type === 'flight' && !d.flight_number) return false
    return true
  },
  { message: 'train_number required for train; flight_number required for flight' }
)

app.post('/', requireAuth, async (c) => {
  const userId = c.get('user').id
  let body: unknown
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'Invalid JSON' }, 400)
  }

  const parsed = createJourneySchema.safeParse(body)
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400)

  const { journey_type, train_number, flight_number, source, destination, journey_date, pnr_number } =
    parsed.data

  // 1. Upsert room
  const room = await upsertRoom({ journey_type, train_number, flight_number, source, destination, journey_date })

  // 2. Create journey
  const { data: journey, error: journeyError } = await supabase
    .from('journeys')
    .insert({
      user_id: userId,
      journey_type,
      train_number: train_number ?? null,
      flight_number: flight_number ?? null,
      source,
      destination,
      journey_date,
      pnr_number: pnr_number ?? null,
    })
    .select()
    .single()

  if (journeyError) return c.json({ error: journeyError.message }, 500)

  // 3. Add to room_members (ignore duplicate)
  await supabase
    .from('room_members')
    .upsert(
      { room_id: room.id, user_id: userId, journey_id: journey.id },
      { onConflict: 'room_id,user_id', ignoreDuplicates: true }
    )

  // 4. Update member count
  await supabase.rpc('increment_room_member_count', { room_id: room.id })

  return c.json({ journey, room }, 201)
})

app.get('/:id', requireAuth, async (c) => {
  const { id } = c.req.param()
  const userId = c.get('user').id

  const { data, error } = await supabase
    .from('journeys')
    .select('*')
    .eq('id', id)
    .eq('user_id', userId)
    .single()

  if (error || !data) return c.json({ error: 'Journey not found' }, 404)
  return c.json({ journey: data })
})

app.delete('/:id', requireAuth, async (c) => {
  const { id } = c.req.param()
  const userId = c.get('user').id

  const { error } = await supabase
    .from('journeys')
    .update({ is_active: false })
    .eq('id', id)
    .eq('user_id', userId)

  if (error) return c.json({ error: error.message }, 500)
  return c.json({ success: true })
})

export default app
