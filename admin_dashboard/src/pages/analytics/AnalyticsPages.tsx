import { Link } from 'react-router-dom'
import { api } from '../../lib/api'
import { money, num } from '../../lib/format'
import {
  Card,
  CardHead,
  initials,
  KpiCard,
  PageHeader,
} from '../../components/ui/primitives'
import { GrowthLineChart, RevenueAreaChart } from '../../components/charts/charts'
import { useAsyncData } from '../../state/live'
import type { AdminVendorRow } from '../vendorAdmin'
import {
  bestSellers,
  monthlySeries,
  revenueSeries,
  topVendorsByRevenue,
  type AdminOrderRow,
} from './series'

type VendorRow = AdminVendorRow & { created_at?: string | null }

export function AnalyticsOverviewPage() {
  const orders = useAsyncData(() => api<AdminOrderRow[]>('/admin/orders', { query: { limit: 500 } })).data ?? []
  const vendors = useAsyncData(() => api<VendorRow[]>('/admin/vendors')).data ?? []

  const series = revenueSeries(orders, 14)
  const totalRevenue = series.reduce((s, d) => s + d.revenue, 0)
  const totalOrders = series.reduce((s, d) => s + d.orders, 0)

  const open = vendors.filter((v) => v.is_open && !v.is_paused)
  const paused = vendors.filter((v) => v.is_paused)
  const closed = vendors.filter((v) => !v.is_open && !v.is_paused)

  return (
    <>
      <PageHeader
        title="Analytics Overview"
        description="Platform health across sales, vendors and customers."
      />

      <div className="grid-kpi">
        <KpiCard label="Revenue (14d)" value={money(totalRevenue)} />
        <KpiCard label="Orders (14d)" value={num(totalOrders)} />
        <KpiCard label="Open Vendors" value={open.length} />
        <KpiCard label="Unverified Stores" value={vendors.filter((v) => !v.is_verified).length} deltaGoodDirection="down" />
      </div>

      <Card>
        <CardHead title="Platform revenue — last 14 days" />
        <div className="card-pad"><RevenueAreaChart data={series} height={260} /></div>
      </Card>

      <div className="grid-2" style={{ marginTop: 14 }}>
        <Card>
          <CardHead title="Vendor funnel" />
          <div className="card-pad">
            <FunnelRow label="Open & live" value={open.length} total={vendors.length} color="#2e9e5b" />
            <FunnelRow label="Paused" value={paused.length} total={vendors.length} color="#de9e20" />
            <FunnelRow label="Closed" value={closed.length} total={vendors.length} color="#d64545" />
            <FunnelRow
              label="Verified businesses"
              value={vendors.filter((v) => v.is_verified).length}
              total={vendors.length}
              color="#3378c9"
            />
          </div>
        </Card>

        <Card>
          <CardHead title="Top products by units sold" action={<Link to="/analytics/sales" className="link">Sales</Link>} />
          <div>
            {bestSellers(orders, 6).map((p) => (
              <div key={p.name} className="list-row">
                <div>
                  <div className="cell-main small">{p.name}</div>
                </div>
                <div style={{ marginLeft: 'auto' }} className="mono small">{num(p.unitsSold)} · {money(p.revenue)}</div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <Card style={{ marginTop: 14 }}>
        <CardHead title="Vendor leaderboard — revenue" action={<Link to="/analytics/vendors" className="link">Vendor analytics</Link>} />
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>#</th>
                <th>Store</th>
                <th className="num">Orders</th>
                <th className="num">Revenue</th>
              </tr>
            </thead>
            <tbody>
              {topVendorsByRevenue(orders, 8).map((v, i) => (
                <tr key={v.storeName}>
                  <td className="muted mono">{i + 1}</td>
                  <td>
                    {v.id ? (
                      <Link to={`/vendors/${v.id}`} className="row-flex">
                        <div className="mini-avatar">{initials(v.storeName)}</div>
                        <span className="cell-main">{v.storeName}</span>
                      </Link>
                    ) : (
                      <span className="cell-main">{v.storeName}</span>
                    )}
                  </td>
                  <td className="num">{num(v.ordersCount)}</td>
                  <td className="num">{money(v.revenue)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </>
  )
}

function FunnelRow({
  label,
  value,
  total,
  color,
}: {
  label: string
  value: number
  total: number
  color: string
}) {
  return (
    <div style={{ marginBottom: 12 }}>
      <div className="row-flex" style={{ justifyContent: 'space-between', marginBottom: 4 }}>
        <span className="small" style={{ fontWeight: 600 }}>{label}</span>
        <span className="small muted mono">
          {value} ({Math.round((value / Math.max(1, total)) * 100)}%)
        </span>
      </div>
      <div className="progress-track">
        <div className="progress-fill" style={{ width: `${(value / Math.max(1, total)) * 100}%`, background: color }} />
      </div>
    </div>
  )
}

export function VendorAnalyticsPage() {
  const vendors = useAsyncData(() => api<VendorRow[]>('/admin/vendors')).data ?? []
  const orders = useAsyncData(() => api<AdminOrderRow[]>('/admin/orders', { query: { limit: 500 } })).data ?? []

  const growth: Array<{ label: string; vendors: number }> = []
  {
    const now = new Date()
    for (let i = 7; i >= 0; i--) {
      const ref = new Date(now.getFullYear(), now.getMonth() - i + 1, 0)
      const count = vendors.filter((v) => v.created_at && new Date(v.created_at) <= ref).length
      growth.push({ label: ref.toLocaleDateString('en-PH', { month: 'short' }), vendors: count })
    }
  }

  const open = vendors.filter((v) => v.is_open && !v.is_paused)
  const monthly = monthlySeries(orders, 4)

  return (
    <>
      <PageHeader
        title="Vendor Analytics"
        description="Growth, distribution and performance of the vendor network."
      />

      <div className="grid-kpi">
        <KpiCard label="Total Vendors" value={vendors.length} />
        <KpiCard label="Open" value={open.length} />
        <KpiCard label="Paused" value={vendors.filter((v) => v.is_paused).length} />
        <KpiCard label="Closed" value={vendors.filter((v) => !v.is_open && !v.is_paused).length} />
      </div>

      <div className="grid-2">
        <Card>
          <CardHead title="Vendor growth — cumulative" />
          <div className="card-pad">
            <GrowthLineChart data={growth} dataKey="vendors" height={250} />
          </div>
        </Card>

        <Card>
          <CardHead title="Verified vs unverified" />
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th>State</th>
                  <th className="num">Vendors</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td className="cell-main">Verified</td>
                  <td className="num">{vendors.filter((v) => v.is_verified).length}</td>
                </tr>
                <tr>
                  <td className="cell-main">Unverified</td>
                  <td className="num">{vendors.filter((v) => !v.is_verified).length}</td>
                </tr>
              </tbody>
            </table>
          </div>
          <div className="card-pad">
            <p className="small muted" style={{ marginTop: 4 }}>
              Platform order volume trend:
              {monthly.map((m) => ` ${m.label}: ${m.orders}`).join(' ·')}
            </p>
          </div>
        </Card>
      </div>
    </>
  )
}
