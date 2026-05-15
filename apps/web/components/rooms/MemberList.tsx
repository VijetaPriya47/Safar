import Link from 'next/link'
import { Avatar } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import type { PublicUser } from '@safarmate/types'

export function MemberList({ members }: { members: PublicUser[] }) {
  if (!members.length) return <p className="text-sm text-gray-500 py-4 text-center">No members yet.</p>

  return (
    <ul className="divide-y divide-gray-50">
      {members.map((member) => (
        <li key={member.id}>
          <Link
            href={`/profile/${member.id}`}
            className="flex items-center gap-3 py-3 px-4 hover:bg-gray-50 transition-colors"
          >
            <Avatar name={member.name} avatarUrl={member.avatar_url} size="sm" />
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-medium text-gray-900">{member.name}</p>
              {member.college_name && (
                <p className="truncate text-xs text-gray-500">{member.college_name}</p>
              )}
            </div>
            <div className="flex gap-1 shrink-0">
              {member.pnr_verified && <Badge label="PNR" variant="green" />}
              {member.college_verified && <Badge label="Student" variant="blue" />}
            </div>
          </Link>
        </li>
      ))}
    </ul>
  )
}
