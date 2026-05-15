import { Train, Plane, Route, ArrowRight, Users } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { formatDate } from '@/lib/utils'
import type { Room } from '@safarknots/types'

const RoomIcon = ({ type }: { type: Room['room_type'] }) => {
  if (type === 'train') return <Train size={20} className="text-blue-600" />
  if (type === 'flight') return <Plane size={20} className="text-purple-600" />
  return <Route size={20} className="text-green-600" />
}

const typeVariant: Record<Room['room_type'], 'blue' | 'yellow' | 'green'> = {
  train: 'blue',
  flight: 'yellow',
  route: 'green',
}

export function RoomHeader({ room }: { room: Room }) {
  return (
    <div className="border-b border-gray-100 bg-white px-4 py-4">
      <div className="flex items-center gap-2 mb-2">
        <RoomIcon type={room.room_type} />
        <Badge label={room.room_type} variant={typeVariant[room.room_type]} />
        {room.identifier && (
          <span className="text-sm text-gray-500">{room.identifier}</span>
        )}
      </div>

      <div className="flex items-center gap-2 text-base font-semibold text-gray-900">
        <span>{room.source}</span>
        <ArrowRight size={16} className="text-gray-400" />
        <span>{room.destination}</span>
      </div>

      <div className="mt-1 flex items-center gap-3">
        <span className="text-xs text-gray-500">{formatDate(room.journey_date)}</span>
        <div className="flex items-center gap-1 text-xs text-gray-500">
          <Users size={12} />
          <span>{room.member_count} travelers</span>
        </div>
      </div>
    </div>
  )
}
