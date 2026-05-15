import Link from 'next/link'
import { Train, Shield, Users, ArrowRight } from 'lucide-react'

export default function LandingPage() {
  return (
    <main className="min-h-screen bg-white">
      {/* Nav */}
      <nav className="flex items-center justify-between px-6 py-4 border-b border-gray-100">
        <span className="text-xl font-bold text-brand-600">SafarMate</span>
        <Link
          href="/login"
          className="rounded-lg bg-brand-600 px-4 py-2 text-sm font-medium text-white hover:bg-brand-700 transition-colors"
        >
          Sign in
        </Link>
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

        <Link
          href="/login"
          className="inline-flex items-center gap-2 rounded-xl bg-brand-600 px-8 py-4 text-base font-semibold text-white hover:bg-brand-700 transition-colors shadow-lg shadow-brand-600/30"
        >
          Get started free
          <ArrowRight size={18} />
        </Link>

        <p className="mt-4 text-xs text-gray-400">No credit card required · Google login</p>
      </section>

      {/* Features */}
      <section className="px-6 py-8 max-w-lg mx-auto">
        <div className="grid gap-4">
          {[
            {
              icon: Train,
              title: 'Train & flight rooms',
              desc: 'Join a shared room the moment you add your journey. Instantly see who else is traveling with you.',
            },
            {
              icon: Users,
              title: 'Private groups',
              desc: 'Create or join travel groups with filters for gender, college batch, and group size.',
            },
            {
              icon: Shield,
              title: 'Safe by design',
              desc: 'Contact details stay hidden until you join a group. Verified PNR and student badges.',
            },
          ].map(({ icon: Icon, title, desc }) => (
            <div key={title} className="flex gap-4 rounded-xl border border-gray-100 bg-white p-4 shadow-sm">
              <div className="shrink-0 h-10 w-10 rounded-lg bg-brand-50 flex items-center justify-center">
                <Icon size={20} className="text-brand-600" />
              </div>
              <div>
                <p className="font-semibold text-gray-900 mb-1">{title}</p>
                <p className="text-sm text-gray-500 leading-relaxed">{desc}</p>
              </div>
            </div>
          ))}
        </div>
      </section>
    </main>
  )
}
