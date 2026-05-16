'use client'

import { useState } from 'react'
import { useParams } from 'next/navigation'
import { Users, MessageCircle, Plus } from 'lucide-react'
import { RoomHeader } from '@/components/rooms/RoomHeader'
import { MemberList } from '@/components/rooms/MemberList'
import { GroupCard } from '@/components/groups/GroupCard'
import { ChatWindow } from '@/components/chat/ChatWindow'
import { CreateGroupModal } from '@/components/groups/CreateGroupModal'
import { Button } from '@/components/ui/button'
import { useRouter } from 'next/navigation'
import { useRoom, useJoinRoom } from '@/lib/hooks/useRoom'
import { useAuthStore } from '@/stores/authStore'

type Tab = 'chat' | 'members' | 'groups'

export default function RoomPage() {
  const { id } = useParams<{ id: string }>()
  const [tab, setTab] = useState<Tab>('chat')
  const [showCreateGroup, setShowCreateGroup] = useState(false)

  const router = useRouter()
  const { data: room, isLoading } = useRoom(id)
  const { mutate: joinRoom, isPending: isJoining } = useJoinRoom()
  const user = useAuthStore((s) => s.user)

  if (isLoading) return <div className="flex items-center justify-center h-screen text-sm text-gray-400">Loading…</div>
  if (!room) return <div className="flex items-center justify-center h-screen text-sm text-red-500">Room not found</div>

  const isMember = room.members.some((m) => m.id === user?.id)

  const tabs: { key: Tab; label: string; icon: typeof MessageCircle }[] = [
    { key: 'chat', label: 'Chat', icon: MessageCircle },
    { key: 'members', label: `Members (${room.member_count})`, icon: Users },
    { key: 'groups', label: `Groups (${room.groups?.length ?? 0})`, icon: Users },
  ]

  return (
    <div className="flex flex-col h-screen">
      <RoomHeader room={room} />

      {/* Tab bar */}
      <div className="flex border-b border-gray-100 bg-white">
        {tabs.map(({ key, label }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`flex-1 py-2.5 text-sm font-medium transition-colors border-b-2 ${
              tab === key
                ? 'border-brand-600 text-brand-600'
                : 'border-transparent text-gray-500 hover:text-gray-700'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Join bar (non-members) */}
      {!isMember && (
        <div className="border-b border-orange-100 bg-orange-50 px-4 py-3 flex items-center justify-between">
          <p className="text-sm text-orange-700">{user ? 'Join this room to chat' : 'Sign in to join and chat'}</p>
          <Button
            size="sm"
            isLoading={isJoining}
            onClick={() => user ? joinRoom(id) : router.push('/login')}
          >
            {user ? 'Join room' : 'Sign in'}
          </Button>
        </div>
      )}

      {/* Tab content */}
      {tab === 'chat' && (
        isMember
          ? <ChatWindow roomId={id} />
          : <div className="flex-1 flex items-center justify-center text-sm text-gray-400">
              {user ? 'Join the room to chat.' : 'Sign in and join the room to chat.'}
            </div>
      )}

      {tab === 'members' && (
        <div className="flex-1 overflow-y-auto">
          <MemberList members={room.members} />
        </div>
      )}

      {tab === 'groups' && (
        <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3">
          {isMember && (
            <Button
              variant="secondary"
              size="sm"
              className="w-full"
              onClick={() => setShowCreateGroup(true)}
            >
              <Plus size={14} /> Create a group
            </Button>
          )}
          {(room.groups ?? []).length === 0 ? (
            <p className="text-center text-sm text-gray-400 py-8">No groups yet.</p>
          ) : (
            (room.groups ?? []).map((g) => <GroupCard key={g.id} group={g} />)
          )}
        </div>
      )}

      <CreateGroupModal
        roomId={id}
        isOpen={showCreateGroup}
        onClose={() => setShowCreateGroup(false)}
      />
    </div>
  )
}
