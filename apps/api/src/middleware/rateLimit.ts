import { createMiddleware } from 'hono/factory'
import { HTTPException } from 'hono/http-exception'

const buckets = new Map<string, { count: number; reset: number }>()

// Simple in-process token bucket: 100 requests / 60s per IP
// Replace with Redis + @hono/rate-limiter for multi-instance deploys
export const rateLimit = (limit = 100, windowMs = 60_000) =>
  createMiddleware(async (c, next) => {
    const ip = c.req.header('x-forwarded-for') ?? c.req.header('x-real-ip') ?? 'unknown'
    const now = Date.now()
    const bucket = buckets.get(ip) ?? { count: 0, reset: now + windowMs }

    if (now > bucket.reset) {
      bucket.count = 0
      bucket.reset = now + windowMs
    }

    bucket.count++
    buckets.set(ip, bucket)

    if (bucket.count > limit) {
      throw new HTTPException(429, { message: 'Too many requests' })
    }

    await next()
  })
