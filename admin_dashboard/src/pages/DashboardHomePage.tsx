import { Link } from 'react-router-dom'
import { ArrowRight } from 'lucide-react'
import {
  bestSellers,
  customerById,
  getVendor,
  kpis,
  orders,
  revenueSeries,
  topVendors,
} from '../data/mockDb'
import { fmtDateTime, money, num, pct } from '../lib/format'
import { Badge, Card, CardHead, EmptyState, initials, KpiCard, statusLabel, statusTone } from '../components/ui/primitives'
import { OrdersBarChart, RevenueAreaChart } from '../components/charts/charts'
import { useAsyncData } from '../state/live'

export function DashboardHomePage() {
  const k = useAsyncData(() => kpis()).data ?? kpis()
  const series = useAsyncData(() => revenueSeries(14)).data ?? []
  const recent = orders.slice(0, 8)
  const top = topVendors(5)
  const products = bestSellers(5)
  const maxRevenue = top[0]?.revenue ?? 1

  return (
    <>
      <div className="grid-kpi">
        <KpiCard label="Orders Today" value={num(k.todayOrders)} delta={k.todayOrdersDelta} />
        <KpiCard label="Revenue Today" value={money(k.todayRevenue)} delta={k.todayRevenueDelta} />
        <KpiCard label="Active Vendors" value={k.activeVendors} />
        <KpiCard label="Verified Vendors" value={`${k.verifiedVendors}/${k.activeVendors}`} />
        <KpiCard label="Active Customers" value={num(k.activeCustomers)} />
        <KpiCard label="Pending Approvals" value={k.pendingApprovals} deltaGoodDirection="down" />
      </div>

      <div className="grid-2">
        <Card>
          <CardHead title="Revenue — last 14 days" />
          <div className="card-pad">
            <RevenueAreaChart data={series} />
          </div>
        </Card>
        <Card>
          <CardHead title="Orders — last 14 days" />
          <div className="card-pad">
            <OrdersBarChart data={series} />
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
                {recent.map((o) => {
                  const c = customerById(o.customerId)
                  return (
                    <tr key={o.id}>
                      <td>
                        <div className="cell-main mono">{o.id}</div>
                        <div className="cell-sub">{fmtDateTime(o.placedAt)}</div>
                      </td>
                      <td>{c?.name}</td>
                      <td className="num">{money(o.total)}</td>
                      <td>
                        <Badge tone={statusTone(o.status)}>{statusLabel(o.status)}</Badge>
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
        </Card>

        <Card>
          <CardHead title="Top Vendors" action={<Link to="/analytics/vendors" className="link">Details</Link>} />
          <div>
            {top.map((v) => (
              <Link to={`/vendors/${v.id}`} key={v.id} className="list-row" style={{ display: 'block' }}>
                <div className="row-flex" style={{ justifyContent: 'space-between' }}>
                  <div className="row-flex">
                    <div className="mini-avatar">{initials(v.storeName)}</div>
                    <div>
                      <div className="cell-main" style={{ fontSize: 12.5 }}>
                        {v.storeName} {v.pilot && <span className="chip pilot">Pilot</span>}
                      </div>
                      <div className="cell-sub">{num(v.ordersCount)} orders</div>
                    </div>
                  </div>
                  <div className="cell-main mono" style={{ fontSize: 12.5 }}>{money(v.revenue)}</div>
                </div>
                <div className="progress-track" style={{ marginTop: 7 }}>
                  <div
                    className="progress-fill"
                    style={{ width: `${Math.max(6, (v.revenue / maxRevenue) * 100)}%` }}
                  />
                </div>
              </Link>
            ))}
          </div>
        </Card>

        <Card>
          <CardHead title="Best Sellers" />
          <div>
            {products.length === 0 && <EmptyState message="No sales yet." />}
            {products.map((p) => (
              <div key={`${p.vendorId}-${p.name}`} className="list-row">
                <div>
                  <div className="cell-main" style={{ fontSize: 12.5 }}>{p.name}</div>
                  <div className="cell-sub">{p.vendorName} · {num(p.unitsSold)} sold</div>
                </div>
                <div style={{ marginLeft: 'auto' }} className="mono small">
                  {money(p.revenue)}
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </>
  )
}

export function DeltaInline({ v }: { v: number }) {
  const cls = v > 0 ? 'up' : v < 0 ? 'down' : 'flat'
  return <span className={`delta ${cls}`}>{pct(v)}</span>
}
