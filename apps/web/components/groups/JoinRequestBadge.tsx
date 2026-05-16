'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { Button } from '@/components/ui/button'
import { useJoinGroup } from '@/lib/hooks/useGroup'
import { useAuthStore } from '@/stores/authStore'

interface JoinRequestBadgeProps {
  groupId: string
  isFull: boolean
  onJoined?: (status: string) => void
}

export function JoinRequestBadge({ groupId, isFull, onJoined }: JoinRequestBadgeProps) {
  const { mutate, isPending, isSuccess, data } = useJoinGroup()
  const [joined, setJoined] = useState(false)
  const user = useAuthStore((s) => s.user)
  const router = useRouter()

  const handleJoin = () => {
    if (!user) { router.push('/login'); return }
    mutate(groupId, {
      onSuccess: (res: any) => {
        setJoined(true)
        onJoined?.(res.status)
      },
    })
  }

  if (joined || isSuccess) {
    const status = (data as any)?.status
    return (
      <span className="text-sm text-green-600 font-medium">
        {status === 'pending' ? 'Request sent! Awaiting approval.' : 'Joined group!'}
      </span>
    )
  }

  return (
    <Button onClick={handleJoin} isLoading={isPending} disabled={isFull} size="sm">
      {isFull ? 'Group full' : 'Join group'}
    </Button>
  )
}
