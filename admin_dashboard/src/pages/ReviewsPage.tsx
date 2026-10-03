import { useMemo, useState } from 'react'
import { Info } from 'lucide-react'
import { api } from '../lib/api'
import { useAsyncData } from '../state/live'
import { can, useAuth } from '../state/auth'
import { fmtDate } from '../lib/format'
import {
  Badge,
  Card,
  EmptyState,
  PAGE_SIZE,
  PageHeader,
  Pagination,
  SearchBox,
  Stars,
} from '../components/ui/primitives'

interface AdminReviewRow {
  id: string
  vendor_id: string
  vendor_name: string | null
  customer_name: string | null
  stars: number
  comment: string | null
  vendor_response: string | null
  vendor_responded: boolean
  created_at: string
}

export function ReviewsPage() {
  const { user } = useAuth()
  const fullModerator = can(user?.role ?? 'staff', 'reviews.moderate')
  const [query, setQuery] = useState('')
  const [ratingF, setRatingF] = useState('all')
  const [page, setPage] = useState(1)

  const allReviews = useAsyncData(() => api<AdminReviewRow[]>('/admin/reviews')).data ?? []

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return allReviews.filter((r) => {
      if (ratingF !== 'all' && r.stars !== Number(ratingF)) return false
      if (!q) return true
      return (
        (r.vendor_name?.toLowerCase().includes(q) ?? false) ||
        (r.customer_name?.toLowerCase().includes(q) ?? false) ||
        (r.comment?.toLowerCase().includes(q) ?? false)
      )
    })
  }, [allReviews, query, ratingF])

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const safePage = Math.min(page, pageCount)
  const rows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE)

  return (
    <>
      <PageHeader
        title="Reviews"
        description={
          fullModerator
            ? 'Customer reviews across the platform, newest first.'
            : 'Monitoring view of customer reviews.'
        }
      />

      <div className="filters-bar">
        <SearchBox value={query} onChange={setQuery} placeholder="Search store, customer or comment…" />
        <select className="select" value={ratingF} onChange={(e) => setRatingF(e.target.value)}>
          <option value="all">All ratings</option>
          {[5, 4, 3, 2, 1].map((r) => (
            <option key={r} value={r}>{r} stars</option>
          ))}
        </select>
        <div className="spacer" />
        <span className="small muted">{filtered.length} reviews</span>
      </div>

      <Card key={`${safePage}`}>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Store</th>
                <th>Customer</th>
                <th>Rating</th>
                <th>Comment</th>
                <th>Posted</th>
                <th>State</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td><span className="cell-main">{r.vendor_name ?? '—'}</span></td>
                  <td>{r.customer_name ?? '—'}</td>
                  <td><Stars rating={r.stars} /></td>
                  <td style={{ whiteSpace: 'normal', minWidth: 220 }}>{r.comment ?? ''}</td>
                  <td title={fmtDate(r.created_at)}>{fmtDate(r.created_at)}</td>
                  <td>
                    <div className="row-flex" style={{ gap: 5, flexWrap: 'wrap' }}>
                      {r.vendor_responded
                        ? <Badge tone="blue" dot={false}>Responded</Badge>
                        : <Badge tone="gray" dot={false}>Awaiting reply</Badge>}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!rows.length && <EmptyState message="No reviews match the filters." />}
        </div>
        <Pagination page={safePage} pageCount={pageCount} total={filtered.length} onPage={setPage} />
      </Card>

      <p className="small muted" style={{ marginTop: 10 }}>
        <Info size={12} style={{ verticalAlign: -2 }} /> Vendor responses come through the vendor app.
        Moderation actions (hide/flag) are not persisted by the backend yet, so this view is read-only.
      </p>
    </>
  )
}
