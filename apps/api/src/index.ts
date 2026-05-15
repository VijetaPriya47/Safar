import 'dotenv/config'
import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { cors } from 'hono/cors'
import { logger } from 'hono/logger'
import { HTTPException } from 'hono/http-exception'
import { config } from './lib/config'
import authRoutes from './routes/auth'
import userRoutes from './routes/users'
import journeyRoutes from './routes/journeys'
import roomRoutes from './routes/rooms'
import groupRoutes from './routes/groups'
import moderationRoutes from './routes/moderation'

const app = new Hono()

app.use('*', logger())
app.use(
  '*',
  cors({
    origin: (origin) => config.allowedOrigins.includes(origin) ? origin : config.allowedOrigins[0],
    allowHeaders: ['Authorization', 'Content-Type'],
    allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    credentials: true,
  })
)

app.get('/health', (c) => c.json({ status: 'ok' }))

app.route('/auth', authRoutes)
app.route('/users', userRoutes)
app.route('/journeys', journeyRoutes)
app.route('/rooms', roomRoutes)
app.route('/', groupRoutes)
app.route('/', moderationRoutes)

app.onError((err, c) => {
  if (err instanceof HTTPException) {
    return c.json({ error: err.message }, err.status)
  }
  console.error(err)
  return c.json({ error: 'Internal server error' }, 500)
})

serve({ fetch: app.fetch, port: config.port }, (info) => {
  console.log(`SafarKnots API running on http://localhost:${info.port}`)
})

export default app
