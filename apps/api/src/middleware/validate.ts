import type { Context, Next } from 'hono'
import { HTTPException } from 'hono/http-exception'
import type { ZodSchema } from 'zod'

export const validateBody =
  <T>(schema: ZodSchema<T>) =>
  async (c: Context, next: Next) => {
    let body: unknown
    try {
      body = await c.req.json()
    } catch {
      throw new HTTPException(400, { message: 'Invalid JSON body' })
    }

    const result = schema.safeParse(body)
    if (!result.success) {
      throw new HTTPException(400, {
        message: result.error.issues.map((i) => i.message).join(', '),
      })
    }

    c.set('validatedBody' as never, result.data)
    await next()
  }
