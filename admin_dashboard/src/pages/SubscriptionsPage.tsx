import { api } from '../lib/api'
import { useAsyncData } from '../state/live'
import { fmtDate, num } from '../lib/format'
import {
  Badge,
  Card,
  CardHead,
  EmptyState,
  KpiCard,
  PageHeader,
} from '../components/ui/primitives'
import { DonutChart, ChartLegend, SERIES_COLORS } from '../components/charts/charts'

interface AdminSubscriptionRow {
  id: string
  store_name: string
  is_verified: boolean
  is_paused: boolean
  is_open: boolean
  created_at: string
  menu_count: number
  plan: string
  sub_state: 'active' | 'paused' | 'suspended'
  renewalDate: string | null
}

export function SubscriptionsPage() {
  const rows = useAsyncData(() => api<AdminSubscriptionRow[]>('/admin/subscriptions')).data ?? []

  const active = rows.filter((r) => r.sub_state === 'active')
  const paused = rows.filter((r) => r.sub_state === 'paused')
  const suspended = rows.filter((r) => r.sub_state === 'suspended')

  const donutData = [
    { label: 'Active', value: active.length, colorIndex: 0 },
    { label: 'Paused', value: paused.length, colorIndex: 1 },
    { label: 'Suspended', value: suspended.length, colorIndex: 2 },
  ].filter((d) => d.value > 0)

  return (
    <>
      <PageHeader
        title="Subscriptions"
        description="Vendor plan distribution and subscription state (derived — no billing table yet). All vendors currently report the free plan."
      />

      <div className="grid-kpi">
        <KpiCard label="Total Vendors" value={num(rows.length)} />
        <KpiCard label="Active" value={num(active.length)} />
        <KpiCard label="Paused" value={num(paused.length)} />
        <KpiCard label="Suspended" value={num(suspended.length)} />
      </div>

      <div className="grid-2">
        <Card>
          <CardHead title="State distribution" />
          <div className="card-pad">
            {donutData.length > 0 ? (
              <>
                <DonutChart data={donutData} height={220} />
                <ChartLegend
                  items={donutData.map((d, i) => ({
                    label: `${d.label} (${d.value})`,
                    color: SERIES_COLORS[i % SERIES_COLORS.length],
                  }))}
                />
              </>
            ) : (
              <p className="muted small">No vendors yet.</p>
            )}
          </div>
        </Card>

        <Card>
          <CardHead title="Plan" />
          <div>
            <div className="list-row">
              <div>
                <div className="cell-main">Free</div>
                <div className="cell-sub">₱0 — default for all vendors until billing lands</div>
              </div>
              <div style={{ marginLeft: 'auto' }} className="mono small">
                {rows.length} vendor{rows.length === 1 ? '' : 's'}
              </div>
            </div>
          </div>
        </Card>
      </div>

      <Card style={{ marginTop: 14 }}>
        <CardHead title="All vendor subscriptions" />
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Store</th>
                <th>Plan</th>
                <th>State</th>
                <th>Renewal</th>
                <th>Joined</th>
                <th className="num">Menu Items</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td><span className="cell-main">{r.store_name}</span></td>
                  <td style={{ textTransform: 'capitalize', fontWeight: 600 }}>{r.plan}</td>
                  <td>
                    <Badge tone={r.sub_state === 'active' ? 'green' : r.sub_state === 'paused' ? 'amber' : 'red'}>
                      {r.sub_state}
                    </Badge>
                  </td>
                  <td>{r.renewalDate ? fmtDate(r.renewalDate) : '—'}</td>
                  <td>{fmtDate(r.created_at)}</td>
                  <td className="num">{r.menu_count}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!rows.length && <EmptyState message="No vendors registered yet." />}
        </div>
      </Card>
    </>
  )
}
