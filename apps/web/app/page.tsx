'use client'

import Link from 'next/link'
import { Train, Shield, Users, ArrowRight, Search } from 'lucide-react'
import { Avatar } from '@/components/ui/avatar'
import { useAuthStore } from '@/stores/authStore'

export default function LandingPage() {
  const user = useAuthStore((s) => s.user)
  const isLoading = useAuthStore((s) => s.isLoading)

  return (
    <main className="min-h-screen bg-white">
      {/* Nav */}
      <nav className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
        <span className="text-xl font-bold text-brand-600">SafarKnots</span>

        {!isLoading && (
          user ? (
            <Link
              href="/dashboard"
              className="flex items-center gap-2 rounded-lg border border-gray-200 px-3 py-1.5 text-sm font-medium text-gray-700 hover:border-brand-300 hover:text-brand-600 transition-colors"
            >
              <Avatar name={user.name} avatarUrl={user.avatar_url} size="sm" />
              <span className="max-w-[120px] truncate">{user.name}</span>
            </Link>
          ) : (
            <Link
              href="/login"
              className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-medium text-white hover:bg-brand-700 transition-colors"
            >
              Sign in
            </Link>
          )
        )}
      </nav>

      {/* Hero */}
      <section className="px-6 py-16 text-center max-w-lg mx-auto">
        <div className="mb-6 inline-flex items-center gap-2 rounded-full bg-brand-50 px-4 py-2 text-sm font-medium text-brand-700">
          <Shield size={14} />
          Safety-first travel coordination
        </div>

        <h1 className="text-4xl font-bold tracking-tight text-gray-900 mb-4">
          Find your travel <span className="text-brand-600">companions</span>
        </h1>

        <p className="text-gray-500 text-lg mb-8 leading-relaxed">
          Connect with verified travelers on your train or flight. Form safe groups,
          coordinate plans, and journey together.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
          {user ? (
            <Link
              href="/dashboard"
              className="inline-flex items-center gap-2 rounded-xl bg-brand-600 px-8 py-4 text-base font-semibold text-white hover:bg-brand-700 transition-colors shadow-lg shadow-brand-600/30"
            >
              Go to my profile
              <ArrowRight size={18} />
            </Link>
          ) : (
            <Link
              href="/login"
              className="inline-flex items-center gap-2 rounded-xl bg-brand-600 px-8 py-4 text-base font-semibold text-white hover:bg-brand-700 transition-colors shadow-lg shadow-brand-600/30"
            >
              Get started free
              <ArrowRight size={18} />
            </Link>
          )}
          <Link
            href="/rooms"
            className="inline-flex items-center gap-2 rounded-xl border border-gray-200 bg-white px-8 py-4 text-base font-semibold text-gray-700 hover:border-brand-300 hover:text-brand-600 transition-colors"
          >
            <Search size={18} />
            Browse rooms
          </Link>
        </div>

        <p className="mt-4 text-xs text-gray-400">No account needed to browse · Sign in with Google to join</p>
      </section>

      {/* Features */}
      <section className="px-6 py-8 max-w-lg mx-auto">
        <div className="grid gap-4">
          {[
            {
              icon: Train,
              title: 'Train & flight rooms',
              desc: 'Browse active rooms for your route. See who else is traveling — no sign-in required.',
              href: '/rooms',
            },
            {
              icon: Users,
              title: 'Private groups',
              desc: 'Create or join travel groups with filters for gender, college batch, and group size.',
              href: user ? '/rooms' : '/login',
            },
            {
              icon: Shield,
              title: 'Safe by design',
              desc: 'Contact details stay hidden until you join a group. Verified PNR and student badges.',
              href: user ? '/verify' : '/login',
            },
          ].map(({ icon: Icon, title, desc, href }) => (
            <Link key={title} href={href} className="flex gap-4 rounded-xl border border-gray-100 bg-white p-4 shadow-sm hover:border-brand-200 hover:shadow-md transition-all">
              <div className="shrink-0 h-10 w-10 rounded-lg bg-brand-50 flex items-center justify-center">
                <Icon size={20} className="text-brand-600" />
              </div>
              <div>
                <p className="font-semibold text-gray-900 mb-1">{title}</p>
                <p className="text-sm text-gray-500 leading-relaxed">{desc}</p>
              </div>
            </Link>
          ))}
        </div>
      </section>
    </main>
  )
}
