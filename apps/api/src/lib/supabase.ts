import { createClient } from '@supabase/supabase-js'
import ws from 'ws'
import { config } from './config'

// Service-role client — full DB access, never expose to frontend
// ws is required for Node 20 (no native WebSocket); Node 22+ doesn't need this
export const supabase = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
  auth: { persistSession: false },
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  realtime: { transport: ws as any },
})
