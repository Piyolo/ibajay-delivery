import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { ArrowLeft, BadgeCheck, Ban, Check, RotateCcw, X } from 'lucide-react'
import { getVendor, orders, reviews as allReviews } from '../data/mockDb'
import type { Vendor } from '../types'
import { statusToneOf } from './vendorAdmin'
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

// Prototype actions (mock data) — the list page performs the real
// verify/pause calls against /admin/vendors; this detail view still runs
// on prototype data until the vendor-detail API slice lands.
function approveVendor(v: Vendor) {
  v.status = 'approved'
  flash(`Approved ${v.storeName}`)
}
function rejectVendor(v: Vendor) {
  v.status = 'rejected'
  flash(`Rejected ${v.storeName}`)
}
function suspendVendor(v: Vendor) {
  v.status = 'suspended'
  flash(`Suspended ${v.storeName}`)
}
function reinstateVendor(v: Vendor) {
  v.status = 'approved'
  flash(`${v.storeName} reinstated`)
}
function verifyVendor(v: Vendor) {
  v.verification = 'verified'
  flash(`Verified ${v.storeName}`)
}
function planLabel(p: string): string {
  if (p === 'founding') return 'Founding Vendor'
  return p.charAt(0).toUpperCase() + p.slice(1)
}

export function VendorDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const { user } = useAuth()
  const role = user?.role ?? 'staff'
  const [, bump] = useState(0)

  const vendor = id ? getVendor(id) : undefined
  if (!vendor) {
    return (
      <>
        <PageHeader title="Vendor not found" />
        <button className="btn ghost" onClick={() => navigate('/vendors')}>
          Back to vendors
        </button>
      </>
    )
  }

  const vOrders = orders.filter((o) => o.vendorId === vendor.id).slice(0, 8)
  const vReviews = allReviews.filter((r) => r.vendorId === vendor.id)
  const canAct = can(role, 'vendors.approve')

  return (
    <>
      <PageHeader
        title={vendor.storeName}
        description={`Brgy. ${vendor.barangay}, Ibajay, Aklan · joined ${fmtDate(vendor.joinedAt)}`}
        actions={
          <>
            <Link to="/vendors" className="btn ghost">
              <ArrowLeft /> All vendors
            </Link>
            {canAct && vendor.status === 'pending' && (
              <>
                <button
                  className="btn success"
                  onClick={() => {
                    approveVendor(vendor)
                    bump((n) => n + 1)
                  }}
                >
                  <Check /> Approve application
                </button>
                <button
                  className="btn danger"
                  onClick={() => {
                    rejectVendor(vendor)
                    bump((n) => n + 1)
                  }}
                >
                  <X /> Reject
                </button>
              </>
            )}
            {canAct && vendor.status === 'approved' && vendor.verification === 'unverified' && (
              <button
                className="btn ghost"
                onClick={() => {
                  verifyVendor(vendor)
                  bump((n) => n + 1)
                }}
              >
                <BadgeCheck /> Verify documents
              </button>
            )}
            {canAct && vendor.status === 'approved' && (
              <button
                className="btn danger"
                onClick={() => {
                  suspendVendor(vendor)
                  bump((n) => n + 1)
                }}
              >
                <Ban /> Suspend
              </button>
            )}
            {canAct && vendor.status === 'suspended' && (
              <button
                className="btn ghost"
                onClick={() => {
                  reinstateVendor(vendor)
                  bump((n) => n + 1)
                }}
              >
                <RotateCcw /> Reinstate
              </button>
            )}
          </>
        }
      />

      {vendor.status === 'rejected' && vendor.rejectionReason && (
        <div className="card card-pad section-gap" style={{ borderLeft: '3px solid var(--c-danger)' }}>
          <strong style={{ fontSize: 12.5 }}>Application rejected — </strong>
          <span className="small muted">{vendor.rejectionReason}</span>
        </div>
      )}

      <div className="grid-2">
        <Card>
          <CardHead title="Store Profile" />
          <div className="card-pad">
            <div className="row-flex" style={{ gap: 14 }}>
              <div
                className="mini-avatar"
                style={{ width: 52, height: 52, borderRadius: 12, fontSize: 17 }}
              >
                {initials(vendor.storeName)}
              </div>
              <div>
                <div className="cell-main" style={{ fontSize: 15 }}>
                  {vendor.storeName} {vendor.pilot && <span className="chip pilot">Pilot</span>}
                </div>
                <div className="small muted" style={{ marginTop: 3 }}>{vendor.description}</div>
                <div style={{ marginTop: 6 }}><Stars rating={vendor.rating} /></div>
              </div>
            </div>

            <table className="tbl" style={{ marginTop: 14 }}>
              <tbody>
                <tr><td className="muted">Owner</td><td className="cell-main">{vendor.ownerName}</td></tr>
                <tr><td className="muted">Mobile</td><td>{vendor.mobile}</td></tr>
                <tr><td className="muted">Email</td><td>{vendor.email}</td></tr>
                <tr>
                  <td className="muted">Status</td>
                  <td><Badge tone={statusToneOf(vendor.status)}>{vendor.status}</Badge></td>
                </tr>
                <tr>
                  <td className="muted">Verification</td>
                  <td>
                    {vendor.verification === 'verified'
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
                  <div className="cell-main" style={{ fontSize: 15 }}>{planLabel(vendor.plan)}</div>
                  <div className="small muted" style={{ marginTop: 2 }}>
                    {vendor.plan === 'free'
                      ? '5 products · 2 categories · no analytics'
                      : 'Unlimited products & categories · analytics · featured placement'}
                  </div>
                </div>
                <Badge tone={statusToneOf(vendor.subState)}>{vendor.subState}</Badge>
              </div>
              {vendor.renewalDate && (
                <div className="small muted" style={{ marginTop: 10 }}>
                  Next renewal: {fmtDate(vendor.renewalDate)}
                </div>
              )}
            </div>
          </Card>

          <div className="grid-kpi" style={{ marginTop: 14 }}>
            <div className="card kpi">
              <div className="label">Total Orders</div>
              <div className="value">{num(vendor.ordersCount)}</div>
            </div>
            <div className="card kpi">
              <div className="label">Lifetime Revenue</div>
              <div className="value">{money(vendor.revenue)}</div>
            </div>
            <div className="card kpi">
              <div className="label">Products</div>
              <div className="value">{vendor.productCount}</div>
            </div>
            <div className="card kpi">
              <div className="label">Categories</div>
              <div className="value">{vendor.categoryCount}</div>
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
                    <td className="cell-main mono">{o.id}</td>
                    <td>{fmtDateTime(o.placedAt)}</td>
                    <td style={{ textTransform: 'capitalize' }}>{o.method}</td>
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
                    <span className="cell-main small">{r.customerName}</span>
                    <Stars rating={r.rating} />
                  </div>
                  <p className="small" style={{ marginTop: 4 }}>{r.comment}</p>
                  <div className="row-flex" style={{ marginTop: 5, gap: 8 }}>
                    <span className="cell-sub">{fmtDate(r.createdAt)}</span>
                    {r.responded && <Badge tone="blue" dot={false}>Responded</Badge>}
                    {r.flagged && <Badge tone="red" dot={false}>Flagged</Badge>}
                    {r.hidden && <Badge tone="gray" dot={false}>Hidden</Badge>}
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
