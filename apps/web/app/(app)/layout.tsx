'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { Home, Search, User, PlusCircle, LogOut } from 'lucide-react'
import { cn } from '@/lib/utils'
import { getSupabaseClient } from '@/lib/supabase'

const navItems = [
  { href: '/dashboard', icon: Home, label: 'Home' },
  { href: '/rooms', icon: Search, label: 'Browse' },
  { href: '/journeys/new', icon: PlusCircle, label: 'Add trip' },
  { href: '/profile/edit', icon: User, label: 'Profile' },
]

export default function AppLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()

  const handleSignOut = async () => {
    await getSupabaseClient().auth.signOut()
    window.location.href = '/'
  }

  return (
    <div className="flex flex-col min-h-screen">
      <main className="flex-1 overflow-hidden pb-16">{children}</main>

      {/* Mobile bottom nav */}
      <nav className="fixed bottom-0 left-0 right-0 border-t border-gray-100 bg-white pb-safe z-40">
        <div className="flex items-center justify-around px-2 pt-2 pb-1">
          {navItems.map(({ href, icon: Icon, label }) => {
            const isActive = pathname === href || (href !== '/dashboard' && pathname.startsWith(href))
            return (
              <Link
                key={href}
                href={href}
                className={cn(
                  'flex flex-col items-center gap-0.5 px-3 py-1.5 rounded-xl transition-colors',
                  isActive ? 'text-brand-600' : 'text-gray-400 hover:text-gray-600'
                )}
              >
                <Icon size={22} strokeWidth={isActive ? 2.5 : 1.5} />
                <span className="text-[10px] font-medium">{label}</span>
              </Link>
            )
          })}
          <button
            onClick={handleSignOut}
            className="flex flex-col items-center gap-0.5 px-3 py-1.5 rounded-xl transition-colors text-gray-400 hover:text-red-500"
          >
            <LogOut size={22} strokeWidth={1.5} />
            <span className="text-[10px] font-medium">Sign out</span>
          </button>
        </div>
      </nav>
    </div>
  )
}
