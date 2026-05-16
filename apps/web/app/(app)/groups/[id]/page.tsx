'use client'

import { useState } from 'react'
import { useParams } from 'next/navigation'
import { Users, MessageCircle, Lock, CheckCircle, XCircle } from 'lucide-react'
import { ChatWindow } from '@/components/chat/ChatWindow'
import { MemberList } from '@/components/rooms/MemberList'
import { JoinRequestBadge } from '@/components/groups/JoinRequestBadge'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Avatar } from '@/components/ui/avatar'
import { useGroup, useApproveMember } from '@/lib/hooks/useGroup'
import { useAuthStore } from '@/stores/authStore'
import type { PublicUser } from '@safarknots/types'

type Tab = 'chat' | 'members'

export default function GroupPage() {
  const { id } = useParams<{ id: string }>()
  const [tab, setTab] = useState<Tab>('chat')
  const { data, isLoading } = useGroup(id)
  const user = useAuthStore((s) => s.user)
  const { mutate: approveMember } = useApproveMember(id)

  if (isLoading) return <div className="flex items-center justify-center h-screen text-sm text-gray-400">Loading…</div>
  if (!data) return <div className="flex items-center justify-center h-screen text-sm text-red-500">Group not found</div>

  const { group, members, isMember, isCreator } = data
  const approvedMembers: PublicUser[] = members
    .filter((m: any) => m.status === 'approved')
    .map((m: any) => m.user)
  const pendingMembers = members.filter((m: any) => m.status === 'pending')
  const isFull = group.member_count >= group.max_members

  return (
    <div className="flex flex-col h-screen">
      {/* Header */}
      <div className="border-b border-gray-100 bg-white px-4 py-4">
        <div className="flex items-start gap-2 mb-1">
          {group.visibility === 'private' && <Lock size={14} className="text-gray-400 mt-1 shrink-0" />}
          <h1 className="text-base font-bold text-gray-900">{group.name}</h1>
        </div>
        {group.description && <p className="text-xs text-gray-500 mb-2">{group.description}</p>}
        <div className="flex items-center gap-2">
          <span className="text-xs text-gray-400">{group.member_count}/{group.max_members} members</span>
          {group.requires_approval && <Badge label="Approval required" variant="yellow" />}
        </div>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-gray-100 bg-white">
        {[
          { key: 'chat' as Tab, label: 'Chat', icon: MessageCircle },
          { key: 'members' as Tab, label: `Members (${group.member_count})`, icon: Users },
        ].map(({ key, label }) => (
          <button
            key={key}
            onClick={() => setTab(key)}
            className={`flex-1 py-2.5 text-sm font-medium transition-colors border-b-2 ${
              tab === key ? 'border-brand-600 text-brand-600' : 'border-transparent text-gray-500'
            }`}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Join bar */}
      {!isMember && !isCreator && (
        <div className="border-b border-orange-100 bg-orange-50 px-4 py-3 flex items-center justify-between">
          <p className="text-sm text-orange-700">
            {group.requires_approval ? 'Request to join this group' : 'Join this group to chat'}
          </p>
          <JoinRequestBadge groupId={id} isFull={isFull} />
        </div>
      )}

      {/* Pending approvals (creator only) */}
      {isCreator && pendingMembers.length > 0 && (
        <div className="border-b border-yellow-100 bg-yellow-50 px-4 py-3">
          <p className="text-xs font-semibold text-yellow-800 mb-2">Pending approvals ({pendingMembers.length})</p>
          <div className="space-y-2">
            {pendingMembers.map((m: any) => (
              <div key={m.user_id} className="flex items-center gap-2">
                <Avatar name={m.user?.name ?? '?'} avatarUrl={m.user?.avatar_url} size="sm" />
                <span className="flex-1 text-sm text-gray-700">{m.user?.name}</span>
                <button
                  onClick={() => approveMember({ userId: m.user_id, action: 'approve' })}
                  className="text-green-600 hover:text-green-700"
                >
                  <CheckCircle size={18} />
                </button>
                <button
                  onClick={() => approveMember({ userId: m.user_id, action: 'reject' })}
                  className="text-red-500 hover:text-red-600"
                >
                  <XCircle size={18} />
                </button>
              </div>
            ))}
          </div>
        </div>
      )}

      {tab === 'chat' && (
        isMember || isCreator
          ? <ChatWindow groupId={id} />
          : <div className="flex-1 flex items-center justify-center text-sm text-gray-400">
              {user ? 'Join the group to chat.' : 'Sign in and join the group to chat.'}
            </div>
      )}

      {tab === 'members' && (
        <div className="flex-1 overflow-y-auto">
          <MemberList members={approvedMembers} />
        </div>
      )}
    </div>
  )
}
