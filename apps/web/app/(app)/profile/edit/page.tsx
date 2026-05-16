'use client'

import { useState, useEffect } from 'react'
import { useRouter } from 'next/navigation'
import { getSupabaseClient } from '@/lib/supabase'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { Avatar } from '@/components/ui/avatar'
import { useAuthStore } from '@/stores/authStore'
import { useUpdateProfile } from '@/lib/hooks/useUser'
import type { UpdateProfileBody, Gender } from '@safarknots/types'

export default function EditProfilePage() {
  const router = useRouter()
  const user = useAuthStore((s) => s.user)
  const { mutate, isPending, error, isSuccess } = useUpdateProfile()

  const [form, setForm] = useState<UpdateProfileBody>({
    name: '',
    bio: '',
    gender: undefined,
    college_name: '',
  })

  useEffect(() => {
    if (user) {
      setForm({
        name: user.name,
        bio: user.bio ?? '',
        gender: user.gender ?? undefined,
        college_name: user.college_name ?? '',
      })
    }
  }, [user])

  const handleSignOut = async () => {
    await getSupabaseClient().auth.signOut()
    router.push('/')
  }

  const isLoading = useAuthStore((s) => s.isLoading)

  if (isLoading) {
    return (
      <div className="max-w-md mx-auto px-4 py-6 space-y-4">
        <div className="h-7 w-32 bg-gray-200 rounded animate-pulse" />
        <div className="flex justify-center">
          <div className="h-20 w-20 rounded-full bg-gray-200 animate-pulse" />
        </div>
        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-5 space-y-4">
          {[1, 2, 3, 4].map((i) => (
            <div key={i} className="h-10 bg-gray-100 rounded-lg animate-pulse" />
          ))}
        </div>
      </div>
    )
  }

  if (!user) return (
    <div className="max-w-md mx-auto px-4 py-6 text-center">
      <p className="text-sm text-red-500 mb-3">Could not load your profile. Please try refreshing the page.</p>
      <button
        onClick={() => window.location.reload()}
        className="text-sm text-brand-600 underline"
      >
        Refresh
      </button>
    </div>
  )

  return (
    <div className="max-w-md mx-auto px-4 py-6">
      <h1 className="text-xl font-bold text-gray-900 mb-6">Edit profile</h1>

      <div className="flex justify-center mb-6">
        <Avatar name={user.name} avatarUrl={user.avatar_url} size="lg" />
      </div>

      <form
        onSubmit={(e) => {
          e.preventDefault()
          mutate(form, { onSuccess: () => router.push(`/profile/${user.id}`) })
        }}
        className="flex flex-col gap-4 bg-white rounded-2xl border border-gray-100 shadow-sm p-5"
      >
        <Input
          label="Display name"
          value={form.name ?? ''}
          onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
        />

        <div className="flex flex-col gap-1">
          <label className="text-sm font-medium text-gray-700">Bio</label>
          <textarea
            value={form.bio ?? ''}
            onChange={(e) => setForm((f) => ({ ...f, bio: e.target.value }))}
            rows={3}
            placeholder="Tell others about yourself..."
            className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-brand-600 focus:outline-none focus:ring-1 focus:ring-brand-600"
          />
        </div>

        <div className="flex flex-col gap-1">
          <label className="text-sm font-medium text-gray-700">Gender</label>
          <select
            value={form.gender ?? ''}
            onChange={(e) => setForm((f) => ({ ...f, gender: (e.target.value as Gender) || undefined }))}
            className="rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-brand-600 focus:outline-none"
          >
            <option value="">Prefer not to say</option>
            <option value="male">Male</option>
            <option value="female">Female</option>
            <option value="other">Other</option>
          </select>
        </div>

        <Input
          label="College / University"
          value={form.college_name ?? ''}
          onChange={(e) => setForm((f) => ({ ...f, college_name: e.target.value }))}
          placeholder="Your institution"
        />

        {error && <p className="text-sm text-red-600">{(error as Error).message}</p>}
        {isSuccess && <p className="text-sm text-green-600">Profile updated!</p>}

        <Button type="submit" isLoading={isPending}>Save changes</Button>
      </form>

      <Button
        variant="ghost"
        className="w-full mt-4 text-red-500 hover:text-red-600 hover:bg-red-50"
        onClick={handleSignOut}
      >
        Sign out
      </Button>
    </div>
  )
}
