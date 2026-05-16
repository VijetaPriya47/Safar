'use client'

import Link from 'next/link'
import { useQuery } from '@tanstack/react-query'
import { CheckCircle, XCircle, Users, Train, Plane, Pencil } from 'lucide-react'
import { Avatar } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { useAuthStore } from '@/stores/authStore'
import { api } from '@/lib/api'

export default function ProfilePage() {
  const user = useAuthStore((s) => s.user)
  const isLoading = useAuthStore((s) => s.isLoading)

  const { data } = useQuery({
    queryKey: ['users', 'me'],
    queryFn: () =>
      api.get<{
        user: any
        verified: { college: boolean; pnr: boolean }
        groups_count: number
        groups: any[]
      }>('/users/me'),
    enabled: !!user,
  })

  if (isLoading) {
    return (
      <div className="px-4 py-6 space-y-4 max-w-lg mx-auto">
        <div className="h-24 rounded-2xl bg-gray-100 animate-pulse" />
        <div className="h-20 rounded-2xl bg-gray-100 animate-pulse" />
        <div className="h-32 rounded-2xl bg-gray-100 animate-pulse" />
      </div>
    )
  }

  const profile = data?.user ?? user
  const verified = data?.verified
  const groups = data?.groups ?? []

  return (
    <div className="max-w-lg mx-auto px-4 py-6 space-y-5">
      {/* Profile header */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
        <div className="flex items-center gap-4">
          <Avatar name={profile?.name ?? '?'} avatarUrl={profile?.avatar_url} size="lg" />
          <div className="flex-1 min-w-0">
            <p className="text-lg font-bold text-gray-900 truncate">{profile?.name ?? '—'}</p>
            {profile?.college_name && (
              <p className="text-sm text-gray-500 truncate">{profile.college_name}</p>
            )}
          </div>
          <Link
            href="/profile/edit"
            className="shrink-0 flex items-center gap-1.5 rounded-lg border border-gray-200 px-3 py-1.5 text-sm text-gray-600 hover:border-brand-300 hover:text-brand-600 transition-colors"
          >
            <Pencil size={13} />
            Edit
          </Link>
        </div>

        {profile?.bio && (
          <p className="mt-3 text-sm text-gray-600 leading-relaxed">{profile.bio}</p>
        )}
      </div>

      {/* Verification */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
        <h2 className="text-sm font-semibold text-gray-700 mb-3">Verification</h2>
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2">
            {verified?.college ? (
              <CheckCircle size={16} className="text-green-500 shrink-0" />
            ) : (
              <XCircle size={16} className="text-gray-300 shrink-0" />
            )}
            <span className={`text-sm ${verified?.college ? 'text-green-700 font-medium' : 'text-gray-400'}`}>
              College verified
            </span>
          </div>
          <div className="flex items-center gap-2">
            {verified?.pnr ? (
              <CheckCircle size={16} className="text-green-500 shrink-0" />
            ) : (
              <XCircle size={16} className="text-gray-300 shrink-0" />
            )}
            <span className={`text-sm ${verified?.pnr ? 'text-green-700 font-medium' : 'text-gray-400'}`}>
              PNR verified
            </span>
          </div>
        </div>
        {(!verified?.college || !verified?.pnr) && (
          <Link href="/verify" className="mt-3 inline-block text-xs text-brand-600 font-medium hover:underline">
            Get verified →
          </Link>
        )}
      </div>

      {/* Groups joined */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-sm font-semibold text-gray-700">
            Groups joined
            <span className="ml-2 text-xs font-normal text-gray-400">({data?.groups_count ?? 0})</span>
          </h2>
          <Link href="/rooms" className="text-xs text-brand-600 font-medium hover:underline">
            Browse rooms
          </Link>
        </div>

        {groups.length === 0 ? (
          <div className="text-center py-6">
            <Users size={28} className="text-gray-200 mx-auto mb-2" />
            <p className="text-sm text-gray-400">No groups yet</p>
            <Link href="/rooms" className="mt-2 inline-block text-xs text-brand-600 font-medium hover:underline">
              Find a room to join
            </Link>
          </div>
        ) : (
          <div className="space-y-3">
            {groups.map((m: any) => {
              const group = m.group
              const room = group?.room
              return (
                <Link
                  key={group?.id}
                  href={`/groups/${group?.id}`}
                  className="flex items-start gap-3 rounded-xl border border-gray-100 p-3 hover:border-brand-200 transition-colors"
                >
                  <div className="shrink-0 h-8 w-8 rounded-lg bg-brand-50 flex items-center justify-center">
                    {room?.room_type === 'flight'
                      ? <Plane size={15} className="text-brand-600" />
                      : <Train size={15} className="text-brand-600" />}
                  </div>
                  <div className="min-w-0">
                    <p className="text-sm font-medium text-gray-900 truncate">{group?.name}</p>
                    {room && (
                      <p className="text-xs text-gray-400 truncate">
                        {room.source} → {room.destination} · {room.journey_date}
                      </p>
                    )}
                  </div>
                </Link>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
