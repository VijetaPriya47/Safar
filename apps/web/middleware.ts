import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

const PROTECTED = ['/dashboard', '/rooms', '/groups', '/profile', '/journeys', '/verify']

export async function middleware(request: NextRequest) {
  const response = NextResponse.next({ request })
  const path = request.nextUrl.pathname

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  if (!supabaseUrl || !supabaseAnonKey) return response

  try {
    const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cookiesToSet: { name: string; value: string; options?: Record<string, unknown> }[]) => {
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options as Parameters<typeof response.cookies.set>[2])
          )
        },
      },
    })

    const { data: { user } } = await supabase.auth.getUser()
    const isProtected = PROTECTED.some((p) => path.startsWith(p))

    if (isProtected && !user) {
      return NextResponse.redirect(new URL('/login', request.url))
    }

    if ((path === '/login' || path === '/') && user) {
      return NextResponse.redirect(new URL('/dashboard', request.url))
    }
  } catch {
    // fail open — let the request through if auth check errors
  }

  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|auth/callback).*)'],
}
