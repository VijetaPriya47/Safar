'use client'

import { useState } from 'react'
import { Search } from 'lucide-react'
import { RoomCard } from '@/components/rooms/RoomCard'
import { Input } from '@/components/ui/input'
import { useRooms } from '@/lib/hooks/useRoom'

const TYPES = ['', 'train', 'flight', 'route'] as const

export default function RoomsPage() {
  const [type, setType] = useState('')
  const [destination, setDestination] = useState('')
  const [date, setDate] = useState('')

  const { data, isLoading } = useRooms({
    type: type || undefined,
    destination: destination || undefined,
    date: date || undefined,
  })

  const rooms = data?.rooms ?? []

  return (
    <div className="flex flex-col">
      <div className="bg-white border-b border-gray-100 px-4 py-4 space-y-3">
        <h1 className="text-lg font-bold text-gray-900">Browse rooms</h1>

        {/* Type filter */}
        <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none">
          {TYPES.map((t) => (
            <button
              key={t}
              onClick={() => setType(t)}
              className={`shrink-0 rounded-full px-4 py-1.5 text-sm font-medium transition-colors ${
                type === t
                  ? 'bg-brand-600 text-white'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              {t === '' ? 'All' : t.charAt(0).toUpperCase() + t.slice(1)}
            </button>
          ))}
        </div>

        {/* Search filters */}
        <div className="flex gap-2">
          <div className="relative flex-1">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              value={destination}
              onChange={(e) => setDestination(e.target.value)}
              placeholder="Destination..."
              className="w-full rounded-lg border border-gray-200 pl-8 pr-3 py-2 text-sm focus:border-brand-600 focus:outline-none focus:ring-1 focus:ring-brand-600"
            />
          </div>
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-brand-600 focus:outline-none"
          />
        </div>
      </div>

      <div className="px-4 py-4">
        {isLoading ? (
          <div className="grid gap-3">
            {[1, 2, 3].map((i) => (
              <div key={i} className="h-28 rounded-xl bg-gray-100 animate-pulse" />
            ))}
          </div>
        ) : rooms.length === 0 ? (
          <div className="py-16 text-center">
            <p className="text-gray-400 text-sm">No rooms found. Try adjusting filters.</p>
          </div>
        ) : (
          <div className="grid gap-3">
            {rooms.map((room) => (
              <RoomCard key={room.id} room={room} />
            ))}
          </div>
        )}

        {data?.total != null && data.total > rooms.length && (
          <p className="text-center text-xs text-gray-400 mt-4">
            Showing {rooms.length} of {data.total} rooms
          </p>
        )}
      </div>
    </div>
  )
}
