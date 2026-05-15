'use client'

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../api'
import type { Group, GroupDetail, CreateGroupBody } from '@safarknots/types'

export function useRoomGroups(roomId: string, filters?: { gender_filter?: string }) {
  const params = new URLSearchParams()
  if (filters?.gender_filter) params.set('gender_filter', filters.gender_filter)

  return useQuery({
    queryKey: ['rooms', roomId, 'groups', filters],
    queryFn: () =>
      api
        .get<{ groups: Group[] }>(`/rooms/${roomId}/groups?${params.toString()}`)
        .then((r) => r.groups),
    enabled: !!roomId,
  })
}

export function useGroup(id: string) {
  return useQuery({
    queryKey: ['groups', id],
    queryFn: () =>
      api.get<{ group: GroupDetail; members: unknown[]; isMember: boolean; isCreator: boolean }>(`/groups/${id}`),
    enabled: !!id,
  })
}

export function useCreateGroup(roomId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (body: CreateGroupBody) =>
      api.post<{ group: Group }>(`/rooms/${roomId}/groups`, body).then((r) => r.group),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['rooms', roomId, 'groups'] }),
  })
}

export function useJoinGroup() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (groupId: string) =>
      api.post<{ status: string }>(`/groups/${groupId}/join`, {}),
    onSuccess: (_, groupId) => qc.invalidateQueries({ queryKey: ['groups', groupId] }),
  })
}

export function useApproveMember(groupId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ userId, action }: { userId: string; action: 'approve' | 'reject' }) =>
      api.put(`/groups/${groupId}/members/${userId}`, { action }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['groups', groupId] }),
  })
}
