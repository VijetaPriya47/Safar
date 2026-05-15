import Link from 'next/link'
import { Avatar } from '@/components/ui/avatar'
import { formatRelativeTime } from '@/lib/utils'
import { cn } from '@/lib/utils'
import type { MessageWithSender } from '@safarknots/types'

interface MessageBubbleProps {
  message: MessageWithSender
  isOwn: boolean
}

export function MessageBubble({ message, isOwn }: MessageBubbleProps) {
  if (message.message_type === 'system') {
    return (
      <div className="py-1 text-center text-xs text-gray-400">{message.content}</div>
    )
  }

  return (
    <div className={cn('flex gap-2', isOwn && 'flex-row-reverse')}>
      {!isOwn && (
        <Link href={`/profile/${message.sender_id}`} className="shrink-0 self-end">
          <Avatar name={message.sender?.name ?? '?'} avatarUrl={message.sender?.avatar_url} size="sm" />
        </Link>
      )}

      <div className={cn('flex max-w-[75%] flex-col gap-0.5', isOwn && 'items-end')}>
        {!isOwn && (
          <Link href={`/profile/${message.sender_id}`} className="text-xs font-medium text-gray-600 hover:underline">
            {message.sender?.name}
          </Link>
        )}
        <div
          className={cn(
            'rounded-2xl px-3 py-2 text-sm leading-relaxed',
            isOwn
              ? 'rounded-tr-sm bg-brand-600 text-white'
              : 'rounded-tl-sm bg-gray-100 text-gray-900'
          )}
        >
          {message.content}
        </div>
        <span className="text-[10px] text-gray-400">{formatRelativeTime(message.created_at)}</span>
      </div>
    </div>
  )
}
