/**
 * Pushes migration + seed SQL to Supabase in chunks via the Management API.
 * Requires SUPABASE_ACCESS_TOKEN env var (get from supabase.com/dashboard/account/tokens).
 * Falls back to printing instructions if token not available.
 */
import { readFileSync } from 'fs'
import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
const PROJECT_REF = process.env.SUPABASE_PROJECT_REF ?? SUPABASE_URL?.match(/https:\/\/([^.]+)/)?.[1]

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars.')
  console.error('Run from the repo root: cd apps/api && node --env-file=.env ../../scripts/push-to-supabase.mjs')
  process.exit(1)
}

// Try management API first (needs personal access token)
const accessToken = process.env.SUPABASE_ACCESS_TOKEN

async function runSqlViaManagementApi(sql) {
  const res = await fetch(`https://api.supabase.com/v1/projects/${PROJECT_REF}/database/query`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ query: sql }),
  })
  const text = await res.text()
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text}`)
  return JSON.parse(text)
}

async function insertViaBulkRest(table, rows) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: 'POST',
    headers: {
      'apikey': SERVICE_ROLE_KEY,
      'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=minimal,resolution=ignore-duplicates',
    },
    body: JSON.stringify(rows),
  })
  if (!res.ok) {
    const err = await res.text()
    throw new Error(`Insert into ${table} failed: ${err}`)
  }
}

if (!accessToken) {
  console.log('\nNo SUPABASE_ACCESS_TOKEN set.')
  console.log('Get one from: https://supabase.com/dashboard/account/tokens')
  console.log('\nRun with:')
  console.log('  SUPABASE_ACCESS_TOKEN=your_token node scripts/push-to-supabase.mjs\n')
  console.log('The file to paste manually is:')
  console.log('  supabase/migrations/000_full_setup.sql')
  process.exit(0)
}

console.log('Pushing schema + seed to Supabase via Management API...\n')

const schema = readFileSync('supabase/migrations/001_init.sql', 'utf8')
const seed   = readFileSync('supabase/migrations/002_seed.sql', 'utf8')

try {
  console.log('1/2  Running schema migration...')
  await runSqlViaManagementApi(schema)
  console.log('     Schema created.')

  console.log('2/2  Running seed data...')
  await runSqlViaManagementApi(seed)
  console.log('     Seed inserted.')

  console.log('\nDone! Verify at:')
  console.log(`  https://supabase.com/dashboard/project/${PROJECT_REF}/editor`)
} catch (err) {
  console.error('Error:', err.message)
  process.exit(1)
}
