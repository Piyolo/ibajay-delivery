import { useState } from 'react'
import { UserPlus } from 'lucide-react'
import { staffUsers } from '../data/mockDb'
import type { Role, StaffUser } from '../types'
import { can, useAuth } from '../state/auth'
import { flash } from '../lib/flash'
import { timeAgo } from '../lib/format'
import {
  Badge,
  Card,
  PageHeader,
  SearchBox,
} from '../components/ui/primitives'

export function StaffPage() {
  const { user } = useAuth()
  const role = user?.role ?? 'staff'
  const canManage = can(role, 'staff.manage')
  const [version, setVersion] = useState(0)
  const [query, setQuery] = useState('')
  const [adding, setAdding] = useState(false)

  const rows = staffUsers.filter(
    (s) =>
      !query.trim() ||
      s.name.toLowerCase().includes(query.trim().toLowerCase()) ||
      s.email.toLowerCase().includes(query.trim().toLowerCase()),
  )

  return (
    <>
      <PageHeader
        title="Staff Management"
        description={
          canManage
            ? 'Manage console access for developers, managers and staff.'
            : 'View-only — only developers can manage staff accounts.'
        }
        actions={
          canManage && (
            <button className="btn primary" onClick={() => setAdding(true)}>
              <UserPlus /> Invite staff
            </button>
          )
        }
      />

      <div className="filters-bar">
        <SearchBox value={query} onChange={setQuery} placeholder="Search name or email…" />
      </div>

      <Card key={version}>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Status</th>
                <th>Last Activity</th>
                {canManage && <th>Actions</th>}
              </tr>
            </thead>
            <tbody>
              {rows.map((s) => (
                <StaffRow key={s.id} s={s} canManage={canManage} onChange={() => setVersion((n) => n + 1)} />
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {adding && (
        <InviteModal
          onClose={() => setAdding(false)}
          onInvite={(name, email, newRole) => {
            staffUsers.unshift({
              id: `s${staffUsers.length + 1}`,
              name,
              email,
              role: newRole,
              status: 'invited',
              lastActiveAt: new Date(),
            })
            flash(`Invitation sent to ${name}`)
            setVersion((n) => n + 1)
            setAdding(false)
          }}
        />
      )}
    </>
  )
}

function StaffRow({
  s,
  canManage,
  onChange,
}: {
  s: StaffUser
  canManage: boolean
  onChange: () => void
}) {
  const tone =
    s.status === 'active' ? 'green' : s.status === 'invited' ? 'amber' : 'red'

  return (
    <tr>
      <td><span className="cell-main">{s.name}</span></td>
      <td>{s.email}</td>
      <td style={{ textTransform: 'capitalize', fontWeight: 600 }}>{s.role}</td>
      <td><Badge tone={tone}>{s.status}</Badge></td>
      <td>{timeAgo(s.lastActiveAt)}</td>
      {canManage && (
        <td>
          {s.status === 'invited' && (
            <button
              className="btn ghost xs"
              onClick={() => {
                s.status = 'active'
                flash(`${s.name} activated`)
                onChange()
              }}
            >
              Activate
            </button>
          )}
          {s.status !== 'disabled' ? (
            <button
              className="btn danger xs"
              style={{ marginLeft: 5 }}
              onClick={() => {
                s.status = 'disabled'
                flash(`${s.name}'s access disabled`)
                onChange()
              }}
            >
              Disable
            </button>
          ) : (
            <button
              className="btn ghost xs"
              style={{ marginLeft: 5 }}
              onClick={() => {
                s.status = 'active'
                flash(`${s.name} reinstated`)
                onChange()
              }}
            >
              Reinstate
            </button>
          )}
        </td>
      )}
    </tr>
  )
}

function InviteModal({
  onClose,
  onInvite,
}: {
  onClose: () => void
  onInvite: (name: string, email: string, role: Role) => void
}) {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [role, setRole] = useState<Role>('staff')

  const valid = name.trim().length > 1 && /.+@.+\..+/.test(email)

  return (
    <>
      <div className="drawer-overlay" onClick={onClose} />
      <aside className="drawer" style={{ width: 360 }}>
        <div className="drawer-head">
          <h3>Invite staff member</h3>
          <button className="icon-btn" style={{ marginLeft: 'auto' }} onClick={onClose}>
            ✕
          </button>
        </div>
        <div className="drawer-body">
          <div style={{ marginBottom: 12 }}>
            <label className="field-label">Full name</label>
            <input className="input" style={{ width: '100%' }} value={name} onChange={(e) => setName(e.target.value)} />
          </div>
          <div style={{ marginBottom: 12 }}>
            <label className="field-label">Work email</label>
            <input className="input" style={{ width: '100%' }} value={email} onChange={(e) => setEmail(e.target.value)} />
          </div>
          <div style={{ marginBottom: 18 }}>
            <label className="field-label">Role</label>
            <select className="select" style={{ width: '100%' }} value={role} onChange={(e) => setRole(e.target.value as Role)}>
              <option value="staff">Staff — monitoring only</option>
              <option value="manager">Manager — operations</option>
              <option value="developer">Developer — full access</option>
            </select>
          </div>
          <button
            className="btn primary"
            style={{ width: '100%' }}
            disabled={!valid}
            onClick={() => onInvite(name.trim(), email.trim(), role)}
          >
            Send invitation
          </button>
        </div>
      </aside>
    </>
  )
}
