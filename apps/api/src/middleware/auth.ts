import type { Context, Next } from 'hono'
import { createMiddleware } from 'hono/factory'
import { HTTPException } from 'hono/http-exception'
import { supabase } from '../lib/supabase'

export type AuthUser = {
  id: string
  email: string
}

declare module 'hono' {
  interface ContextVariableMap {
    user: AuthUser
  }
}

export const optionalAuth = createMiddleware(async (c: Context, next: Next) => {
  const authHeader = c.req.header('Authorization')
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7)
    const { data } = await supabase.auth.getUser(token)
    if (data.user) {
      c.set('user', { id: data.user.id, email: data.user.email! })
    }
  }
  await next()
})

export const requireAuth = createMiddleware(async (c: Context, next: Next) => {
  const authHeader = c.req.header('Authorization')
  if (!authHeader?.startsWith('Bearer ')) {
    throw new HTTPException(401, { message: 'Missing authorization header' })
  }

  const token = authHeader.slice(7)
  const { data, error } = await supabase.auth.getUser(token)

  if (error || !data.user) {
    throw new HTTPException(401, { message: 'Invalid or expired token' })
  }

  c.set('user', { id: data.user.id, email: data.user.email! })
  await next()
})
