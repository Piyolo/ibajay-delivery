import { useCallback, useEffect, useMemo, useState } from 'react'
import { api } from '../lib/api'
import type { OrderStatus } from '../types'
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

interface AdminOrderItem {
  item_name: string
  quantity: number
  unit_price: number
}

interface AdminOrder {
  id: string
  order_number: string
  status: OrderStatus
  delivery_method: 'delivery' | 'pickup' | 'scheduled_delivery'
  payment_method: string
  subtotal: number
  delivery_fee: number
  total: number
  created_at: string
  customer_name: string | null
  vendor_name: string | null
  items: AdminOrderItem[]
}

const STATUSES: OrderStatus[] = [
  'pending',
  'accepted',
  'preparing',
  'ready',
  'out_for_delivery',
  'delivered',
  'completed',
  'cancelled',
]

function labelize(s: string): string {
  return s.replaceAll('_', ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

function methodLabel(m: string): string {
  if (m === 'scheduled_delivery') return 'Scheduled'
  return labelize(m)
}

const LIVE_STATUSES = new Set<OrderStatus>(['accepted', 'preparing', 'ready', 'out_for_delivery'])

export function OrdersPage() {
  const [query, setQuery] = useState('')
  const [statusF, setStatusF] = useState<OrderStatus | 'all'>('all')
  const [methodF, setMethodF] = useState<string>('all')
  const [page, setPage] = useState(1)
  const [orders, setOrders] = useState<AdminOrder[]>([])
  const [loading, setLoading] = useState(true)
  const [selected, setSelected] = useState<AdminOrder | null>(null)
  const { tick } = useLive()

  const load = useCallback(() => {
    api<AdminOrder[]>('/admin/orders', { query: { limit: 300 } })
      .then(setOrders)
      .catch(() => setOrders([]))
      .finally(() => setLoading(false))
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(load, [load, tick])

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return orders.filter((o) => {
      if (statusF !== 'all' && o.status !== statusF) return false
      if (methodF === 'delivery_scheduled') {
        if (o.delivery_method !== 'delivery' && o.delivery_method !== 'scheduled_delivery') return false
      } else if (methodF !== 'all' && o.delivery_method !== methodF) return false
      if (!q) return true
      return (
        o.order_number.toLowerCase().includes(q) ||
        (o.customer_name?.toLowerCase().includes(q) ?? false) ||
        (o.vendor_name?.toLowerCase().includes(q) ?? false)
      )
    })
  }, [orders, query, statusF, methodF])

  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const safePage = Math.min(page, pageCount)
  const rows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE)
  const liveCount = orders.filter((o) => LIVE_STATUSES.has(o.status)).length

  return (
    <>
      <PageHeader
        title="Orders"
        description={`${liveCount} live order${liveCount === 1 ? '' : 's'} right now · ${orders.length} recent order${orders.length === 1 ? '' : 's'}`}
      />

      <div className="filters-bar">
        <SearchBox value={query} onChange={setQuery} placeholder="Search order number, customer or store…" />
        <select className="select" value={statusF} onChange={(e) => setStatusF(e.target.value as OrderStatus | 'all')}>
          <option value="all">All statuses</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>{labelize(s)}</option>
          ))}
        </select>
        <select className="select" value={methodF} onChange={(e) => setMethodF(e.target.value)}>
          <option value="all">All methods</option>
          <option value="delivery">Delivery</option>
          <option value="pickup">Pickup</option>
          <option value="scheduled_delivery">Scheduled</option>
        </select>
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
                <tr key={o.id} onClick={() => setSelected(o)} style={{ cursor: 'pointer' }}>
                  <td>
                    <div className="cell-main mono">{o.order_number}</div>
                    <div className="cell-sub">{o.items.length} item{o.items.length === 1 ? '' : 's'}</div>
                  </td>
                  <td>{o.vendor_name ?? '—'}</td>
                  <td>{o.customer_name ?? '—'}</td>
                  <td>{methodLabel(o.delivery_method)}</td>
                  <td className="small">{labelize(o.payment_method)}</td>
                  <td className="num">{money(o.total)}</td>
                  <td>
                    <Badge tone={statusToneOfOrder(o.status)}>{labelize(o.status)}</Badge>
                  </td>
                  <td className="small">{fmtDateTime(new Date(o.created_at))}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!rows.length && (
            <EmptyState message={loading ? 'Loading orders…' : 'No orders match the current filters.'} />
          )}
        </div>
        <Pagination page={safePage} pageCount={pageCount} total={filtered.length} onPage={setPage} />
      </Card>

      {selected && <OrderDrawer order={selected} onClose={() => setSelected(null)} />}
    </>
  )
}

function statusToneOfOrder(s: OrderStatus): 'green' | 'amber' | 'red' | 'gray' | 'blue' {
  switch (s) {
    case 'delivered':
    case 'completed':
      return 'green'
    case 'pending':
      return 'amber'
    case 'accepted':
    case 'preparing':
    case 'ready':
    case 'out_for_delivery':
      return 'blue'
    case 'cancelled':
      return 'red'
    default:
      return 'gray'
  }
}

function OrderDrawer({ order, onClose }: { order: AdminOrder; onClose: () => void }) {
  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(15, 15, 20, 0.45)',
        display: 'flex',
        justifyContent: 'flex-end',
        zIndex: 60,
      }}
      onClick={onClose}
    >
      <div
        className="card"
        style={{ width: 420, maxWidth: '92vw', margin: 16, padding: 18, overflowY: 'auto', height: 'fit-content', maxHeight: '92vh' }}
        onClick={(e) => e.stopPropagation()}
      >
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <h3 className="mono" style={{ fontSize: 14 }}>{order.order_number}</h3>
          <button className="btn ghost xs" onClick={onClose}>Close</button>
        </div>
        <p className="cell-sub" style={{ marginBottom: 12 }}>
          {fmtDateTime(new Date(order.created_at))} · {order.customer_name ?? 'Unknown customer'} →{' '}
          {order.vendor_name ?? 'Unknown store'}
        </p>

        <table className="tbl" style={{ marginBottom: 10 }}>
          <thead>
            <tr>
              <th>Item</th>
              <th className="num">Qty</th>
              <th className="num">Price</th>
            </tr>
          </thead>
          <tbody>
            {order.items.map((i, idx) => (
              <tr key={idx}>
                <td>{i.item_name}</td>
                <td className="num">{i.quantity}</td>
                <td className="num">{money(i.unit_price)}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="list-row"><span className="cell-sub">Subtotal</span><span className="mono small" style={{ marginLeft: 'auto' }}>{money(order.subtotal)}</span></div>
        <div className="list-row"><span className="cell-sub">Delivery fee</span><span className="mono small" style={{ marginLeft: 'auto' }}>{money(order.delivery_fee)}</span></div>
        <div className="list-row"><span className="cell-main">Total</span><span className="mono small" style={{ marginLeft: 'auto' }}>{money(order.total)}</span></div>
        <div className="list-row">
          <Badge tone={statusToneOfOrder(order.status)}>{labelize(order.status)}</Badge>
          <span className="small muted" style={{ marginLeft: 'auto' }}>{methodLabel(order.delivery_method)} · {labelize(order.payment_method)}</span>
        </div>
      </div>
    </div>
  )
}
