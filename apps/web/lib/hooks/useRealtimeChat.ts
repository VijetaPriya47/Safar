'use client'

import { useState, useEffect, useCallback, useRef } from 'react'
import { getSupabaseClient } from '../supabase'
import { api } from '../api'
import type { MessageWithSender } from '@safarmate/types'

interface UseRealtimeChatOptions {
  roomId?: string
  groupId?: string
}

export function useRealtimeChat({ roomId, groupId }: UseRealtimeChatOptions) {
  const [messages, setMessages] = useState<MessageWithSender[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const channelRef = useRef<ReturnType<ReturnType<typeof getSupabaseClient>['channel']> | null>(null)

  const chatPath = roomId ? `/rooms/${roomId}/messages` : `/groups/${groupId}/messages`
  const channelName = roomId ? `room:${roomId}` : `group:${groupId}`
  const filterKey = roomId ? 'room_id' : 'group_id'
  const filterValue = roomId ?? groupId ?? ''

  // Load initial history
  useEffect(() => {
    setIsLoading(true)
    api
      .get<{ messages: MessageWithSender[] }>(chatPath)
      .then((r) => setMessages(r.messages))
      .catch(console.error)
      .finally(() => setIsLoading(false))
  }, [chatPath])

  // Subscribe to realtime new messages
  useEffect(() => {
    const supabase = getSupabaseClient()

    channelRef.current = supabase
      .channel(channelName)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'messages',
          filter: `${filterKey}=eq.${filterValue}`,
        },
        (payload) => {
          setMessages((prev) => {
            // Avoid duplicates from optimistic updates
            if (prev.some((m) => m.id === payload.new.id)) return prev
            return [...prev, payload.new as MessageWithSender]
          })
        }
      )
      .subscribe()

    return () => {
      channelRef.current?.unsubscribe()
    }
  }, [channelName, filterKey, filterValue])

  // Load older messages (infinite scroll)
  const loadMore = useCallback(
    async (beforeId: string) => {
      const res = await api.get<{ messages: MessageWithSender[] }>(
        `${chatPath}?before=${beforeId}&limit=50`
      )
      setMessages((prev) => [...res.messages, ...prev])
      return res.messages.length
    },
    [chatPath]
  )

  // Send a message directly via Supabase (RLS enforces membership)
  const sendMessage = useCallback(
    async (content: string) => {
      const supabase = getSupabaseClient()
      const trimmed = content.trim()
      if (!trimmed) return

      const { error } = await supabase.from('messages').insert({
        ...(roomId ? { room_id: roomId } : { group_id: groupId }),
        content: trimmed,
        message_type: 'text',
      })

      if (error) throw new Error(error.message)
    },
    [roomId, groupId]
  )

  return { messages, isLoading, sendMessage, loadMore }
}
