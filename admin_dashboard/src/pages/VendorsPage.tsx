import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { BadgeCheck, Ban, PlayCircle, RefreshCw } from 'lucide-react'
import { api } from '../lib/api'
import type { AdminVendorRow } from './vendorAdmin'
import { statusLabelOf, statusToneOf, vendorStatusOf } from './vendorAdmin'
import { can, useAuth } from '../state/auth'
import { useLive } from '../state/live'
import { flash } from '../lib/flash'
import {
  Badge,
  Card,
  EmptyState,
  initials,
  PAGE_SIZE,
  PageHeader,
  Pagination,
  SearchBox,
} from '../components/ui/primitives'

type StatusFilter = 'all' | 'open' | 'paused' | 'closed' | 'unverified'

const STATUS_FILTERS: Array<{ v: StatusFilter; label: string }> = [
  { v: 'all', label: 'All' },
  { v: 'open', label: 'Open' },
  { v: 'paused', label: 'Paused' },
  { v: 'unverified', label: 'Unverified' },
]

export function VendorsPage() {
  const { user } = useAuth()
  const role = user?.role ?? 'staff'
  const [query, setQuery] = useState('')
  const [statusF, setStatusF] = useState<StatusFilter>('all')
  const [reloadKey, setReloadKey] = useState(0)
  const [vendors, setVendors] = useState<AdminVendorRow[]>([])
  const [loading, setLoading] = useState(true)
  const [busyId, setBusyId] = useState<string | null>(null)
  const { tick } = useLive()

  const load = useCallback(() => {
    api<AdminVendorRow[]>('/admin/vendors')
      .then(setVendors)
      .catch(() => setVendors([]))
      .finally(() => setLoading(false))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(load, [load, tick, reloadKey])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return vendors.filter((v) => {
      if (statusF === 'open' && !(v.is_open && !v.is_paused)) return false
      if (statusF === 'paused' && !v.is_paused) return false
      if (statusF === 'closed' && (v.is_open || v.is_paused)) return false
      if (statusF === 'unverified' && v.is_verified) return false
      if (!q) return true
      return (
        v.store_name.toLowerCase().includes(q) ||
        (v.owner_name?.toLowerCase().includes(q) ?? false) ||
        v.address.toLowerCase().includes(q)
      )
    })
  }, [vendors, query, statusF])

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const [page, setPage] = useState(1)
  const safePage = Math.min(page, pageCount)
  const rows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE)

  async function act(v: AdminVendorRow, patch: Record<string, boolean>, message: string) {
    setBusyId(v.id)
    try {
      await api(`/admin/vendors/${v.id}`, { method: 'PATCH', body: patch })
      flash(message)
      setReloadKey((n) => n + 1)
    } catch (e) {
      flash(e instanceof Error ? e.message : 'Action failed')
    } finally {
      setBusyId(null)
    }
  }

  return (
    <>
      <PageHeader
        title="Vendor Management"
        description="Monitor active stores, verify businesses, pause or resume listings."
        actions={
          <button className="btn ghost" onClick={() => setReloadKey((n) => n + 1)}>
            <RefreshCw /> Refresh
          </button>
        }
      />

      <div className="filters-bar">
        <SearchBox value={query} onChange={setQuery} placeholder="Search store, owner or address…" />
        <select
          className="select"
          value={statusF}
          onChange={(e) => setStatusF(e.target.value as StatusFilter)}
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
                <th>Verification</th>
                <th className="num">Rating</th>
                <th className="num">Menu Items</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((v) => {
                const status = vendorStatusOf(v)
                return (
                  <tr key={v.id}>
                    <td>
                      <Link to={`/vendors/${v.id}`} className="row-flex">
                        <div className="mini-avatar">{initials(v.store_name)}</div>
                        <div>
                          <div className="cell-main">{v.store_name}</div>
                          <div className="cell-sub">{v.address}</div>
                        </div>
                      </Link>
                    </td>
                    <td>
                      {v.owner_name ?? '—'}
                      <div className="cell-sub">{v.owner_mobile ?? ''}</div>
                    </td>
                    <td>
                      <Badge tone={statusToneOf(status)}>{statusLabelOf(status)}</Badge>
                    </td>
                    <td>
                      {v.is_verified ? (
                        <Badge tone="blue" dot={false}>Verified</Badge>
                      ) : (
                        <span className="small muted">—</span>
                      )}
                    </td>
                    <td className="num">★ {v.average_rating.toFixed(1)}</td>
                    <td className="num">{v.menu_count}</td>
                    <td>
                      <div style={{ display: 'flex', gap: 5 }}>
                        <Link to={`/vendors/${v.id}`} className="btn ghost xs" title="View details">
                          View
                        </Link>
                        {can(role as never, 'vendors.verify') && !v.is_verified && (
                          <button
                            className="btn ghost xs"
                            disabled={busyId === v.id}
                            onClick={() => act(v, { is_verified: true }, `Verified ${v.store_name}`)}
                            title="Verify business documents"
                          >
                            <BadgeCheck /> Verify
                          </button>
                        )}
                        {can(role as never, 'vendors.approve') &&
                          (v.is_paused ? (
                            <button
                              className="btn success xs"
                              disabled={busyId === v.id}
                              onClick={() => act(v, { is_paused: false }, `${v.store_name} resumed`)}
                            >
                              <PlayCircle /> Resume
                            </button>
                          ) : (
                            <button
                              className="btn danger xs"
                              disabled={busyId === v.id}
                              onClick={() => act(v, { is_paused: true }, `Paused ${v.store_name}`)}
                              title="Temporarily hide this store from customers"
                            >
                              <Ban /> Pause
                            </button>
                          ))}
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
          {!rows.length && (
            <EmptyState
              message={
                loading
                  ? 'Loading vendors…'
                  : vendors.length
                    ? 'No vendors match the current filters.'
                    : 'No stores registered yet.'
              }
            />
          )}
        </div>
        <Pagination page={safePage} pageCount={pageCount} total={filtered.length} onPage={setPage} />
      </Card>
    </>
  )
}
