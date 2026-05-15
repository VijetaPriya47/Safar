import Image from 'next/image'
import { cn, getInitials } from '@/lib/utils'

interface AvatarProps {
  name: string
  avatarUrl?: string | null
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

const sizes = {
  sm: { container: 'h-8 w-8', text: 'text-xs' },
  md: { container: 'h-10 w-10', text: 'text-sm' },
  lg: { container: 'h-14 w-14', text: 'text-lg' },
}

export function Avatar({ name, avatarUrl, size = 'md', className }: AvatarProps) {
  const { container, text } = sizes[size]

  if (avatarUrl) {
    return (
      <div className={cn('relative overflow-hidden rounded-full', container, className)}>
        <Image src={avatarUrl} alt={name} fill className="object-cover" sizes="56px" />
      </div>
    )
  }

  return (
    <div
      className={cn(
        'flex items-center justify-center rounded-full bg-brand-100 font-semibold text-brand-700',
        container,
        text,
        className
      )}
    >
      {getInitials(name)}
    </div>
  )
}
