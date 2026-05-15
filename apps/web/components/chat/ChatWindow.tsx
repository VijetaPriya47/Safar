'use client'

import { useEffect, useRef } from 'react'
import { MessageBubble } from './MessageBubble'
import { MessageInput } from './MessageInput'
import { useRealtimeChat } from '@/lib/hooks/useRealtimeChat'
import { useAuthStore } from '@/stores/authStore'

interface ChatWindowProps {
  roomId?: string
  groupId?: string
}

export function ChatWindow({ roomId, groupId }: ChatWindowProps) {
  const { messages, isLoading, sendMessage, loadMore } = useRealtimeChat({ roomId, groupId })
  const user = useAuthStore((s) => s.user)
  const bottomRef = useRef<HTMLDivElement>(null)
  const topRef = useRef<HTMLDivElement>(null)

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [messages.length])

  const handleScroll = async (e: React.UIEvent<HTMLDivElement>) => {
    const el = e.currentTarget
    if (el.scrollTop < 80 && messages.length > 0) {
      const oldest = messages[0]
      if (oldest) await loadMore(oldest.id)
    }
  }

  if (isLoading) {
    return (
      <div className="flex flex-1 items-center justify-center text-sm text-gray-400">
        Loading messages…
      </div>
    )
  }

  return (
    <div className="flex flex-1 flex-col overflow-hidden">
      <div
        className="flex-1 overflow-y-auto px-4 py-4 space-y-3"
        onScroll={handleScroll}
      >
        <div ref={topRef} />
        {messages.length === 0 && (
          <p className="text-center text-sm text-gray-400 pt-8">
            No messages yet. Say hello!
          </p>
        )}
        {messages.map((msg) => (
          <MessageBubble
            key={msg.id}
            message={msg}
            isOwn={msg.sender_id === user?.id}
          />
        ))}
        <div ref={bottomRef} />
      </div>
      <MessageInput onSend={sendMessage} />
    </div>
  )
}
