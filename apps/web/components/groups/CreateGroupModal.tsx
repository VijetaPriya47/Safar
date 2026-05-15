'use client'

import { useState } from 'react'
import { Modal } from '@/components/ui/modal'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import { useCreateGroup } from '@/lib/hooks/useGroup'
import type { CreateGroupBody } from '@safarmate/types'

interface CreateGroupModalProps {
  roomId: string
  isOpen: boolean
  onClose: () => void
}

export function CreateGroupModal({ roomId, isOpen, onClose }: CreateGroupModalProps) {
  const { mutate, isPending, error } = useCreateGroup(roomId)
  const [form, setForm] = useState<CreateGroupBody>({
    name: '',
    description: '',
    gender_filter: 'any',
    max_members: 10,
    visibility: 'public',
    requires_approval: false,
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    mutate(form, {
      onSuccess: () => {
        onClose()
        setForm({ name: '', description: '', gender_filter: 'any', max_members: 10, visibility: 'public', requires_approval: false })
      },
    })
  }

  return (
    <Modal isOpen={isOpen} onClose={onClose} title="Create a Group">
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input
          label="Group name"
          required
          value={form.name}
          onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
          placeholder="e.g. Night Owls, Girls Squad"
        />
        <div className="flex flex-col gap-1">
          <label className="text-sm font-medium text-gray-700">Description (optional)</label>
          <textarea
            value={form.description}
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            placeholder="Tell people what your group is about..."
            rows={2}
            className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-brand-600 focus:outline-none focus:ring-1 focus:ring-brand-600"
          />
        </div>

        <div className="grid grid-cols-2 gap-3">
          <div className="flex flex-col gap-1">
            <label className="text-sm font-medium text-gray-700">Gender filter</label>
            <select
              value={form.gender_filter}
              onChange={(e) => setForm((f) => ({ ...f, gender_filter: e.target.value as CreateGroupBody['gender_filter'] }))}
              className="rounded-lg border border-gray-200 px-3 py-2 text-sm focus:border-brand-600 focus:outline-none"
            >
              <option value="any">Any</option>
              <option value="all_girls">Girls only</option>
              <option value="all_boys">Boys only</option>
              <option value="mixed">Mixed</option>
            </select>
          </div>
          <Input
            label="Max members"
            type="number"
            min={2}
            max={50}
            value={form.max_members}
            onChange={(e) => setForm((f) => ({ ...f, max_members: parseInt(e.target.value, 10) }))}
          />
        </div>

        <div className="flex items-center gap-4">
          <label className="flex items-center gap-2 text-sm text-gray-700">
            <input
              type="checkbox"
              checked={form.visibility === 'private'}
              onChange={(e) => setForm((f) => ({ ...f, visibility: e.target.checked ? 'private' : 'public' }))}
              className="rounded"
            />
            Private group
          </label>
          <label className="flex items-center gap-2 text-sm text-gray-700">
            <input
              type="checkbox"
              checked={form.requires_approval}
              onChange={(e) => setForm((f) => ({ ...f, requires_approval: e.target.checked }))}
              className="rounded"
            />
            Require approval
          </label>
        </div>

        {error && <p className="text-sm text-red-600">{(error as Error).message}</p>}

        <div className="flex gap-2 pt-2">
          <Button type="button" variant="secondary" className="flex-1" onClick={onClose}>
            Cancel
          </Button>
          <Button type="submit" className="flex-1" isLoading={isPending}>
            Create group
          </Button>
        </div>
      </form>
    </Modal>
  )
}
