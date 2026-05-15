'use client'

import { useState } from 'react'
import { Shield, CheckCircle, Upload } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'
import { useAuthStore } from '@/stores/authStore'

export default function VerifyPage() {
  const user = useAuthStore((s) => s.user)
  const [uploading, setUploading] = useState(false)
  const [done, setDone] = useState(false)

  const handleUpload = async (type: 'pnr' | 'college', file: File) => {
    setUploading(true)
    // TODO: upload to Supabase Storage via signed URL, then call POST /verifications
    await new Promise((r) => setTimeout(r, 800))
    setDone(true)
    setUploading(false)
  }

  return (
    <div className="max-w-md mx-auto px-4 py-6">
      <div className="flex items-center gap-3 mb-6">
        <Shield size={24} className="text-brand-600" />
        <h1 className="text-xl font-bold text-gray-900">Get verified</h1>
      </div>

      <div className="space-y-4">
        {/* PNR Verification */}
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
          <div className="flex items-start justify-between mb-3">
            <div>
              <p className="font-semibold text-gray-900">PNR Verification</p>
              <p className="text-xs text-gray-500 mt-0.5">Upload your ticket / PNR confirmation</p>
            </div>
            {user?.pnr_verified
              ? <Badge label="Verified" variant="green" />
              : <Badge label="Not verified" variant="gray" />}
          </div>

          {done ? (
            <div className="flex items-center gap-2 text-green-600 text-sm">
              <CheckCircle size={16} />
              Submitted for review
            </div>
          ) : (
            <label className="cursor-pointer">
              <div className="flex items-center gap-2 rounded-lg border border-dashed border-gray-200 px-4 py-3 hover:border-brand-400 transition-colors">
                <Upload size={16} className="text-gray-400" />
                <span className="text-sm text-gray-500">Choose file (PDF or image)</span>
              </div>
              <input
                type="file"
                className="sr-only"
                accept="image/*,.pdf"
                onChange={(e) => {
                  const file = e.target.files?.[0]
                  if (file) handleUpload('pnr', file)
                }}
              />
            </label>
          )}
        </div>

        {/* Student Verification */}
        <div className="bg-white rounded-xl border border-gray-100 shadow-sm p-4">
          <div className="flex items-start justify-between mb-3">
            <div>
              <p className="font-semibold text-gray-900">Student Verification</p>
              <p className="text-xs text-gray-500 mt-0.5">Upload your college ID card</p>
            </div>
            {user?.college_verified
              ? <Badge label="Verified" variant="blue" />
              : <Badge label="Not verified" variant="gray" />}
          </div>

          <label className="cursor-pointer">
            <div className="flex items-center gap-2 rounded-lg border border-dashed border-gray-200 px-4 py-3 hover:border-brand-400 transition-colors">
              <Upload size={16} className="text-gray-400" />
              <span className="text-sm text-gray-500">Choose file (image)</span>
            </div>
            <input
              type="file"
              className="sr-only"
              accept="image/*"
              onChange={(e) => {
                const file = e.target.files?.[0]
                if (file) handleUpload('college', file)
              }}
            />
          </label>
        </div>

        <p className="text-xs text-gray-400 text-center">
          Documents are reviewed within 24 hours. They are never shown to other users.
        </p>
      </div>
    </div>
  )
}
