import { vendors } from '../data/mockDb'
import type { Plan } from '../types'
import { fmtDate, money, num } from '../lib/format'
import {
  Badge,
  Card,
  CardHead,
  KpiCard,
  PageHeader,
} from '../components/ui/primitives'
import { DonutChart, ChartLegend, SERIES_COLORS } from '../components/charts/charts'

const PLAN_META: Record<Plan, { label: string; price: string }> = {
  free: { label: 'Free', price: '₱0' },
  plus: { label: 'Plus', price: '₱299/mo · ₱1,999/yr' },
  founding: { label: 'Founding Vendor', price: '₱7,999 one-time' },
}

export function SubscriptionsPage() {
  const approved = vendors.filter((v) => v.status === 'approved')
  const byPlan = (plan: Plan) => approved.filter((v) => v.plan === plan)
  const inGrace = vendors.filter((v) => v.subState === 'grace')
  const expired = vendors.filter((v) => v.subState === 'expired')

  // Monthly recurring revenue estimate: Plus monthly-equivalents only.
  const mrr = byPlan('plus').length * 299

  const donutData = (['free', 'plus', 'founding'] as Plan[])
    .map((p, i) => ({ label: PLAN_META[p].label, value: byPlan(p).length, colorIndex: i }))
    .filter((d) => d.value > 0)

  return (
    <>
      <PageHeader
        title="Subscriptions"
        description="Vendor plan distribution, renewals and subscription revenue."
      />

      <div className="grid-kpi">
        <KpiCard label="Plus Subscribers" value={num(byPlan('plus').length)} />
        <KpiCard label="Founding Vendors" value={`${byPlan('founding').length}/10`} />
        <KpiCard label="Free Plan" value={num(byPlan('free').length)} />
        <KpiCard label="Est. MRR" value={money(mrr)} />
        <KpiCard label="In Grace Period" value={inGrace.length} deltaGoodDirection="down" />
      </div>

      <div className="grid-2">
        <Card>
          <CardHead title="Plan distribution" />
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
              <p className="muted small">No active subscriptions.</p>
            )}
          </div>
        </Card>

        <Card>
          <CardHead title="Plans" />
          <div>
            {(Object.keys(PLAN_META) as Plan[]).map((p) => (
              <div key={p} className="list-row">
                <div>
                  <div className="cell-main">{PLAN_META[p].label}</div>
                  <div className="cell-sub">{PLAN_META[p].price}</div>
                </div>
                <div style={{ marginLeft: 'auto' }} className="mono small">
                  {byPlan(p).length} vendor{byPlan(p).length === 1 ? '' : 's'}
                </div>
              </div>
            ))}
          </div>
          <div className="card-pad" style={{ borderTop: '1px solid var(--c-border)' }}>
            <p className="small muted">
              Expiring soon: {inGrace.map((v) => v.storeName).join(', ') || 'none'}
            </p>
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
                <th>Renewal / Grace Ends</th>
                <th className="num">Lifetime Revenue</th>
              </tr>
            </thead>
            <tbody>
              {approved.map((v) => (
                <tr key={v.id}>
                  <td><span className="cell-main">{v.storeName}</span></td>
                  <td style={{ textTransform: 'capitalize', fontWeight: 600 }}>
                    {PLAN_META[v.plan].label}
                  </td>
                  <td>
                    <Badge tone={v.subState === 'active' ? 'green' : v.subState === 'grace' ? 'amber' : 'red'}>
                      {v.subState}
                    </Badge>
                  </td>
                  <td>{v.renewalDate ? fmtDate(v.renewalDate) : '—'}</td>
                  <td className="num">{money(v.revenue)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {expired.length > 0 && (
        <p className="small muted" style={{ marginTop: 10 }}>
          {expired.length} vendor account{expired.length === 1 ? '' : 's'} with expired plans retain all historical data per platform policy — stores are hidden until renewal.
        </p>
      )}
    </>
  )
}
