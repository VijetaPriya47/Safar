import Link from 'next/link'
import { Lock, Users } from 'lucide-react'
import { Badge } from '@/components/ui/badge'
import type { Group } from '@safarknots/types'

const genderLabel: Record<Group['gender_filter'], string> = {
  all_boys: 'Boys only',
  all_girls: 'Girls only',
  mixed: 'Mixed',
  any: 'Any',
}

const genderVariant: Record<Group['gender_filter'], 'blue' | 'red' | 'green' | 'gray'> = {
  all_boys: 'blue',
  all_girls: 'red',
  mixed: 'green',
  any: 'gray',
}

export function GroupCard({ group }: { group: Group }) {
  return (
    <Link
      href={`/groups/${group.id}`}
      className="flex flex-col gap-2 rounded-xl border border-gray-100 bg-white p-4 shadow-sm hover:shadow-md transition-shadow active:scale-[0.99]"
    >
      <div className="flex items-start justify-between gap-2">
        <div className="flex items-center gap-2 min-w-0">
          {group.visibility === 'private' && <Lock size={14} className="shrink-0 text-gray-400" />}
          <p className="truncate text-sm font-semibold text-gray-900">{group.name}</p>
        </div>
        <Badge label={genderLabel[group.gender_filter]} variant={genderVariant[group.gender_filter]} />
      </div>

      {group.description && (
        <p className="line-clamp-2 text-xs text-gray-500">{group.description}</p>
      )}

      <div className="flex items-center justify-between text-xs text-gray-500">
        <div className="flex items-center gap-1">
          <Users size={12} />
          <span>{group.member_count} / {group.max_members}</span>
        </div>
        {group.requires_approval && <span className="text-yellow-600">Approval required</span>}
      </div>
    </Link>
  )
}
