const required = (key: string): string => {
  const val = process.env[key]
  if (!val) throw new Error(`Missing required env var: ${key}`)
  return val
}

export const config = {
  supabaseUrl: required('SUPABASE_URL'),
  supabaseServiceRoleKey: required('SUPABASE_SERVICE_ROLE_KEY'),
  allowedOrigins: (process.env['ALLOWED_ORIGIN'] ?? 'http://localhost:3000')
    .split(',')
    .map((o) => o.trim()),
  port: parseInt(process.env['PORT'] ?? '3001', 10),
}
