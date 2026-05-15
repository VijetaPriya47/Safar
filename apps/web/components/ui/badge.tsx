import { cn } from '@/lib/utils'

interface BadgeProps {
  label: string
  variant?: 'blue' | 'green' | 'yellow' | 'gray' | 'red'
  className?: string
}

const variants = {
  blue: 'bg-blue-50 text-blue-700 border-blue-200',
  green: 'bg-green-50 text-green-700 border-green-200',
  yellow: 'bg-yellow-50 text-yellow-700 border-yellow-200',
  gray: 'bg-gray-50 text-gray-600 border-gray-200',
  red: 'bg-red-50 text-red-700 border-red-200',
}

export function Badge({ label, variant = 'gray', className }: BadgeProps) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium',
        variants[variant],
        className
      )}
    >
      {label}
    </span>
  )
}
