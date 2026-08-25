import { useMemo, useState } from 'react'
import { X } from 'lucide-react'
import { customerById, getVendor, isLive, orders } from '../data/mockDb'
import type { Method, Order, OrderStatus } from '../types'
import { ORDER_FLOW } from '../types'
import { fmtDateTime, money } from '../lib/format'
import { useLive } from '../state/live'
import {
  Badge,
  Card,
  EmptyState,
  PAGE_SIZE,
  PageHeader,
  Pagination,
  SearchBox,
} from '../components/ui/primitives'

const STATUSES: Array<{ v: OrderStatus | 'all'; label: string }> = [
  { v: 'all', label: 'All statuses' },
  ...ORDER_FLOW.map((s) => ({ v: s as OrderStatus | 'all', label: labelize(s) })),
  { v: 'cancelled' as const, label: 'Cancelled' },
]

function labelize(s: string): string {
  return s.replaceAll('_', ' ').replace(/\b\w/g, (c: string) => c.toUpperCase())
}

export function OrdersPage() {
  const [query, setQuery] = useState('')
  const [statusF, setStatusF] = useState<OrderStatus | 'all'>('all')
  const [vendorF, setVendorF] = useState('all')
  const [methodF, setMethodF] = useState<Method | 'all'>('all')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState<Order | null>(null)
  const { tick } = useLive()

  const filtered = useMemo(() => {
    void tick // re-run when the simulated auto-refresh advances orders
    const q = query.trim().toLowerCase()
    return orders.filter((o) => {
      if (statusF !== 'all' && o.status !== statusF) return false
      if (vendorF !== 'all' && o.vendorId !== vendorF) return false
      if (methodF !== 'all' && o.method !== methodF) return false
      if (from && o.placedAt < new Date(`${from}T00:00:00`)) return false
      if (to && o.placedAt > new Date(`${to}T23:59:59`)) return false
      if (!q) return true
      const vendor = getVendor(o.vendorId)
      const customer = customerById(o.customerId)
      return (
        o.id.toLowerCase().includes(q) ||
        (customer?.name.toLowerCase().includes(q) ?? false) ||
        (vendor?.storeName.toLowerCase().includes(q) ?? false)
      )
    })
  }, [query, statusF, vendorF, methodF, from, to, tick])

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const safePage = Math.min(page, pageCount)
  const rows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE)
  const liveCount = orders.filter((o) => isLive(o.status)).length

  return (
    <>
      <PageHeader
        title="Orders"
        description={`${liveCount} live order${liveCount === 1 ? '' : 's'} right now · ${orders.length} total in the last 45 days`}
      />

      <div className="filters-bar">
        <SearchBox value={query} onChange={setQuery} placeholder="Search order ID, customer or store…" />
        <select className="select" value={statusF} onChange={(e) => setStatusF(e.target.value as OrderStatus | 'all')}>
          {STATUSES.map((s) => (
            <option key={s.v} value={s.v}>{labelize(s.label)}</option>
          ))}
        </select>
        <select className="select" value={vendorF} onChange={(e) => setVendorF(e.target.value)}>
          <option value="all">All vendors</option>
          {[...new Set(orders.map((o) => o.vendorId))].map((vid) => (
            <option key={vid} value={vid}>{getVendor(vid)?.storeName}</option>
          ))}
        </select>
        <select className="select" value={methodF} onChange={(e) => setMethodF(e.target.value as Method | 'all')}>
          <option value="all">All methods</option>
          <option value="delivery">Delivery</option>
          <option value="pickup">Pickup</option>
          <option value="scheduled">Scheduled</option>
        </select>
        <input className="input" type="date" value={from} onChange={(e) => setFrom(e.target.value)} title="From date" />
        <span className="muted small">→</span>
        <input className="input" type="date" value={to} onChange={(e) => setTo(e.target.value)} title="To date" />
        <div className="spacer" />
        <span className="small muted">{filtered.length} orders</span>
      </div>

      <Card>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Order</th>
                <th>Vendor</th>
                <th>Customer</th>
                <th>Method</th>
                <th>Payment</th>
                <th className="num">Total</th>
                <th>Status</th>
                <th>Placed</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((o) => (
                <tr key={o.id} className="clickable" onClick={() => setSelected(o)}>
                  <td>
                    <div className="cell-main mono">{o.id}</div>
                    <div className="cell-sub">{o.items.reduce((s, i) => s + i.qty, 0)} items</div>
                  </td>
                  <td>{getVendor(o.vendorId)?.storeName}</td>
                  <td>{customerById(o.customerId)?.name}</td>
                  <td style={{ textTransform: 'capitalize' }}>{o.method}</td>
                  <td style={{ textTransform: 'uppercase', fontSize: 11.5 }}>
                    {o.payment === 'cod' ? 'COD' : 'Cash on pickup'}
                  </td>
                  <td className="num">{money(o.total)}</td>
                  <td><OrderStatusBadge status={o.status} /></td>
                  <td>{fmtDateTime(o.placedAt)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!rows.length && <EmptyState message="No orders match the current filters." />}
        </div>
        <Pagination page={safePage} pageCount={pageCount} total={filtered.length} onPage={setPage} />
      </Card>

      {selected && <OrderDrawer order={selected} onClose={() => setSelected(null)} />}
    </>
  )
}

export function OrderStatusBadge({ status }: { status: string }) {
  const tone =
    status === 'completed' || status === 'delivered'
      ? 'green'
      : status === 'cancelled'
        ? 'red'
        : status === 'pending'
          ? 'amber'
          : status === 'accepted'
            ? 'blue'
            : status === 'preparing'
              ? 'purple'
              : status === 'ready'
                ? 'green'
                : 'orange'
  return <Badge tone={tone}>{labelize(status)}</Badge>
}

function OrderDrawer({ order, onClose }: { order: Order; onClose: () => void }) {
  const vendor = getVendor(order.vendorId)
  const customer = customerById(order.customerId)

  return (
    <>
      <div className="drawer-overlay" onClick={onClose} />
      <aside className="drawer">
        <div className="drawer-head">
          <h3 className="mono">{order.id}</h3>
          <OrderStatusBadge status={order.status} />
          <button className="icon-btn" style={{ marginLeft: 'auto' }} onClick={onClose}>
            <X />
          </button>
        </div>

        <div className="drawer-body">
          <section style={{ marginBottom: 18 }}>
            <span className="field-label">Vendor</span>
            <div className="cell-main">{vendor?.storeName}</div>
            <div className="small muted">Brgy. {vendor?.barangay}, Ibajay · {vendor?.mobile}</div>
          </section>

          <section style={{ marginBottom: 18 }}>
            <span className="field-label">Customer</span>
            <div className="cell-main">{customer?.name}</div>
            <div className="small muted">{order.address}</div>
            <div className="small muted">{order.payment === 'cod' ? 'Cash on delivery' : 'Cash on pickup'}</div>
          </section>

          <section style={{ marginBottom: 18 }}>
            <span className="field-label">Items</span>
            <table className="tbl">
              <tbody>
                {order.items.map((it, i) => (
                  <tr key={i}>
                    <td>{it.name}</td>
                    <td className="num muted">×{it.qty}</td>
                    <td className="num">{money(it.price * it.qty)}</td>
                  </tr>
                ))}
                <tr>
                  <td colSpan={2} className="muted">Subtotal</td>
                  <td className="num">{money(order.subtotal)}</td>
                </tr>
                <tr>
                  <td colSpan={2} className="muted">Delivery fee</td>
                  <td className="num">{money(order.deliveryFee)}</td>
                </tr>
                <tr>
                  <td colSpan={2}><strong>Total</strong></td>
                  <td className="num"><strong>{money(order.total)}</strong></td>
                </tr>
              </tbody>
            </table>
          </section>

          <section>
            <span className="field-label">Progress</span>
            {order.status === 'cancelled' ? (
              <div>
                <Badge tone="red">Cancelled</Badge>
                <p className="small muted" style={{ marginTop: 8 }}>
                  Reason: {order.cancelReason ?? 'Not specified.'}
                </p>
              </div>
            ) : (
              <ul className="timeline">
                {ORDER_FLOW.map((step, i) => {
                  const curIdx = ORDER_FLOW.indexOf(order.status)
                  return (
                    <li
                      key={step}
                      className={
                        i < curIdx ? 'done' : i === curIdx ? 'current' : 'pending-step'
                      }
                    >
                      <span className="tl-dot" />
                      <span className="tl-label">
                        {labelize(step)}
                        {i <= curIdx && step === order.status && (
                          <span className="cell-sub" style={{ display: 'block' }}>
                            {fmtDateTime(order.placedAt)}
                          </span>
                        )}
                      </span>
                    </li>
                  )
                })}
              </ul>
            )}
          </section>
        </div>
      </aside>
    </>
  )
}
