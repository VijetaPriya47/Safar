'use client'

import Link from 'next/link'
import { useQuery } from '@tanstack/react-query'
import { PlusCircle, ArrowRight, Train } from 'lucide-react'
import { Avatar } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import { RoomCard } from '@/components/rooms/RoomCard'
import { useAuthStore } from '@/stores/authStore'
import { api } from '@/lib/api'
import type { Journey, Room } from '@safarknots/types'

export default function DashboardPage() {
  const user = useAuthStore((s) => s.user)

  const { data: journeysData } = useQuery({
    queryKey: ['my-journeys'],
    queryFn: () => api.get<{ journeys: (Journey & { room?: Room })[] }>('/users/me/journeys'),
    enabled: !!user,
  })

  const journeys = journeysData?.journeys ?? []

  return (
    <div className="flex flex-col gap-0">
      {/* Header */}
      <div className="bg-white border-b border-gray-100 px-4 py-4">
        <div className="flex items-center gap-3">
          {user && <Avatar name={user.name} avatarUrl={user.avatar_url} size="md" />}
          <div className="min-w-0">
            <p className="text-sm text-gray-500">Good to see you,</p>
            <p className="text-base font-semibold text-gray-900 truncate">{user?.name ?? '…'}</p>
          </div>
        </div>
      </div>

      <div className="px-4 py-4 space-y-6">
        {/* Add trip CTA */}
        <Link
          href="/journeys/new"
          className="flex items-center gap-3 rounded-xl bg-brand-600 p-4 text-white shadow-lg shadow-brand-600/30"
        >
          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-white/20">
            <PlusCircle size={20} />
          </div>
          <div className="flex-1">
            <p className="font-semibold">Add a new journey</p>
            <p className="text-sm text-blue-100">Find travelers on your route</p>
          </div>
          <ArrowRight size={18} className="text-blue-200" />
        </Link>

        {/* My journeys */}
        <section>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-base font-semibold text-gray-900">My journeys</h2>
            <Link href="/rooms" className="text-sm text-brand-600 font-medium">Browse all</Link>
          </div>

          {journeys.length === 0 ? (
            <div className="flex flex-col items-center gap-3 rounded-xl border border-dashed border-gray-200 py-8 text-center">
              <Train size={32} className="text-gray-300" />
              <p className="text-sm text-gray-500">No journeys yet</p>
              <Link href="/journeys/new" className="inline-flex items-center justify-center rounded-lg bg-brand-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-brand-700 transition-colors">
                Add your first journey
              </Link>
            </div>
          ) : (
            <div className="grid gap-3">
              {journeys.map((j) => (
                <div key={j.id} className="rounded-xl border border-gray-100 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm font-medium text-gray-900">
                        {j.source} → {j.destination}
                      </p>
                      <p className="text-xs text-gray-500 mt-0.5">
                        {j.journey_type} · {j.journey_date}
                      </p>
                    </div>
                    {j.train_number && (
                      <span className="text-xs font-medium text-blue-600 bg-blue-50 px-2 py-0.5 rounded-full">
                        {j.train_number}
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>

        {/* Browse rooms */}
        <section>
          <div className="flex items-center justify-between mb-3">
            <h2 className="text-base font-semibold text-gray-900">Explore rooms</h2>
          </div>
          <Link href="/rooms" className="block">
            <div className="rounded-xl border border-gray-100 bg-white p-4 shadow-sm hover:shadow-md transition-shadow">
              <p className="text-sm text-gray-700 font-medium">Browse all travel rooms →</p>
              <p className="text-xs text-gray-400 mt-1">Filter by train, flight, route, date</p>
            </div>
          </Link>
        </section>
      </div>
    </div>
  )
}
