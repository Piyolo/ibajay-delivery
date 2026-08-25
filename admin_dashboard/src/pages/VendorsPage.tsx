import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { BadgeCheck, Ban, Check, Eye, RotateCcw, ShieldX, X } from 'lucide-react'
import { vendors } from '../data/mockDb'
import type { Vendor, VendorStatus } from '../types'
import { can, useAuth } from '../state/auth'
import { flash } from '../lib/flash'
import { fmtDate, money, num } from '../lib/format'
import {
  Badge,
  Card,
  EmptyState,
  initials,
  PAGE_SIZE,
  PageHeader,
  Pagination,
  SearchBox,
  Stars,
} from '../components/ui/primitives'

const STATUS_FILTERS: Array<{ v: VendorStatus | 'all'; label: string }> = [
  { v: 'all', label: 'All' },
  { v: 'pending', label: 'Pending approval' },
  { v: 'approved', label: 'Approved' },
  { v: 'suspended', label: 'Suspended' },
  { v: 'rejected', label: 'Rejected' },
]

export function approveVendor(v: Vendor) {
  v.status = 'approved'
  flash(`Approved ${v.storeName}`)
}

export function rejectVendor(v: Vendor) {
  v.status = 'rejected'
  v.rejectionReason = 'Rejected by admin review during prototype session.'
  flash(`Rejected ${v.storeName}`)
}

export function suspendVendor(v: Vendor) {
  v.status = 'suspended'
  flash(`Suspended ${v.storeName}`)
}

export function reinstateVendor(v: Vendor) {
  v.status = 'approved'
  flash(`${v.storeName} reinstated`)
}

export function verifyVendor(v: Vendor) {
  v.verification = 'verified'
  flash(`Verified ${v.storeName}`)
}

export function VendorsPage() {
  const { user } = useAuth()
  const role = user?.role ?? 'staff'
  const [query, setQuery] = useState('')
  const [statusF, setStatusF] = useState<VendorStatus | 'all'>('all')
  const [version, setVersion] = useState(0)

  const filtered = useMemo(() => {
    void version
    const q = query.trim().toLowerCase()
    return vendors.filter((v) => {
      if (statusF !== 'all' && v.status !== statusF) return false
      if (!q) return true
      return (
        v.storeName.toLowerCase().includes(q) ||
        v.ownerName.toLowerCase().includes(q) ||
        v.barangay.toLowerCase().includes(q)
      )
    })
  }, [query, statusF, version])

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const [page, setPage] = useState(1)
  const safePage = Math.min(page, pageCount)
  const rows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE)

  return (
    <>
      <PageHeader
        title="Vendor Management"
        description="Review applications, manage active stores and monitor vendor performance."
      />

      <div className="filters-bar">
        <SearchBox value={query} onChange={setQuery} placeholder="Search store, owner or barangay…" />
        <select
          className="select"
          value={statusF}
          onChange={(e) => setStatusF(e.target.value as VendorStatus | 'all')}
        >
          {STATUS_FILTERS.map((f) => (
            <option key={f.v} value={f.v}>
              {f.label}
            </option>
          ))}
        </select>
        <div className="spacer" />
        <span className="small muted">
          {filtered.length} of {vendors.length} vendors
        </span>
      </div>

      <Card>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Store</th>
                <th>Owner</th>
                <th>Status</th>
                <th>Subscription</th>
                <th>Verification</th>
                <th className="num">Orders</th>
                <th className="num">Revenue</th>
                <th>Date Joined</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((v) => (
                <VendorRow key={v.id} v={v} role={role} onChange={() => setVersion((n) => n + 1)} />
              ))}
            </tbody>
          </table>
          {!rows.length && <EmptyState message="No vendors match the current filters." />}
        </div>
        <Pagination page={safePage} pageCount={pageCount} total={filtered.length} onPage={setPage} />
      </Card>
    </>
  )
}

function VendorRow({
  v,
  role,
  onChange,
}: {
  v: Vendor
  role: string
  onChange: () => void
}) {
  const act = (fn: (v: Vendor) => void) => () => {
    fn(v)
    onChange()
  }

  return (
    <tr>
      <td>
        <Link to={`/vendors/${v.id}`} className="row-flex">
          <div className="mini-avatar">{initials(v.storeName)}</div>
          <div>
            <div className="cell-main">
              {v.storeName} {v.pilot && <span className="chip pilot">Pilot</span>}
            </div>
            <div className="cell-sub">Brgy. {v.barangay}</div>
          </div>
        </Link>
      </td>
      <td>{v.ownerName}</td>
      <td>
        <Badge tone={statusToneOf(v.status)}>{v.status}</Badge>
      </td>
      <td>
        <Badge tone={planTone(v.plan)} dot={false}>{planLabel(v.plan)}</Badge>
        {v.subState !== 'active' && (
          <div style={{ marginTop: 3 }}>
            <Badge tone={statusToneOf(v.subState)}>{v.subState}</Badge>
          </div>
        )}
      </td>
      <td>
        {v.verification === 'verified' ? (
          <Badge tone="blue" dot={false}>Verified</Badge>
        ) : (
          <span className="small muted">—</span>
        )}
      </td>
      <td className="num">{num(v.ordersCount)}</td>
      <td className="num">{money(v.revenue)}</td>
      <td>{fmtDate(v.joinedAt)}</td>
      <td>
        <div style={{ display: 'flex', gap: 5 }}>
          <Link to={`/vendors/${v.id}`} className="btn ghost xs" title="View details">
            <Eye /> View
          </Link>
          {can(role as never, 'vendors.approve') && v.status === 'pending' && (
            <>
              <button className="btn success xs" onClick={act(approveVendor)}>
                <Check /> Approve
              </button>
              <button className="btn danger xs" onClick={act(rejectVendor)}>
                <X /> Reject
              </button>
            </>
          )}
          {can(role as never, 'vendors.approve') && v.status === 'approved' && (
            <>
              {v.verification === 'unverified' && (
                <button className="btn ghost xs" onClick={act(verifyVendor)} title="Verify business documents">
                  <BadgeCheck /> Verify
                </button>
              )}
              <button className="btn danger xs" onClick={act(suspendVendor)} title="Suspend store">
                <Ban /> Suspend
              </button>
            </>
          )}
          {can(role as never, 'vendors.approve') && v.status === 'suspended' && (
            <button className="btn ghost xs" onClick={act(reinstateVendor)}>
              <RotateCcw /> Reinstate
            </button>
          )}
          {can(role as never, 'vendors.approve') && v.status === 'suspended' && (
            <button
              className="btn danger xs"
              onClick={() => flash('Permanently removing vendors is disabled in the prototype — data is preserved by policy.')}
              title="Data is never deleted per platform policy"
            >
              <ShieldX /> Remove
            </button>
          )}
        </div>
      </td>
    </tr>
  )
}

export function statusToneOf(s: string): 'green' | 'amber' | 'red' | 'gray' | 'blue' {
  switch (s) {
    case 'approved':
    case 'active':
      return 'green'
    case 'pending':
    case 'grace':
      return 'amber'
    case 'rejected':
    case 'suspended':
    case 'expired':
      return 'red'
    default:
      return 'gray'
  }
}

export function planLabel(p: string): string {
  if (p === 'founding') return 'Founding Vendor'
  return p.charAt(0).toUpperCase() + p.slice(1)
}

function planTone(p: string): 'purple' | 'orange' | 'gray' {
  if (p === 'founding') return 'orange'
  if (p === 'plus') return 'purple'
  return 'gray'
}
