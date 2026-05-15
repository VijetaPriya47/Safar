'use client'

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../api'
import type { User, PublicUser, UpdateProfileBody } from '@safarknots/types'

export function useMe() {
  return useQuery({
    queryKey: ['auth', 'me'],
    queryFn: () => api.get<{ user: User }>('/auth/me').then((r) => r.user),
    staleTime: 5 * 60 * 1000,
  })
}

export function useUser(id: string) {
  return useQuery({
    queryKey: ['users', id],
    queryFn: () => api.get<{ user: PublicUser }>(`/users/${id}`).then((r) => r.user),
    enabled: !!id,
  })
}

export function useUpdateProfile() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (body: UpdateProfileBody) =>
      api.put<{ user: User }>('/users/me', body).then((r) => r.user),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['auth', 'me'] }),
  })
}

export function useBlockUser() {
  return useMutation({
    mutationFn: (userId: string) => api.post(`/users/${userId}/block`, {}),
  })
}
