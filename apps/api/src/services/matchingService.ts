import type { Room } from '@safarknots/types'
import { supabase } from '../lib/supabase'

// Find rooms that share the same destination on a given date
// This is the MVP approach to overlapping-route discovery
export async function findOverlappingRooms(
  destination: string,
  journeyDate: string,
  excludeRoomId?: string
): Promise<Room[]> {
  let query = supabase
    .from('rooms')
    .select('*')
    .ilike('destination', destination)
    .eq('journey_date', journeyDate)
    .order('member_count', { ascending: false })
    .limit(20)

  if (excludeRoomId) {
    query = query.neq('id', excludeRoomId)
  }

  const { data, error } = await query
  if (error) throw new Error(error.message)
  return (data ?? []) as Room[]
}
