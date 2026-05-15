import { GoogleSignInButton } from '@/components/auth/GoogleSignInButton'
import { Shield } from 'lucide-react'

export default function LoginPage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center px-6 bg-gray-50">
      <div className="w-full max-w-sm">
        <div className="text-center mb-8">
          <h1 className="text-2xl font-bold text-gray-900 mb-2">Welcome to SafarMate</h1>
          <p className="text-sm text-gray-500">Sign in to find your travel companions</p>
        </div>

        <div className="bg-white rounded-2xl border border-gray-100 shadow-sm p-6">
          <GoogleSignInButton />

          <div className="mt-6 flex items-start gap-3 rounded-lg bg-blue-50 p-3">
            <Shield size={16} className="shrink-0 text-blue-600 mt-0.5" />
            <p className="text-xs text-blue-700 leading-relaxed">
              We use Google OAuth — we never store your password. Your contact
              details stay private until you join a group.
            </p>
          </div>
        </div>

        <p className="mt-6 text-center text-xs text-gray-400">
          By signing in, you agree to our Terms of Service and Privacy Policy.
        </p>
      </div>
    </main>
  )
}
