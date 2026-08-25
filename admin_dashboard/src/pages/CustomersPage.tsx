import { useMemo, useState } from 'react'
import { customers, orders } from '../data/mockDb'
import { fmtDate, money, num, timeAgo } from '../lib/format'
import {
  Card,
  EmptyState,
  initials,
  PAGE_SIZE,
  PageHeader,
  Pagination,
  SearchBox,
} from '../components/ui/primitives'
import { useLive } from '../state/live'

export function CustomersPage() {
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)
  const { tick } = useLive()

  // Recompute live per-customer stats whenever the simulated refresh fires.
  const liveStats = useMemo(() => {
    void tick
    const map = new Map<string, { count: number; spent: number; lastAt: Date }>()
    for (const o of orders) {
      if (o.status === 'cancelled') continue
      const cur = map.get(o.customerId) ?? { count: 0, spent: 0, lastAt: o.placedAt }
      cur.count += 1
      cur.spent += o.total
      if (o.placedAt > cur.lastAt) cur.lastAt = o.placedAt
      map.set(o.customerId, cur)
    }
    return map
  }, [tick])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    const rows = customers.map((c) => ({
      ...c,
      liveOrders: liveStats.get(c.id)?.count ?? c.ordersCount,
      liveSpent: liveStats.get(c.id)?.spent ?? c.totalSpent,
      lastOrder: liveStats.get(c.id)?.lastAt,
    }))
    if (!q) return rows.sort((a, b) => b.liveSpent - a.liveSpent)
    return rows.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        c.mobile.includes(q) ||
        c.barangay.toLowerCase().includes(q) ||
        c.email.toLowerCase().includes(q),
    )
  }, [query, liveStats])

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const safePage = Math.min(page, pageCount)
  const pageRows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE)

  return (
    <>
      <PageHeader
        title="Customers"
        description={`${num(customers.length)} registered customer accounts.`}
      />

      <div className="filters-bar">
        <SearchBox value={query} onChange={setQuery} placeholder="Search name, mobile or barangay…" />
        <div className="spacer" />
        <span className="small muted">{filtered.length} customers</span>
      </div>

      <Card>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Customer</th>
                <th>Mobile</th>
                <th>Barangay</th>
                <th className="num">Orders</th>
                <th className="num">Total Spent</th>
                <th>Last Order</th>
                <th>Joined</th>
              </tr>
            </thead>
            <tbody>
              {pageRows.map((c) => (
                <tr key={c.id}>
                  <td>
                    <div className="row-flex">
                      <div className="mini-avatar">{initials(c.name)}</div>
                      <div>
                        <div className="cell-main">{c.name}</div>
                        <div className="cell-sub">{c.email}</div>
                      </div>
                    </div>
                  </td>
                  <td>{c.mobile}</td>
                  <td>Brgy. {c.barangay}</td>
                  <td className="num">{num(c.liveOrders)}</td>
                  <td className="num">{money(c.liveSpent)}</td>
                  <td>{c.lastOrder ? timeAgo(c.lastOrder) : '—'}</td>
                  <td>{fmtDate(c.joinedAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!pageRows.length && <EmptyState message="No customers match the search." />}
        </div>
        <Pagination page={safePage} pageCount={pageCount} total={filtered.length} onPage={setPage} />
      </Card>
    </>
  )
}
