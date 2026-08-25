import { useMemo, useState } from 'react'
import { EyeOff, Info, RotateCcw } from 'lucide-react'
import { getVendor, reviews as allReviews } from '../data/mockDb'
import { can, useAuth } from '../state/auth'
import { flash } from '../lib/flash'
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

export function ReviewsPage() {
  const { user } = useAuth()
  // Staff may hide flagged reviews only; managers/developers moderate freely.
  const fullModerator = can(user?.role ?? 'staff', 'reviews.moderate')
  const [query, setQuery] = useState('')
  const [ratingF, setRatingF] = useState('all')
  const [flaggedOnly, setFlaggedOnly] = useState(false)
  const [page, setPage] = useState(1)
  const [version, setVersion] = useState(0)

  const filtered = useMemo(() => {
    void version
    const q = query.trim().toLowerCase()
    return allReviews.filter((r) => {
      if (flaggedOnly && !r.flagged) return false
      if (ratingF !== 'all' && r.rating !== Number(ratingF)) return false
      if (!q) return true
      return (
        (getVendor(r.vendorId)?.storeName.toLowerCase().includes(q) ?? false) ||
        r.customerName.toLowerCase().includes(q) ||
        r.comment.toLowerCase().includes(q)
      )
    })
  }, [query, ratingF, flaggedOnly, version])

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const safePage = Math.min(page, pageCount)
  const rows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE)

  return (
    <>
      <PageHeader
        title="Reviews"
        description={
          fullModerator
            ? 'Moderate customer reviews. Flagged entries surface spam and abuse.'
            : 'Monitoring view — flagged reviews can be hidden; other moderation is restricted.'
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
        <label className="row-flex small" style={{ gap: 6, cursor: 'pointer' }}>
          <input type="checkbox" checked={flaggedOnly} onChange={(e) => setFlaggedOnly(e.target.checked)} />
          Flagged only
        </label>
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
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => {
                const vendor = getVendor(r.vendorId)
                const staffBlocked = !fullModerator && !r.flagged
                return (
                  <tr key={r.id}>
                    <td><span className="cell-main">{vendor?.storeName ?? r.vendorId}</span></td>
                    <td>{r.customerName}</td>
                    <td><Stars rating={r.rating} /></td>
                    <td style={{ whiteSpace: 'normal', minWidth: 220 }}>
                      {r.hidden ? <s className="muted">{r.comment}</s> : r.comment}
                    </td>
                    <td title={fmtDate(r.createdAt)}>{fmtDate(r.createdAt)}</td>
                    <td>
                      <div className="row-flex" style={{ gap: 5, flexWrap: 'wrap' }}>
                        {r.flagged && <Badge tone="red">Flagged</Badge>}
                        {r.responded && <Badge tone="blue" dot={false}>Responded</Badge>}
                        {r.hidden && <Badge tone="gray">Hidden</Badge>}
                      </div>
                    </td>
                    <td>
                      {r.hidden ? (
                        <button
                          className="btn ghost xs"
                          disabled={staffBlocked}
                          title={staffBlocked ? 'Restricted for staff — flagged reviews only' : ''}
                          onClick={() => {
                            r.hidden = false
                            flash('Review restored')
                            setVersion((n) => n + 1)
                          }}
                        >
                          <RotateCcw /> Restore
                        </button>
                      ) : (
                        <button
                          className="btn danger xs"
                          disabled={staffBlocked}
                          title={staffBlocked ? 'Restricted for staff — flagged reviews only' : ''}
                          onClick={() => {
                            r.hidden = true
                            flash('Review hidden from the store page')
                            setVersion((n) => n + 1)
                          }}
                        >
                          <EyeOff /> Hide
                        </button>
                      )}
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
          {!rows.length && <EmptyState message="No reviews match the filters." />}
        </div>
        <Pagination page={safePage} pageCount={pageCount} total={filtered.length} onPage={setPage} />
      </Card>

      <p className="small muted" style={{ marginTop: 10 }}>
        <Info size={12} style={{ verticalAlign: -2 }} /> Auto-flagging catches spam patterns; vendor responses come through the vendor app.
      </p>
    </>
  )
}
