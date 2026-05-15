import Link from 'next/link'
import { Train, Plane, Route, Users, ArrowRight } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import { formatDate } from '@/lib/utils'
import type { Room } from '@safarmate/types'

const RoomIcon = ({ type }: { type: Room['room_type'] }) => {
  if (type === 'train') return <Train size={16} className="text-blue-600" />
  if (type === 'flight') return <Plane size={16} className="text-purple-600" />
  return <Route size={16} className="text-green-600" />
}

const typeVariant: Record<Room['room_type'], 'blue' | 'yellow' | 'green'> = {
  train: 'blue',
  flight: 'yellow',
  route: 'green',
}

export function RoomCard({ room }: { room: Room }) {
  return (
    <Link
      href={`/rooms/${room.id}`}
      className="flex flex-col gap-3 rounded-xl border border-gray-100 bg-white p-4 shadow-sm transition-shadow hover:shadow-md active:scale-[0.99]"
    >
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-2">
          <RoomIcon type={room.room_type} />
          <span className="text-xs text-gray-500">{room.identifier ?? room.room_type}</span>
        </div>
        <Badge label={room.room_type} variant={typeVariant[room.room_type]} />
      </div>

      <div className="flex items-center gap-2 text-sm font-medium text-gray-900">
        <span className="truncate">{room.source}</span>
        <ArrowRight size={14} className="shrink-0 text-gray-400" />
        <span className="truncate">{room.destination}</span>
      </div>

      <div className="flex items-center justify-between">
        <span className="text-xs text-gray-500">{formatDate(room.journey_date)}</span>
        <div className="flex items-center gap-1 text-xs text-gray-500">
          <Users size={12} />
          <span>{room.member_count} travelers</span>
        </div>
      </div>
    </Link>
  )
}
