import { Link } from 'react-router-dom'
import { bestSellers, monthlySeries, revenueSeries, topVendors, vendors } from '../../data/mockDb'
import { money, num } from '../../lib/format'
import {
  Badge,
  Card,
  CardHead,
  initials,
  KpiCard,
  PageHeader,
  Stars,
} from '../../components/ui/primitives'
import { GrowthLineChart, RevenueAreaChart } from '../../components/charts/charts'
import { useAsyncData } from '../../state/live'

export function AnalyticsOverviewPage() {
  const series = useAsyncData(() => revenueSeries(14)).data ?? []
  const totalRevenue = series.reduce((s, d) => s + d.revenue, 0)
  const totalOrders = series.reduce((s, d) => s + d.orders, 0)

  const approved = vendors.filter((v) => v.status === 'approved')
  const pending = vendors.filter((v) => v.status === 'pending')
  const suspended = vendors.filter((v) => v.status === 'suspended')

  return (
    <>
      <PageHeader
        title="Analytics Overview"
        description="Platform health across sales, vendors and customers."
      />

      <div className="grid-kpi">
        <KpiCard label="Revenue (14d)" value={money(totalRevenue)} />
        <KpiCard label="Orders (14d)" value={num(totalOrders)} />
        <KpiCard label="Active Vendors" value={approved.length} />
        <KpiCard label="Pending Applications" value={pending.length} deltaGoodDirection="down" />
      </div>

      <Card>
        <CardHead title="Platform revenue — last 14 days" />
        <div className="card-pad"><RevenueAreaChart data={series} height={260} /></div>
      </Card>

      <div className="grid-2" style={{ marginTop: 14 }}>
        <Card>
          <CardHead title="Vendor funnel" />
          <div className="card-pad">
            <FunnelRow label="Approved & live" value={approved.length} total={vendors.length} color="#2e9e5b" />
            <FunnelRow label="Pending review" value={pending.length} total={vendors.length} color="#de9e20" />
            <FunnelRow label="Suspended" value={suspended.length} total={vendors.length} color="#d64545" />
            <FunnelRow
              label="Verified businesses"
              value={approved.filter((v) => v.verification === 'verified').length}
              total={vendors.length}
              color="#3378c9"
            />
          </div>
        </Card>

        <Card>
          <CardHead title="Top products by units sold" action={<Link to="/analytics/sales" className="link">Sales</Link>} />
          <div>
            {bestSellers(6).map((p) => (
              <div key={`${p.vendorId}-${p.name}`} className="list-row">
                <div>
                  <div className="cell-main small">{p.name}</div>
                  <div className="cell-sub">{p.vendorName}</div>
                </div>
                <div style={{ marginLeft: 'auto' }} className="mono small">{num(p.unitsSold)} · {money(p.revenue)}</div>
              </div>
            ))}
          </div>
        </Card>
      </div>

      <Card style={{ marginTop: 14 }}>
        <CardHead title="Vendor leaderboard — lifetime revenue" action={<Link to="/analytics/vendors" className="link">Vendor analytics</Link>} />
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>#</th>
                <th>Store</th>
                <th>Rating</th>
                <th className="num">Orders</th>
                <th className="num">Revenue</th>
                <th>Plan</th>
              </tr>
            </thead>
            <tbody>
              {topVendors(8).map((v, i) => (
                <tr key={v.id}>
                  <td className="muted mono">{i + 1}</td>
                  <td>
                    <Link to={`/vendors/${v.id}`} className="row-flex">
                      <div className="mini-avatar">{initials(v.storeName)}</div>
                      <span className="cell-main">{v.storeName}</span>
                    </Link>
                  </td>
                  <td><Stars rating={v.rating} /></td>
                  <td className="num">{num(v.ordersCount)}</td>
                  <td className="num">{money(v.revenue)}</td>
                  <td>
                    <Badge tone={v.plan === 'founding' ? 'orange' : v.plan === 'plus' ? 'purple' : 'gray'} dot={false}>
                      {v.plan === 'founding' ? 'Founding' : v.plan === 'plus' ? 'Plus' : 'Free'}
                    </Badge>
                  </td>
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
  const growth = useAsyncData(() => {
    // Vendor count over the last 8 months, derived from join dates.
    const months: Array<{ label: string; vendors: number }> = []
    for (let i = 7; i >= 0; i--) {
      const ref = new Date()
      ref.setDate(1)
      ref.setMonth(ref.getMonth() - i)
      ref.setHours(23, 59, 59)
      const count = vendors.filter(
        (v) => new Date(`${v.joinedAt}T23:59:59`) <= ref && v.status !== 'rejected',
      ).length
      months.push({ label: ref.toLocaleDateString('en-PH', { month: 'short' }), vendors: count })
    }
    return months
  }).data ?? []

  const approved = vendors.filter((v) => v.status === 'approved')
  const revenueByPlan = ['free', 'plus', 'founding'].map((plan) => ({
    plan,
    vendors: approved.filter((v) => v.plan === plan).length,
    revenue: approved.filter((v) => v.plan === plan).reduce((s, v) => s + v.revenue, 0),
  }))
  const monthly = useAsyncData(() => monthlySeries(4)).data ?? []

  return (
    <>
      <PageHeader
        title="Vendor Analytics"
        description="Growth, distribution and performance of the vendor network."
      />

      <div className="grid-kpi">
        <KpiCard label="Total Vendors" value={vendors.length} />
        <KpiCard label="Active" value={approved.length} />
        <KpiCard label="Pending Review" value={vendors.filter((v) => v.status === 'pending').length} deltaGoodDirection="down" />
        <KpiCard label="Suspended" value={vendors.filter((v) => v.status === 'suspended').length} deltaGoodDirection="down" />
      </div>

      <div className="grid-2">
        <Card>
          <CardHead title="Vendor growth — cumulative" />
          <div className="card-pad">
            <GrowthLineChart data={growth} dataKey="vendors" height={250} />
          </div>
        </Card>

        <Card>
          <CardHead title="Revenue by subscription plan" />
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th>Plan</th>
                  <th className="num">Vendors</th>
                  <th className="num">Lifetime revenue</th>
                  <th className="num">Avg / vendor</th>
                </tr>
              </thead>
              <tbody>
                {revenueByPlan.map((r) => (
                  <tr key={r.plan}>
                    <td className="cell-main" style={{ textTransform: 'capitalize' }}>
                      {r.plan === 'founding' ? 'Founding Vendor' : r.plan}
                    </td>
                    <td className="num">{r.vendors}</td>
                    <td className="num">{money(r.revenue)}</td>
                    <td className="num">{money(r.vendors ? Math.round(r.revenue / r.vendors) : 0)}</td>
                  </tr>
                ))}
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
