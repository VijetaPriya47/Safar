'use client'

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../api'
import type { Room, RoomDetail, Paginated } from '@safarmate/types'

interface RoomsQuery {
  type?: string
  date?: string
  source?: string
  destination?: string
  page?: number
}

export function useRooms(query: RoomsQuery = {}) {
  const params = new URLSearchParams()
  if (query.type) params.set('type', query.type)
  if (query.date) params.set('date', query.date)
  if (query.source) params.set('source', query.source)
  if (query.destination) params.set('destination', query.destination)
  if (query.page) params.set('page', String(query.page))

  return useQuery({
    queryKey: ['rooms', query],
    queryFn: () =>
      api.get<{ rooms: Room[]; total: number }>(`/rooms?${params.toString()}`),
  })
}

export function useRoom(id: string) {
  return useQuery({
    queryKey: ['rooms', id],
    queryFn: () => api.get<{ room: RoomDetail }>(`/rooms/${id}`).then((r) => r.room),
    enabled: !!id,
  })
}

export function useJoinRoom() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (roomId: string) => api.post(`/rooms/${roomId}/join`, {}),
    onSuccess: (_, roomId) => {
      qc.invalidateQueries({ queryKey: ['rooms', roomId] })
    },
  })
}

export function useLeaveRoom() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (roomId: string) => api.delete(`/rooms/${roomId}/leave`),
    onSuccess: (_, roomId) => {
      qc.invalidateQueries({ queryKey: ['rooms', roomId] })
    },
  })
}
