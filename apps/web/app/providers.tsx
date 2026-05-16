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

    // Single source of truth for auth state — onAuthStateChange fires INITIAL_SESSION
    // immediately on subscribe, so getSession() is not needed for initialization.
    // This avoids a race condition where getSession() calls /auth/me before
    // sync-profile has created the user row on the first sign-in.
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      setSession(session)
      if (session) {
        if (event === 'SIGNED_IN') {
          const googleUser = session.user
          await api.post('/auth/sync-profile', {
            name: googleUser.user_metadata['full_name'] ?? googleUser.email,
            email: googleUser.email,
            avatar_url: googleUser.user_metadata['avatar_url'],
            google_id: googleUser.id,
          }).catch(() => {})
        }
        try {
          const r = await api.get<{ user: any }>('/auth/me')
          setUser(r.user)
        } catch {
          setUser(null)
        }
      } else {
        clear()
      }
      setIsLoading(false)
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
