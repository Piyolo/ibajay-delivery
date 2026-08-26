import { useState } from 'react'
import { monthlySeries, revenueSeries } from '../../data/mockDb'
import { money, num } from '../../lib/format'
import { Card, CardHead, KpiCard, PageHeader } from '../../components/ui/primitives'
import { OrdersBarChart, RevenueAreaChart } from '../../components/charts/charts'
import { useAsyncData } from '../../state/live'

type Grain = 'daily' | 'weekly' | 'monthly' | 'annual'

export function SalesAnalyticsPage() {
  const [grain, setGrain] = useState<Grain>('daily')

  const series = useAsyncData(() =>
    grain === 'monthly' || grain === 'annual' ? monthlySeries(grain === 'annual' ? 12 : 4) : weeklyOrDaily(grain),
  )

  const data = series.data ?? []
  const totalRevenue = data.reduce((s, p) => s + p.revenue, 0)
  const totalOrders = data.reduce((s, p) => s + p.orders, 0)
  const aov = totalOrders ? Math.round(totalRevenue / totalOrders) : 0

  return (
    <>
      <PageHeader
        title="Sales Analytics"
        description="Revenue and order volume across reporting periods."
        actions={
          <select className="select" value={grain} onChange={(e) => setGrain(e.target.value as Grain)}>
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
            <option value="annual">Annual</option>
          </select>
        }
      />

      <div className="grid-kpi">
        <KpiCard label={`Revenue (${grain})`} value={money(totalRevenue)} />
        <KpiCard label={`Orders (${grain})`} value={num(totalOrders)} />
        <KpiCard label="Average Order Value" value={money(aov)} />
        <KpiCard
          label="Best Day"
          value={
            data.length
              ? money(Math.max(...data.map((d) => d.revenue)))
              : money(0)
          }
        />
      </div>

      <div className="grid-2">
        <Card>
          <CardHead title="Revenue trend" />
          <div className="card-pad"><RevenueAreaChart data={data} height={280} /></div>
        </Card>
        <Card>
          <CardHead title="Order volume" />
          <div className="card-pad"><OrdersBarChart data={data} height={280} /></div>
        </Card>
      </div>

      <Card>
        <CardHead title="Period breakdown" />
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Period</th>
                <th className="num">Orders</th>
                <th className="num">Revenue</th>
                <th className="num">AOV</th>
                <th>Share of revenue</th>
              </tr>
            </thead>
            <tbody>
              {data.map((d) => {
                const share = totalRevenue ? (d.revenue / totalRevenue) * 100 : 0
                return (
                  <tr key={d.label}>
                    <td className="cell-main">{d.label}</td>
                    <td className="num">{num(d.orders)}</td>
                    <td className="num">{money(d.revenue)}</td>
                    <td className="num">{money(d.orders ? Math.round(d.revenue / d.orders) : 0)}</td>
                    <td>
                      <div className="row-flex">
                        <div className="progress-track" style={{ width: 140 }}>
                          <div className="progress-fill" style={{ width: `${share}%` }} />
                        </div>
                        <span className="small muted mono">{share.toFixed(1)}%</span>
                      </div>
                    </td>
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      </Card>
    </>
  )
}

function weeklyOrDaily(grain: 'daily' | 'weekly') {
  if (grain === 'weekly') {
    const daily = revenueSeries(28)
    // Bucket the last 28 days into 4 ISO-style weeks.
    const weeks: Array<{ label: string; revenue: number; orders: number }> = []
    for (let w = 0; w < 4; w++) {
      const chunk = daily.slice(w * 7, w * 7 + 7)
      weeks.push({
        label: `Week ${w + 1}`,
        revenue: chunk.reduce((s, d) => s + d.revenue, 0),
        orders: chunk.reduce((s, d) => s + d.orders, 0),
      })
    }
    return weeks
  }
  return revenueSeries(14)
}
