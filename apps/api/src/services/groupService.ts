import type { Group, GroupMember } from '@safarmate/types'
import { supabase } from '../lib/supabase'

export async function isRoomMember(roomId: string, userId: string): Promise<boolean> {
  const { data } = await supabase
    .from('room_members')
    .select('id')
    .eq('room_id', roomId)
    .eq('user_id', userId)
    .maybeSingle()
  return !!data
}

export async function isGroupMember(groupId: string, userId: string): Promise<boolean> {
  const { data } = await supabase
    .from('group_members')
    .select('id')
    .eq('group_id', groupId)
    .eq('user_id', userId)
    .eq('status', 'approved')
    .maybeSingle()
  return !!data
}

export async function isGroupCreator(groupId: string, userId: string): Promise<boolean> {
  const { data } = await supabase
    .from('groups')
    .select('creator_id')
    .eq('id', groupId)
    .single()
  return data?.creator_id === userId
}

export async function approveMember(groupId: string, userId: string, approverId: string): Promise<GroupMember> {
  const { data, error } = await supabase
    .from('group_members')
    .update({
      status: 'approved',
      approved_at: new Date().toISOString(),
      approved_by: approverId,
    })
    .eq('group_id', groupId)
    .eq('user_id', userId)
    .select()
    .single()

  if (error) throw new Error(error.message)

  await supabase.rpc('increment_group_member_count', { group_id: groupId })
  return data as GroupMember
}

export async function rejectMember(groupId: string, userId: string): Promise<void> {
  const { error } = await supabase
    .from('group_members')
    .update({ status: 'rejected' })
    .eq('group_id', groupId)
    .eq('user_id', userId)

  if (error) throw new Error(error.message)
}
