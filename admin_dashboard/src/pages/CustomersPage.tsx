import { useCallback, useEffect, useMemo, useState } from 'react'
import { api } from '../lib/api'
import { fmtDate, num } from '../lib/format'
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

interface AdminCustomer {
  id: string
  full_name: string
  email: string
  mobile_number: string
  is_active: boolean
  created_at: string
  order_count: number
}

export function CustomersPage() {
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)
  const [customers, setCustomers] = useState<AdminCustomer[]>([])
  const [loading, setLoading] = useState(true)
  const { tick } = useLive()

  const load = useCallback(() => {
    api<AdminCustomer[]>('/admin/customers')
      .then(setCustomers)
      .catch(() => setCustomers([]))
      .finally(() => setLoading(false))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(load, [load, tick])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    if (!q) return customers
    return customers.filter(
      (c) =>
        c.full_name.toLowerCase().includes(q) ||
        c.mobile_number.includes(q) ||
        c.email.toLowerCase().includes(q),
    )
  }, [customers, query])

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const safePage = Math.min(page, pageCount)
  const pageRows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE)

  return (
    <>
      <PageHeader
        title="Customers"
        description={`${num(customers.length)} registered customer account${customers.length === 1 ? '' : 's'}.`}
      />

      <div className="filters-bar">
        <SearchBox value={query} onChange={setQuery} placeholder="Search name, mobile or email…" />
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
                <th>Email</th>
                <th className="num">Orders</th>
                <th>Joined</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {pageRows.map((c) => (
                <tr key={c.id}>
                  <td>
                    <div className="row-flex">
                      <div className="mini-avatar">{initials(c.full_name)}</div>
                      <div className="cell-main">{c.full_name}</div>
                    </div>
                  </td>
                  <td>{c.mobile_number}</td>
                  <td>{c.email}</td>
                  <td className="num">{num(c.order_count)}</td>
                  <td>{fmtDate(new Date(c.created_at))}</td>
                  <td>
                    <span className={`chip ${c.is_active ? 'active' : ''}`}>
                      {c.is_active ? 'Active' : 'Disabled'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!pageRows.length && (
            <EmptyState message={loading ? 'Loading customers…' : 'No customers match the current search.'} />
          )}
        </div>
        <Pagination page={safePage} pageCount={pageCount} total={filtered.length} onPage={setPage} />
      </Card>
    </>
  )
}
