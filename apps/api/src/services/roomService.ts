import type { JourneyType, Room } from '@safarknots/types'
import { supabase } from '../lib/supabase'

function normalizeCity(city: string): string {
  return city.trim().toLowerCase().replace(/\s+/g, '-')
}

export function buildRoomKey(params: {
  journey_type: JourneyType
  train_number?: string | null
  flight_number?: string | null
  source: string
  destination: string
  journey_date: string
}): string {
  const date = params.journey_date
  switch (params.journey_type) {
    case 'train':
      return `train_${params.train_number}_${date}`
    case 'flight':
      return `flight_${params.flight_number}_${date}`
    case 'route':
      return `route_${normalizeCity(params.source)}_${normalizeCity(params.destination)}_${date}`
  }
}

export async function upsertRoom(params: {
  journey_type: JourneyType
  train_number?: string | null
  flight_number?: string | null
  source: string
  destination: string
  journey_date: string
}): Promise<Room> {
  const room_key = buildRoomKey(params)
  const identifier = params.train_number ?? params.flight_number ?? `${params.source}-${params.destination}`

  const { data, error } = await supabase
    .from('rooms')
    .upsert(
      {
        room_key,
        room_type: params.journey_type,
        identifier,
        source: params.source,
        destination: params.destination,
        journey_date: params.journey_date,
      },
      { onConflict: 'room_key', ignoreDuplicates: false }
    )
    .select()
    .single()

  if (error) throw new Error(`Failed to upsert room: ${error.message}`)
  return data as Room
}

export async function incrementMemberCount(roomId: string): Promise<void> {
  await supabase.rpc('increment_room_member_count', { room_id: roomId })
}

export async function decrementMemberCount(roomId: string): Promise<void> {
  await supabase.rpc('decrement_room_member_count', { room_id: roomId })
}
