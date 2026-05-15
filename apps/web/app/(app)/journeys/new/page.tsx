'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { useMutation } from '@tanstack/react-query'
import { api } from '@/lib/api'
import { Input } from '@/components/ui/input'
import { Button } from '@/components/ui/button'
import type { CreateJourneyBody } from '@safarknots/types'

export default function NewJourneyPage() {
  const router = useRouter()
  const [form, setForm] = useState<CreateJourneyBody>({
    journey_type: 'train',
    source: '',
    destination: '',
    journey_date: '',
  })

  const { mutate, isPending, error } = useMutation({
    mutationFn: (body: CreateJourneyBody) =>
      api.post<{ journey: any; room: any }>('/journeys', body),
    onSuccess: (data) => {
      router.push(`/rooms/${data.room.id}`)
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    mutate(form)
  }

  return (
    <div className="max-w-md mx-auto px-4 py-6">
      <div className="mb-6">
        <h1 className="text-xl font-bold text-gray-900">Add a journey</h1>
        <p className="text-sm text-gray-500 mt-1">We'll match you with other travelers on the same route.</p>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4 bg-white rounded-2xl border border-gray-100 shadow-sm p-5">
        {/* Journey type */}
        <div className="flex flex-col gap-1">
          <label className="text-sm font-medium text-gray-700">Journey type</label>
          <div className="flex gap-2">
            {(['train', 'flight', 'route'] as const).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setForm((f) => ({ ...f, journey_type: t }))}
                className={`flex-1 rounded-lg border py-2 text-sm font-medium capitalize transition-colors ${
                  form.journey_type === t
                    ? 'border-brand-600 bg-brand-50 text-brand-700'
                    : 'border-gray-200 text-gray-500 hover:border-gray-300'
                }`}
              >
                {t}
              </button>
            ))}
          </div>
        </div>

        {/* Train / flight number */}
        {form.journey_type === 'train' && (
          <Input
            label="Train number"
            required
            value={form.train_number ?? ''}
            onChange={(e) => setForm((f) => ({ ...f, train_number: e.target.value }))}
            placeholder="e.g. 12301"
          />
        )}
        {form.journey_type === 'flight' && (
          <Input
            label="Flight number"
            required
            value={form.flight_number ?? ''}
            onChange={(e) => setForm((f) => ({ ...f, flight_number: e.target.value }))}
            placeholder="e.g. AI202"
          />
        )}

        <div className="grid grid-cols-2 gap-3">
          <Input
            label="From"
            required
            value={form.source}
            onChange={(e) => setForm((f) => ({ ...f, source: e.target.value }))}
            placeholder="Delhi"
          />
          <Input
            label="To"
            required
            value={form.destination}
            onChange={(e) => setForm((f) => ({ ...f, destination: e.target.value }))}
            placeholder="Guwahati"
          />
        </div>

        <Input
          label="Date"
          type="date"
          required
          value={form.journey_date}
          onChange={(e) => setForm((f) => ({ ...f, journey_date: e.target.value }))}
        />

        <Input
          label="PNR number (optional)"
          value={form.pnr_number ?? ''}
          onChange={(e) => setForm((f) => ({ ...f, pnr_number: e.target.value }))}
          placeholder="For verification badge"
        />

        {error && <p className="text-sm text-red-600">{(error as Error).message}</p>}

        <Button type="submit" isLoading={isPending} size="lg">
          Find my room →
        </Button>
      </form>
    </div>
  )
}
