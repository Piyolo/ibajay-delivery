/** Shared shapes + series builders for the analytics pages, computed
 *  client-side from the live /admin/orders and /admin/vendors payloads. */

export interface AdminOrderItemRow {
  item_name: string
  quantity: number
  unit_price: number
}

export interface AdminOrderRow {
  id: string
  order_number: string
  vendor_id?: string | null
  status: string
  delivery_method: string
  payment_method: string
  total: number
  created_at: string
  customer_name: string | null
  vendor_name: string | null
  items: AdminOrderItemRow[]
}

export interface Point {
  label: string
  revenue: number
  orders: number
}

const LIVE_CANCELLED = 'cancelled'

function dayKey(d: Date): string {
  return d.toISOString().slice(0, 10)
}

export function revenueSeries(orders: AdminOrderRow[], days: number): Point[] {
  const buckets = new Map<string, Point>()
  const out: Point[] = []
  const now = new Date()
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(now)
    d.setDate(d.getDate() - i)
    const p: Point = {
      label: d.toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }),
      revenue: 0,
      orders: 0,
    }
    buckets.set(dayKey(d), p)
    out.push(p)
  }
  for (const o of orders) {
    if (o.status === LIVE_CANCELLED) continue
    const p = buckets.get(dayKey(new Date(o.created_at)))
    if (p) {
      p.revenue += o.total
      p.orders += 1
    }
  }
  return out
}

export function weeklySeries(orders: AdminOrderRow[], weeks: number): Point[] {
  const daily = revenueSeries(orders, weeks * 7)
  const out: Point[] = []
  for (let w = 0; w < weeks; w++) {
    const chunk = daily.slice(w * 7, w * 7 + 7)
    out.push({
      label: `Week ${w + 1}`,
      revenue: chunk.reduce((s, d) => s + d.revenue, 0),
      orders: chunk.reduce((s, d) => s + d.orders, 0),
    })
  }
  return out
}

export function monthlySeries(orders: AdminOrderRow[], monthsBack: number): Point[] {
  const out: Point[] = []
  const now = new Date()
  for (let i = monthsBack - 1; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1)
    out.push({
      label: d.toLocaleDateString('en-PH', { month: 'short' }),
      revenue: 0,
      orders: 0,
    })
  }
  for (const o of orders) {
    if (o.status === LIVE_CANCELLED) continue
    const d = new Date(o.created_at)
    const idx =
      (now.getFullYear() - d.getFullYear()) * 12 + (now.getMonth() - d.getMonth())
    if (idx >= 0 && idx < monthsBack) {
      const p = out[monthsBack - 1 - idx]
      p.revenue += o.total
      p.orders += 1
    }
  }
  return out
}

export interface VendorTotal {
  id: string | null
  storeName: string
  ordersCount: number
  revenue: number
}

export function topVendorsByRevenue(orders: AdminOrderRow[], limit: number): VendorTotal[] {
  const agg = new Map<string, VendorTotal>()
  for (const o of orders) {
    if (o.status === LIVE_CANCELLED) continue
    const key = o.vendor_name ?? o.vendor_id ?? 'Unknown'
    const cur = agg.get(key) ?? {
      id: o.vendor_id ?? null,
      storeName: o.vendor_name ?? 'Unknown',
      ordersCount: 0,
      revenue: 0,
    }
    cur.ordersCount += 1
    cur.revenue += o.total
    agg.set(key, cur)
  }
  return [...agg.values()].sort((a, b) => b.revenue - a.revenue).slice(0, limit)
}

export interface ProductSalesRow {
  name: string
  unitsSold: number
  revenue: number
}

export function bestSellers(orders: AdminOrderRow[], limit: number): ProductSalesRow[] {
  const agg = new Map<string, ProductSalesRow>()
  for (const o of orders) {
    if (o.status === LIVE_CANCELLED) continue
    for (const item of o.items ?? []) {
      const cur = agg.get(item.item_name) ?? { name: item.item_name, unitsSold: 0, revenue: 0 }
      cur.unitsSold += item.quantity
      cur.revenue += item.unit_price * item.quantity
      agg.set(item.item_name, cur)
    }
  }
  return [...agg.values()].sort((a, b) => b.unitsSold - a.unitsSold).slice(0, limit)
}
