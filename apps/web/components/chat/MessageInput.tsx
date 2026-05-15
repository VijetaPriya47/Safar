'use client'

import { useState, type KeyboardEvent } from 'react'
import { Send } from 'lucide-react'
import { cn } from '@/lib/utils'

interface MessageInputProps {
  onSend: (content: string) => Promise<void>
  disabled?: boolean
}

export function MessageInput({ onSend, disabled }: MessageInputProps) {
  const [value, setValue] = useState('')
  const [isSending, setIsSending] = useState(false)

  const handleSend = async () => {
    const trimmed = value.trim()
    if (!trimmed || isSending) return
    setIsSending(true)
    try {
      await onSend(trimmed)
      setValue('')
    } catch (err) {
      console.error(err)
    } finally {
      setIsSending(false)
    }
  }

  const handleKey = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  return (
    <div className="border-t border-gray-100 bg-white px-4 py-3 pb-safe">
      <div className="flex items-end gap-2">
        <textarea
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={handleKey}
          placeholder="Type a message..."
          rows={1}
          disabled={disabled || isSending}
          className={cn(
            'flex-1 resize-none rounded-2xl border border-gray-200 px-4 py-2.5 text-sm',
            'focus:border-brand-600 focus:outline-none focus:ring-1 focus:ring-brand-600',
            'max-h-32 overflow-y-auto',
            'disabled:bg-gray-50 disabled:text-gray-400'
          )}
          style={{ lineHeight: '1.4' }}
        />
        <button
          onClick={handleSend}
          disabled={!value.trim() || isSending || disabled}
          className={cn(
            'flex h-10 w-10 shrink-0 items-center justify-center rounded-full transition-colors',
            value.trim()
              ? 'bg-brand-600 text-white hover:bg-brand-700'
              : 'bg-gray-100 text-gray-400 cursor-not-allowed'
          )}
        >
          <Send size={16} />
        </button>
      </div>
    </div>
  )
}
