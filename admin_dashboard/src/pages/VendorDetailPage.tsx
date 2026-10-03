import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { ArrowLeft, BadgeCheck, Ban, PlayCircle } from 'lucide-react'
import { api } from '../lib/api'
import { useAsyncData } from '../state/live'
import type { AdminVendorRow } from './vendorAdmin'
import { statusToneOf, vendorStatusOf, statusLabelOf } from './vendorAdmin'
import { can, useAuth } from '../state/auth'
import { flash } from '../lib/flash'
import { fmtDate, fmtDateTime, money, num } from '../lib/format'
import {
  Badge,
  Card,
  CardHead,
  EmptyState,
  initials,
  PageHeader,
  Stars,
} from '../components/ui/primitives'

interface AdminOrderRow {
  id: string
  order_number: string
  status: string
  delivery_method: string
  total: number
  created_at: string
}

interface AdminReviewRow {
  id: string
  vendor_id: string
  customer_name: string | null
  stars: number
  comment: string | null
  vendor_response: string | null
  vendor_responded: boolean
  created_at: string
}

export function VendorDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { user } = useAuth()
  const role = user?.role ?? 'staff'
  const [reload, setReload] = useState(0)

  const vendors =
    useAsyncData(async () => {
      void reload
      return api<AdminVendorRow[]>('/admin/vendors')
    }).data ?? []
  const vendor = id ? vendors.find((v) => v.id === id) : undefined

  const vOrders =
    useAsyncData(async () => {
      if (!id) return []
      return api<AdminOrderRow[]>('/admin/orders', { query: { vendor_id: id, limit: 8 } })
    }).data ?? []

  const vReviews = (
    useAsyncData(async () => {
      const all = await api<AdminReviewRow[]>('/admin/reviews')
      return all.filter((r) => r.vendor_id === id)
    }).data ?? []
  ).slice(0, 10)

  async function act(patch: Record<string, boolean>, message: string) {
    if (!vendor) return
    try {
      await api(`/admin/vendors/${vendor.id}`, { method: 'PATCH', body: patch })
      flash(message)
      setReload((n) => n + 1)
    } catch (e) {
      flash(e instanceof Error ? e.message : 'Action failed')
    }
  }

  if (!vendor) {
    return (
      <>
        <PageHeader title={vendors.length ? 'Vendor not found' : 'Loading…'} />
        <button className="btn ghost" onClick={() => navigate('/vendors')}>
          Back to vendors
        </button>
      </>
    )
  }

  const status = vendorStatusOf(vendor)
  const canAct = can(role, 'vendors.approve') || can(role, 'vendors.verify')

  return (
    <>
      <PageHeader
        title={vendor.store_name}
        description={`${vendor.address} · rating ${vendor.average_rating.toFixed(1)} (${vendor.total_reviews} reviews)`}
        actions={
          <>
            <Link to="/vendors" className="btn ghost">
              <ArrowLeft /> All vendors
            </Link>
            {can(role, 'vendors.verify') && !vendor.is_verified && (
              <button className="btn ghost" onClick={() => act({ is_verified: true }, `Verified ${vendor.store_name}`)}>
                <BadgeCheck /> Verify documents
              </button>
            )}
            {canAct && (
              vendor.is_paused ? (
                <button className="btn success" onClick={() => act({ is_paused: false }, `${vendor.store_name} resumed`)}>
                  <PlayCircle /> Resume
                </button>
              ) : (
                <button className="btn danger" onClick={() => act({ is_paused: true }, `Paused ${vendor.store_name}`)}>
                  <Ban /> Suspend
                </button>
              )
            )}
          </>
        }
      />

      <div className="grid-2">
        <Card>
          <CardHead title="Store Profile" />
          <div className="card-pad">
            <div className="row-flex" style={{ gap: 14 }}>
              <div
                className="mini-avatar"
                style={{ width: 52, height: 52, borderRadius: 12, fontSize: 17 }}
              >
                {initials(vendor.store_name)}
              </div>
              <div>
                <div className="cell-main" style={{ fontSize: 15 }}>
                  {vendor.store_name}
                </div>
                <div className="small muted" style={{ marginTop: 3 }}>{vendor.address}</div>
                <div style={{ marginTop: 6 }}><Stars rating={vendor.average_rating} /></div>
              </div>
            </div>

            <table className="tbl" style={{ marginTop: 14 }}>
              <tbody>
                <tr><td className="muted">Owner</td><td className="cell-main">{vendor.owner_name ?? '—'}</td></tr>
                <tr><td className="muted">Mobile</td><td>{vendor.owner_mobile ?? '—'}</td></tr>
                <tr><td className="muted">Email</td><td>{vendor.owner_email ?? '—'}</td></tr>
                <tr>
                  <td className="muted">Status</td>
                  <td><Badge tone={statusToneOf(status)}>{statusLabelOf(status)}</Badge></td>
                </tr>
                <tr>
                  <td className="muted">Verification</td>
                  <td>
                    {vendor.is_verified
                      ? <Badge tone="blue" dot={false}>Verified business</Badge>
                      : <span className="small muted">Not verified</span>}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </Card>

        <div>
          <Card>
            <CardHead title="Subscription" />
            <div className="card-pad">
              <div className="row-flex" style={{ justifyContent: 'space-between' }}>
                <div>
                  <div className="cell-main" style={{ fontSize: 15 }}>Free plan</div>
                  <div className="small muted" style={{ marginTop: 2 }}>
                    No billing tier data yet — all vendors report the free plan.
                  </div>
                </div>
                <Badge tone={statusToneOf(status === 'open' ? 'active' : status === 'paused' ? 'suspended' : 'closed')}>
                  {status === 'open' ? 'active' : status === 'paused' ? 'paused' : 'suspended'}
                </Badge>
              </div>
            </div>
          </Card>

          <div className="grid-kpi" style={{ marginTop: 14 }}>
            <div className="card kpi">
              <div className="label">Total Reviews</div>
              <div className="value">{num(vendor.total_reviews)}</div>
            </div>
            <div className="card kpi">
              <div className="label">Avg Rating</div>
              <div className="value">{vendor.average_rating.toFixed(1)}</div>
            </div>
            <div className="card kpi">
              <div className="label">Products</div>
              <div className="value">{vendor.menu_count}</div>
            </div>
            <div className="card kpi">
              <div className="label">Recent Orders</div>
              <div className="value">{vOrders.length}</div>
            </div>
          </div>
        </div>
      </div>

      <div className="grid-2" style={{ gridTemplateColumns: '3fr 2fr' }}>
        <Card>
          <CardHead title="Recent Orders" />
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th>Order</th>
                  <th>Placed</th>
                  <th>Method</th>
                  <th className="num">Total</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {vOrders.map((o) => (
                  <tr key={o.id}>
                    <td className="cell-main mono">{o.order_number}</td>
                    <td>{fmtDateTime(new Date(o.created_at))}</td>
                    <td style={{ textTransform: 'capitalize' }}>{o.delivery_method.replaceAll('_', ' ')}</td>
                    <td className="num">{money(o.total)}</td>
                    <td>
                      <Badge tone={statusToneOf(o.status)}>
                        {o.status.replaceAll('_', ' ')}
                      </Badge>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            {!vOrders.length && <EmptyState message="No orders yet — this store has no live sales." />}
          </div>
        </Card>

        <Card>
          <CardHead title={`Reviews (${vReviews.length})`} />
          <div>
            {vReviews.map((r) => (
              <div key={r.id} className="list-row" style={{ alignItems: 'flex-start' }}>
                <div style={{ flex: 1 }}>
                  <div className="row-flex" style={{ justifyContent: 'space-between' }}>
                    <span className="cell-main small">{r.customer_name ?? 'Customer'}</span>
                    <Stars rating={r.stars} />
                  </div>
                  <p className="small" style={{ marginTop: 4 }}>{r.comment}</p>
                  <div className="row-flex" style={{ marginTop: 5, gap: 8 }}>
                    <span className="cell-sub">{fmtDate(new Date(r.created_at))}</span>
                    {r.vendor_responded && <Badge tone="blue" dot={false}>Responded</Badge>}
                  </div>
                </div>
              </div>
            ))}
            {!vReviews.length && <EmptyState message="No reviews yet." />}
          </div>
        </Card>
      </div>
    </>
  )
}
