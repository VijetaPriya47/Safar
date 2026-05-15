'use client'

import { useEffect, type ReactNode } from 'react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { getSupabaseClient } from '@/lib/supabase'
import { useAuthStore } from '@/stores/authStore'
import { api } from '@/lib/api'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 60_000, retry: 1 },
  },
})

function AuthProvider({ children }: { children: ReactNode }) {
  const { setSession, setUser, setIsLoading, clear } = useAuthStore()

  useEffect(() => {
    const supabase = getSupabaseClient()

    supabase.auth.getSession().then(async ({ data }) => {
      setSession(data.session)
      if (data.session) {
        try {
          const r = await api.get<{ user: any }>('/auth/me')
          setUser(r.user)
        } catch {}
      }
      setIsLoading(false)
    })

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      setSession(session)
      if (session) {
        // Sync profile on first sign-in
        if (event === 'SIGNED_IN') {
          const googleUser = session.user
          await api.post('/auth/sync-profile', {
            name: googleUser.user_metadata['full_name'] ?? googleUser.email,
            email: googleUser.email,
            avatar_url: googleUser.user_metadata['avatar_url'],
            google_id: googleUser.id,
          }).catch(() => {})
        }
        api.get<{ user: any }>('/auth/me').then((r) => setUser(r.user)).catch(() => {})
      } else {
        clear()
      }
    })

    return () => subscription.unsubscribe()
  }, [setSession, setUser, setIsLoading, clear])

  return <>{children}</>
}

export function Providers({ children }: { children: ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>{children}</AuthProvider>
    </QueryClientProvider>
  )
}
