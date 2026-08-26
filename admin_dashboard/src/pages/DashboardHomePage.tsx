import { Link } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import { api } from '../lib/api'
import { fmtDateTime, money, num } from '../lib/format'
import { Badge, Card, CardHead, EmptyState, initials, KpiCard, statusLabel, statusTone } from '../components/ui/primitives'
import { OrdersBarChart, RevenueAreaChart } from '../components/charts/charts'
import { useAsyncData } from '../state/live'

interface Overview {
  vendors_total: number
  vendors_open: number
  vendors_verified: number
  customers_total: number
  orders_today: number
  orders_this_week: number
  orders_active: number
  revenue_today: number
  revenue_week: number
  week: Array<{ date: string; revenue: number; orders: number }>
}

interface AdminOrderRow {
  id: string
  order_number: string
  status: string
  total: number
  created_at: string
  customer_name: string | null
  vendor_name: string | null
}

interface AdminVendorRow {
  id: string
  store_name: string
  logo_url: string | null
  is_open: boolean
  is_verified: boolean
  average_rating: number
  menu_count: number
}

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']

export function DashboardHomePage() {
  const overview = useAsyncData(async () => {
    await new Promise((r) => setTimeout(r, 0))
    return api<Overview>('/admin/overview')
  }).data

  const orders = useAsyncData(() => api<AdminOrderRow[]>('/admin/orders', { query: { limit: 8 } })).data ?? []
  const vendors = useAsyncData(() => api<AdminVendorRow[]>('/admin/vendors')).data ?? []

  const series = (overview?.week ?? []).map((d) => ({
    label: DAYS[new Date(`${d.date}T00:00:00`).getDay()],
    revenue: d.revenue,
    orders: d.orders,
  }))
  const top = [...vendors].sort((a, b) => b.average_rating - a.average_rating).slice(0, 5)

  return (
    <>
      <div className="grid-kpi">
        <KpiCard label="Orders Today" value={num(overview?.orders_today ?? 0)} />
        <KpiCard label="Revenue Today" value={money(overview?.revenue_today ?? 0)} />
        <KpiCard label="Orders This Week" value={num(overview?.orders_this_week ?? 0)} />
        <KpiCard label="Live Orders" value={num(overview?.orders_active ?? 0)} />
        <KpiCard label="Open Vendors" value={`${overview?.vendors_open ?? 0}/${overview?.vendors_total ?? 0}`} />
        <KpiCard label="Customers" value={num(overview?.customers_total ?? 0)} />
      </div>

      <div className="grid-2">
        <Card>
          <CardHead title="Revenue — last 7 days" />
          <div className="card-pad">
            {series.length ? (
              <RevenueAreaChart data={series} />
            ) : (
              <EmptyState message="No sales recorded yet." />
            )}
          </div>
        </Card>
        <Card>
          <CardHead title="Orders — last 7 days" />
          <div className="card-pad">
            {series.length ? (
              <OrdersBarChart data={series} />
            ) : (
              <EmptyState message="No orders yet." />
            )}
          </div>
        </Card>
      </div>

      <div className="grid-3">
        <Card>
          <CardHead
            title="Recent Orders"
            action={
              <Link to="/orders" className="link">
                View all <ArrowRight size={12} style={{ verticalAlign: -2 }} />
              </Link>
            }
          />
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th>Order</th>
                  <th>Customer</th>
                  <th>Total</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {orders.map((o) => (
                  <tr key={o.id}>
                    <td>
                      <div className="cell-main mono">{o.order_number}</div>
                      <div className="cell-sub">{fmtDateTime(new Date(o.created_at))}</div>
                    </td>
                    <td>{o.customer_name ?? '—'}</td>
                    <td className="num">{money(o.total)}</td>
                    <td>
                      <Badge tone={statusTone(o.status as never)}>{statusLabel(o.status as never)}</Badge>
                    </td>
                  </tr>
                ))}
                {!orders.length && (
                  <tr>
                    <td colSpan={4}><EmptyState message="No orders yet." /></td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </Card>

        <Card>
          <CardHead title="Stores" action={<Link to="/vendors" className="link">Manage</Link>} />
          <div>
            {top.map((v) => (
              <Link to={`/vendors/${v.id}`} key={v.id} className="list-row" style={{ display: 'block' }}>
                <div className="row-flex" style={{ justifyContent: 'space-between' }}>
                  <div className="row-flex">
                    <div className="mini-avatar">{initials(v.store_name)}</div>
                    <div>
                      <div className="cell-main" style={{ fontSize: 12.5 }}>
                        {v.store_name} {!v.is_open && <span className="chip pilot">Closed</span>}
                      </div>
                      <div className="cell-sub">
                        ★ {v.average_rating.toFixed(1)} · {num(v.menu_count)} items
                      </div>
                    </div>
                  </div>
                  {v.is_verified && <Badge tone="blue" dot={false}>Verified</Badge>}
                </div>
              </Link>
            ))}
            {!top.length && <EmptyState message="No stores registered yet." />}
          </div>
        </Card>

        <Card>
          <CardHead title="Platform Snapshot" />
          <div>
            <SnapshotRow label="Revenue this week" value={money(overview?.revenue_week ?? 0)} />
            <SnapshotRow label="Verified stores" value={`${overview?.vendors_verified ?? 0} of ${overview?.vendors_total ?? 0}`} />
            <SnapshotRow label="Registered customers" value={num(overview?.customers_total ?? 0)} />
            <SnapshotRow label="Live orders right now" value={num(overview?.orders_active ?? 0)} />
          </div>
        </Card>
      </div>
    </>
  )
}

function SnapshotRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="list-row">
      <span className="cell-sub">{label}</span>
      <span className="cell-main mono" style={{ marginLeft: 'auto' }}>{value}</span>
    </div>
  )
}
