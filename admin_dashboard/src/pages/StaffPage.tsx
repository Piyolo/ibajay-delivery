import { useState } from 'react'
import { api } from '../lib/api'
import { useAsyncData } from '../state/live'
import { can, useAuth } from '../state/auth'
import { fmtDate } from '../lib/format'
import {
  Badge,
  Card,
  EmptyState,
  PageHeader,
  SearchBox,
} from '../components/ui/primitives'

interface AdminStaffRow {
  id: string
  full_name: string
  email: string
  mobile_number: string
  is_active: boolean
  created_at: string
}

export function StaffPage() {
  const { user } = useAuth()
  const role = user?.role ?? 'staff'
  const canManage = can(role, 'staff.manage')
  const [query, setQuery] = useState('')

  const staffUsers = useAsyncData(() => api<AdminStaffRow[]>('/admin/staff')).data ?? []

  const rows = staffUsers.filter(
    (s) =>
      !query.trim() ||
      s.full_name.toLowerCase().includes(query.trim().toLowerCase()) ||
      s.email.toLowerCase().includes(query.trim().toLowerCase()),
  )

  return (
    <>
      <PageHeader
        title="Staff Management"
        description="Administrator accounts with console access. Read-only for now — invites and role edits land with the backend staff endpoints."
      />

      <div className="filters-bar">
        <SearchBox value={query} onChange={setQuery} placeholder="Search name or email…" />
      </div>

      <Card>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Mobile</th>
                <th>Status</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((s) => (
                <tr key={s.id}>
                  <td><span className="cell-main">{s.full_name}</span></td>
                  <td>{s.email}</td>
                  <td>{s.mobile_number}</td>
                  <td>
                    <Badge tone={s.is_active ? 'green' : 'red'}>
                      {s.is_active ? 'active' : 'disabled'}
                    </Badge>
                  </td>
                  <td>{fmtDate(s.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!rows.length && <EmptyState message="No admin accounts found." />}
        </div>
      </Card>

      {canManage && (
        <p className="small muted" style={{ marginTop: 10 }}>
          Inviting or disabling staff requires a backend endpoint that is not available yet.
        </p>
      )}
    </>
  )
}
