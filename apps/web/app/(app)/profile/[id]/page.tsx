'use client'

import { useParams } from 'next/navigation'
import { Flag, Ban } from 'lucide-react'
import { Avatar } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { useUser, useBlockUser } from '@/lib/hooks/useUser'
import { useMutation } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { useAuthStore } from '@/stores/authStore'
import { useState } from 'react'

export default function ProfilePage() {
  const { id } = useParams<{ id: string }>()
  const { data: profile, isLoading, isError } = useUser(id)
  const currentUser = useAuthStore((s) => s.user)
  const { mutate: blockUser } = useBlockUser()
  const [reported, setReported] = useState(false)

  const { mutate: report } = useMutation({
    mutationFn: () =>
      api.post('/reports', {
        reported_user_id: id,
        reason: 'inappropriate_behavior',
        description: 'Reported from profile page',
      }),
    onSuccess: () => setReported(true),
  })

  if (isLoading) return <div className="flex items-center justify-center h-screen text-sm text-gray-400">Loading…</div>
  if (isError) return <div className="flex items-center justify-center h-screen text-sm text-red-500">Failed to load profile. Check your connection and try again.</div>
  if (!profile) return <div className="flex items-center justify-center h-screen text-sm text-red-500">User not found</div>

  const isOwnProfile = currentUser?.id === id

  return (
    <div className="max-w-md mx-auto px-4 py-6">
      <div className="flex flex-col items-center text-center mb-6">
        <Avatar name={profile.name} avatarUrl={profile.avatar_url} size="lg" className="mb-3" />
        <h1 className="text-xl font-bold text-gray-900">{profile.name}</h1>
        {profile.college_name && (
          <p className="text-sm text-gray-500 mt-1">{profile.college_name}</p>
        )}
        <div className="flex gap-2 mt-3">
          {profile.pnr_verified && <Badge label="PNR Verified" variant="green" />}
          {profile.college_verified && <Badge label="Student Verified" variant="blue" />}
          {profile.gender && <Badge label={profile.gender} variant="gray" />}
        </div>
      </div>

      {profile.bio && (
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4 mb-4">
          <p className="text-sm text-gray-700 leading-relaxed">{profile.bio}</p>
        </div>
      )}

      {!isOwnProfile && (
        <div className="flex gap-2">
          <Button
            variant="secondary"
            size="sm"
            className="flex-1 gap-2"
            onClick={() => blockUser(id)}
          >
            <Ban size={14} /> Block
          </Button>
          <Button
            variant="danger"
            size="sm"
            className="flex-1 gap-2"
            disabled={reported}
            onClick={() => report()}
          >
            <Flag size={14} /> {reported ? 'Reported' : 'Report'}
          </Button>
        </div>
      )}
    </div>
  )
}
