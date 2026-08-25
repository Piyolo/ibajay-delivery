import {
  AuditEntry,
  Category,
  Customer,
  Kpis,
  Method,
  ORDER_FLOW,
  Order,
  OrderItem,
  OrderStatus,
  Payment,
  ProductSales,
  Review,
  StaffUser,
  Vendor,
} from '../types'

// Deterministic PRNG so the demo dataset is stable between reloads.
function mulberry32(seed: number) {
  let a = seed
  return () => {
    a |= 0
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

const rand = mulberry32(20260824)

function int(min: number, max: number): number {
  return Math.floor(rand() * (max - min + 1)) + min
}

function pick<T>(arr: T[]): T {
  return arr[Math.floor(rand() * arr.length)]
}

function daysAgo(n: number, hour = int(8, 20)): Date {
  const d = new Date()
  d.setDate(d.getDate() - n)
  d.setHours(hour, int(0, 59), 0, 0)
  return d
}

// ---------------------------------------------------------------- Vendors

export const vendors: Vendor[] = [
  {
    id: 'v1',
    storeName: 'Ibajay Seafood Grill',
    ownerName: 'Roderick Flores',
    mobile: '+63 917 302 8841',
    email: 'roderick.flores@gmail.com',
    barangay: 'Poblacion',
    description:
      'Fresh catch grilled to order. The platform pilot store since May 2026.',
    status: 'approved',
    verification: 'verified',
    plan: 'founding',
    subState: 'active',
    ordersCount: 412,
    revenue: 168540,
    rating: 4.7,
    productCount: 24,
    categoryCount: 6,
    joinedAt: '2026-05-02',
    pilot: true,
  },
  {
    id: 'v2',
    storeName: "Kusina ni Ining",
    ownerName: 'Juanita Requinto',
    mobile: '+63 928 551 2047',
    email: 'ining.requinto@yahoo.com',
    barangay: 'Naisud',
    description: 'Home-style carinderia favorites, cooked daily.',
    status: 'approved',
    verification: 'verified',
    plan: 'plus',
    subState: 'active',
    renewalDate: '2026-09-18',
    ordersCount: 356,
    revenue: 121300,
    rating: 4.6,
    productCount: 31,
    categoryCount: 7,
    joinedAt: '2026-05-11',
  },
  {
    id: 'v3',
    storeName: 'Ibajay Bakery',
    ownerName: 'Eduardo Tanaleon',
    mobile: '+63 906 774 3320',
    email: 'edtanaleon@gmail.com',
    barangay: 'Poblacion',
    description: 'Pandesal, ensaymada and custom cakes since 1998.',
    status: 'approved',
    verification: 'verified',
    plan: 'plus',
    subState: 'grace',
    renewalDate: '2026-08-29',
    ordersCount: 501,
    revenue: 98470,
    rating: 4.8,
    productCount: 18,
    categoryCount: 4,
    joinedAt: '2026-04-27',
  },
  {
    id: 'v4',
    storeName: "Mang Ben's Lechon House",
    ownerName: 'Benjamin Salazar',
    mobile: '+63 915 208 6613',
    email: 'bensalazar58@outlook.com',
    barangay: 'Bugtong Bato',
    description: 'Lechon by reservation, party trays and bilao specials.',
    status: 'approved',
    verification: 'verified',
    plan: 'founding',
    subState: 'active',
    ordersCount: 189,
    revenue: 214260,
    rating: 4.9,
    productCount: 12,
    categoryCount: 3,
    joinedAt: '2026-05-06',
  },
  {
    id: 'v5',
    storeName: 'Aklan Halo-Halo Corner',
    ownerName: 'Maria Teresa Sarmiento',
    mobile: '+63 939 445 7782',
    email: 'mtsarmiento@gmail.com',
    barangay: 'Riviera',
    description: 'Halo-halo, mais con yelo and merienda classics.',
    status: 'approved',
    verification: 'unverified',
    plan: 'plus',
    subState: 'active',
    renewalDate: '2026-09-02',
    ordersCount: 274,
    revenue: 76910,
    rating: 4.5,
    productCount: 15,
    categoryCount: 4,
    joinedAt: '2026-05-19',
  },
  {
    id: 'v6',
    storeName: "J&J Burger Stop",
    ownerName: 'Jeric Tumbokon',
    mobile: '+63 995 118 9034',
    email: 'jerictumbokon@gmail.com',
    barangay: 'Poblacion',
    description: 'Grilled burgers, fries and shakes beside the plaza.',
    status: 'approved',
    verification: 'unverified',
    plan: 'free',
    subState: 'active',
    ordersCount: 143,
    revenue: 38220,
    rating: 4.3,
    productCount: 5,
    categoryCount: 2,
    joinedAt: '2026-06-14',
  },
  {
    id: 'v7',
    storeName: 'Fresh Catch Ibajay',
    ownerName: 'Noel Andrada',
    mobile: '+63 921 660 4419',
    email: 'noelandrada_fish@gmail.com',
    barangay: 'Colasi',
    description:
      'Daily fresh fish, sinigang packs and seafood trays. Application under review.',
    status: 'pending',
    verification: 'unverified',
    plan: 'free',
    subState: 'active',
    ordersCount: 0,
    revenue: 0,
    rating: 0,
    productCount: 9,
    categoryCount: 3,
    joinedAt: '2026-08-21',
  },
  {
    id: 'v8',
    storeName: 'Brew Point Café',
    ownerName: 'Katrina Mendoza',
    mobile: '+63 917 845 2260',
    email: 'kat.brewpoint@gmail.com',
    barangay: 'Poblacion',
    description:
      'Barako coffee, frappes and rice-box breakfasts near the municipal hall.',
    status: 'pending',
    verification: 'unverified',
    plan: 'plus',
    subState: 'active',
    ordersCount: 0,
    revenue: 0,
    rating: 0,
    productCount: 16,
    categoryCount: 5,
    joinedAt: '2026-08-23',
  },
  {
    id: 'v9',
    storeName: 'Golden Spoon Catering',
    ownerName: 'Divine Castro',
    mobile: '+63 908 337 5126',
    email: 'divine.goldenspoon@yahoo.com',
    barangay: 'Agbago',
    description: 'Party trays and event catering for fiestas and birthdays.',
    status: 'suspended',
    verification: 'unverified',
    plan: 'free',
    subState: 'expired',
    ordersCount: 64,
    revenue: 47880,
    rating: 4.1,
    productCount: 8,
    categoryCount: 2,
    joinedAt: '2026-06-30',
  },
  {
    id: 'v10',
    storeName: "Mama Rosa's Sutukil",
    ownerName: 'Rosario Bellosillo',
    mobile: '+63 926 471 8893',
    email: 'rosabellsutukil@gmail.com',
    barangay: 'Naisud',
    description: 'Sugba-tuwa-kilaw platters and family bilao sets.',
    status: 'rejected',
    verification: 'unverified',
    plan: 'free',
    subState: 'expired',
    ordersCount: 0,
    revenue: 0,
    rating: 0,
    productCount: 0,
    categoryCount: 0,
    joinedAt: '2026-08-12',
    rejectionReason:
      'Incomplete business permit documents. Owner may resubmit with DTI registration and sanitary permit.',
  },
]

const vendorById = new Map(vendors.map((v) => [v.id, v]))

export function getVendor(id: string): Vendor | undefined {
  return vendorById.get(id)
}

// ---------------------------------------------------------------- Customers

const customerNames = [
  'Andrea Legaspi', 'Marco Villanueva', 'Christine dela Cruz', 'Paolo Esparagoza',
  'Liezl Bataller', 'Ramonito Tuyor', 'Sheena Mae Ibarra', 'Ferdinand Alcantara',
  'Grace Ann Zulueta', 'Dennis Sumbilon', 'Rowena Gadrinab', 'Michael Oquendo',
  'Aileen Rose Fabregas', 'Jonathan Mosqueda', 'Karen Ureta', 'Alfredo Bisnar Jr.',
  'Melinda Cañete', 'Ryan Anthony Galvez', 'Judith Maravillas', 'Elmer Tubongbanua',
  'Precious Reaño', 'Gilbert Amarille', 'Hazel Fuentes', 'Arnel Pacheco',
]

export const customers: Customer[] = customerNames.map((name, i) => {
  const ordersCount = int(1, 34)
  return {
    id: `c${i + 1}`,
    name,
    mobile: `+63 ${pick(['917', '928', '906', '939', '995'])} ${int(100, 999)} ${int(1000, 9999)}`,
    email: `${name.toLowerCase().split(' ').slice(0, 2).join('.')}@gmail.com`,
    barangay: pick([
      'Poblacion', 'Naisud', 'Bugtong Bato', 'Riviera', 'Agbago', 'Aparicio', 'Colasi',
    ]),
    ordersCount,
    totalSpent: ordersCount * int(120, 480),
    joinedAt: daysAgo(int(5, 110)).toISOString().slice(0, 10),
    lastOrderAt: daysAgo(int(0, 12)).toISOString().slice(0, 10),
  }
})

const customerMap = new Map(customers.map((c) => [c.id, c]))

// ---------------------------------------------------------------- Menu names

const menuByVendor: Record<string, string[]> = {
  v1: ['Inihaw na Panga', 'Buttered Garlic Shrimp', 'Sinigang na Lapu-Lapu', 'Calamari Frito', 'Grilled Squid Bilao', 'Baked Scallops'],
  v2: ['Adobo Rice Bowl', 'Pancit Bihon Guisado', 'Pork Sinigang', 'Tortang Talong', 'Chicken Arroz Caldo', 'Lumpiang Shanghai (12pcs)'],
  v3: ['Pandesal (dozen)', 'Ensaymada Special', 'Spanish Bread (6pcs)', 'Cheese Cupcake', 'Ube Roll Slice'],
  v4: ['Lechon Kawali Bilao', 'Lechon Paksiw', 'Crispy Pata Party Tray', 'Inihaw na Liempo', 'Chicharon Bulaklak'],
  v5: ['Halo-Halo Special', 'Mais Con Yelo', 'Banana Cue (3 sticks)', 'Turon with Langka', 'Sago at Gulaman'],
  v6: ['Quarter Pounder Burger', 'Cheeseburger Deluxe', 'Loaded Fries', 'Chicken Wings (6pcs)', 'Iced Coffee Float'],
}

const allMenuItems = Object.values(menuByVendor).flat()

// ---------------------------------------------------------------- Orders

let orderSeq = 1088
let orderCounter = orderSeq

function makeOrder(status: OrderStatus, placedDaysAgo: number): Order {
  const vendor = pick([vendors[0], vendors[0], vendors[1], vendors[2], vendors[3], vendors[4], vendors[5]])
  const customer = pick(customers)
  const itemCount = int(1, 4)
  const items: OrderItem[] = []
  const menu = menuByVendor[vendor.id] ?? allMenuItems
  for (let i = 0; i < itemCount; i++) {
    items.push({
      name: pick(menu),
      qty: int(1, 3),
      price: int(45, 320),
    })
  }
  const method: Method = pick(['delivery', 'delivery', 'pickup', 'scheduled'])
  const payment: Payment = method === 'pickup' ? 'cash_on_pickup' : 'cod'
  const subtotal = items.reduce((s, it) => s + it.price * it.qty, 0)
  const deliveryFee = method === 'delivery' ? pick([20, 30, 30, 50]) : 0
  const placedAt = daysAgo(placedDaysAgo)
  const scheduledFor =
    method === 'scheduled'
      ? new Date(placedAt.getTime() + 36 * 3600 * 1000)
      : undefined
  return {
    id: `ORD-${orderSeq++}`,
    vendorId: vendor.id,
    customerId: customer.id,
    items,
    subtotal,
    deliveryFee,
    total: subtotal + deliveryFee,
    method,
    payment,
    status,
    placedAt,
    scheduledFor,
    address: `${customer.name.split(' ')[0]}'s address, Brgy. ${customer.barangay}, Ibajay, Aklan`,
    cancelReason:
      status === 'cancelled'
        ? pick([
            'Customer changed their mind before preparation started.',
            'Duplicate order placed by mistake.',
            'Vendor ran out of stock for a key item.',
          ])
        : undefined,
  }
}

function buildOrders(): Order[] {
  const list: Order[] = []
  // Historical completed / cancelled over ~40 days.
  for (let i = 0; i < 96; i++) {
    list.push(makeOrder(rand() < 0.12 ? 'cancelled' : 'completed', int(1, 40)))
  }
  // Yesterday & today: spread across non-terminal statuses.
  const recentMix: OrderStatus[] = [
    'pending', 'accepted', 'preparing', 'ready', 'out_for_delivery',
    'delivered', 'completed', 'pending', 'preparing', 'out_for_delivery',
    'delivered', 'accepted', 'ready', 'pending', 'delivered',
  ]
  for (const st of recentMix) {
    list.push(makeOrder(st, int(0, 1)))
  }
  return list.sort((a, b) => b.placedAt.getTime() - a.placedAt.getTime())
}

export const orders: Order[] = buildOrders()

export function isLive(status: OrderStatus): boolean {
  return status !== 'completed' && status !== 'cancelled' && status !== 'delivered'
}

// ---------------------------------------------------------------- Reviews

export const reviews: Review[] = [
  { id: 'r1', vendorId: 'v1', customerName: 'Andrea Legaspi', rating: 5, comment: 'Grilled panga was huge and smoky. Sulit sa price!', responded: true, flagged: false, hidden: false, createdAt: '2026-08-22' },
  { id: 'r2', vendorId: 'v1', customerName: 'Michael Oquendo', rating: 4, comment: 'Scallops were great, delivery arrived a bit late though.', responded: true, flagged: false, hidden: false, createdAt: '2026-08-20' },
  { id: 'r3', vendorId: 'v1', customerName: 'Anonymous', rating: 2, comment: 'FREE VIAGRA CLICK HERE www.suspicious-deals.example', responded: false, flagged: true, hidden: false, createdAt: '2026-08-19' },
  { id: 'r4', vendorId: 'v2', customerName: 'Sheena Mae Ibarra', rating: 5, comment: 'Best pancit in town. Laging init pa rin pag dating.', responded: true, flagged: false, hidden: false, createdAt: '2026-08-21' },
  { id: 'r5', vendorId: 'v2', customerName: 'Dennis Sumbilon', rating: 4, comment: 'Lumpiang shanghai is consistent. Will reorder.', responded: false, flagged: false, hidden: false, createdAt: '2026-08-18' },
  { id: 'r6', vendorId: 'v3', customerName: 'Grace Ann Zulueta', rating: 5, comment: 'Pandesal still warm every morning. A staple na talaga.', responded: true, flagged: false, hidden: false, createdAt: '2026-08-23' },
  { id: 'r7', vendorId: 'v3', customerName: 'Anonymous', rating: 1, comment: 'Cheap replica watches!!! DM me now', responded: false, flagged: true, hidden: true, createdAt: '2026-08-15' },
  { id: 'r8', vendorId: 'v4', customerName: 'Ramonito Tuyor', rating: 5, comment: 'Ordered lechon for my son\'s birthday. Sabaw pa lang sulit na.', responded: true, flagged: false, hidden: false, createdAt: '2026-08-17' },
  { id: 'r9', vendorId: 'v5', customerName: 'Karen Ureta', rating: 4, comment: 'Halo-halo special hits different on hot afternoons.', responded: false, flagged: false, hidden: false, createdAt: '2026-08-19' },
  { id: 'r10', vendorId: 'v5', customerName: 'Jonathan Mosqueda', rating: 3, comment: 'Medyo malata yung banana cue this time. Still okay.', responded: true, flagged: false, hidden: false, createdAt: '2026-08-16' },
  { id: 'r11', vendorId: 'v6', customerName: 'Ryan Anthony Galvez', rating: 4, comment: 'Loaded fries are generous. Burger patty could be juicier.', responded: false, flagged: false, hidden: false, createdAt: '2026-08-21' },
  { id: 'r12', vendorId: 'v6', customerName: 'Anonymous', rating: 1, comment: 'Earn 50k daily from home! Join t.me/getrichquickx', responded: false, flagged: true, hidden: false, createdAt: '2026-08-22' },
  { id: 'r13', vendorId: 'v1', customerName: 'Liezl Bataller', rating: 5, comment: 'The buttered garlic shrimp never misses.', responded: false, flagged: false, hidden: false, createdAt: '2026-08-23' },
  { id: 'r14', vendorId: 'v2', customerName: 'Elmer Tubongbanua', rating: 4, comment: 'Arroz caldo perfect for rainy nights.', responded: false, flagged: false, hidden: false, createdAt: '2026-08-14' },
]

// ---------------------------------------------------------------- Categories

export const categories: Category[] = [
  { id: 'cat1', name: 'Rice Meals', productCount: 42, vendorCount: 6, active: true },
  { id: 'cat2', name: 'BBQ & Grills', productCount: 27, vendorCount: 4, active: true },
  { id: 'cat3', name: 'Seafood', productCount: 19, vendorCount: 2, active: true },
  { id: 'cat4', name: 'Merienda', productCount: 23, vendorCount: 4, active: true },
  { id: 'cat5', name: 'Bread & Pastries', productCount: 16, vendorCount: 1, active: true },
  { id: 'cat6', name: 'Beverages', productCount: 21, vendorCount: 4, active: true },
  { id: 'cat7', name: 'Party Trays', productCount: 9, vendorCount: 2, active: true },
  { id: 'cat8', name: 'Combo Meals', productCount: 0, vendorCount: 0, active: false },
]

// ---------------------------------------------------------------- Staff

export const staffUsers: StaffUser[] = [
  { id: 's1', name: 'Piolo Mangilog', email: 'piolo@ibaeats.ph', role: 'developer', status: 'active', lastActiveAt: new Date() },
  { id: 's2', name: 'Aileen Vega', email: 'aileen@ibaeats.ph', role: 'manager', status: 'active', lastActiveAt: daysAgo(0, 9) },
  { id: 's3', name: 'Marco Dizon', email: 'marco@ibaeats.ph', role: 'staff', status: 'active', lastActiveAt: daysAgo(0, 8) },
  { id: 's4', name: 'Grace Lim', email: 'grace@ibaeats.ph', role: 'staff', status: 'invited', lastActiveAt: daysAgo(3, 14) },
  { id: 's5', name: 'Ramon Cruz', email: 'ramon@ibaeats.ph', role: 'manager', status: 'disabled', lastActiveAt: daysAgo(21, 11) },
]

// ---------------------------------------------------------------- Audit log

export const auditLog: AuditEntry[] = [
  { id: 'a1', at: daysAgo(0, 8), actorName: 'Aileen Vega', actorRole: 'manager', action: 'vendor.approved', target: 'Fresh Catch Ibajay', detail: 'Application documents reviewed and approved.' },
  { id: 'a2', at: daysAgo(0, 7), actorName: 'System', actorRole: 'developer', action: 'subscription.grace_started', target: 'Ibajay Bakery', detail: 'Plus plan expired, 7-day grace period started.' },
  { id: 'a3', at: daysAgo(1, 15), actorName: 'Aileen Vega', actorRole: 'manager', action: 'vendor.rejected', target: "Mama Rosa's Sutukil", detail: 'Incomplete business permit documents.' },
  { id: 'a4', at: daysAgo(1, 10), actorName: 'Piolo Mangilog', actorRole: 'developer', action: 'vendor.suspended', target: 'Golden Spoon Catering', detail: 'Repeated late-preparation complaints from customers.' },
  { id: 'a5', at: daysAgo(2, 13), actorName: 'Marco Dizon', actorRole: 'staff', action: 'review.hidden', target: 'Ibajay Bakery', detail: 'Spam review flagged by auto-filter.' },
  { id: 'a6', at: daysAgo(2, 9), actorName: 'Piolo Mangilog', actorRole: 'developer', action: 'settings.updated', target: 'Delivery fee tiers', detail: 'Adjusted 3–5 KM tier from ₱40 to ₱50.' },
  { id: 'a7', at: daysAgo(3, 16), actorName: 'Aileen Vega', actorRole: 'manager', action: 'vendor.verified', target: "Kusina ni Ining", detail: 'DTI and sanitary permits verified on-site.' },
  { id: 'a8', at: daysAgo(4, 11), actorName: 'System', actorRole: 'developer', action: 'order.cancelled', target: 'ORD-1042', detail: 'Auto-cancelled: no vendor response within 15 minutes.' },
]

export function pushAudit(entry: Omit<AuditEntry, 'id' | 'at'>) {
  auditLog.unshift({ ...entry, id: `a${auditLog.length + 1}`, at: new Date() })
}

// ---------------------------------------------------------------- Derived selectors

export function kpis(): Kpis {
  const todayStart = new Date()
  todayStart.setHours(0, 0, 0, 0)
  const yesterdayStart = new Date(todayStart)
  yesterdayStart.setDate(yesterdayStart.getDate() - 1)

  let todayOrders = 0
  let todayRevenue = 0
  let yesterdayOrders = 0
  let yesterdayRevenue = 0

  for (const o of orders) {
    if (o.status === 'cancelled') continue
    if (o.placedAt >= todayStart) {
      todayOrders++
      todayRevenue += o.total
    } else if (o.placedAt >= yesterdayStart) {
      yesterdayOrders++
      yesterdayRevenue += o.total
    }
  }

  const monthAgo = new Date(Date.now() - 30 * 24 * 3600 * 1000)
  const activeCustomers = new Set(
    orders.filter((o) => o.placedAt >= monthAgo).map((o) => o.customerId),
  ).size

  return {
    todayOrders,
    todayOrdersDelta: pctDelta(todayOrders, yesterdayOrders),
    todayRevenue,
    todayRevenueDelta: pctDelta(todayRevenue, yesterdayRevenue),
    activeVendors: vendors.filter((v) => v.status === 'approved').length,
    verifiedVendors: vendors.filter((v) => v.status === 'approved' && v.verification === 'verified').length,
    activeCustomers,
    pendingApprovals: vendors.filter((v) => v.status === 'pending').length,
    liveOrders: orders.filter((o) => isLive(o.status)).length,
  }
}

function pctDelta(cur: number, prev: number): number {
  if (prev === 0) return cur > 0 ? 100 : 0
  return ((cur - prev) / prev) * 100
}

export function revenueSeries(days: number) {
  const out: { label: string; revenue: number; orders: number }[] = []
  const now = new Date()
  now.setHours(23, 59, 59, 0)
  for (let i = days - 1; i >= 0; i--) {
    const dayStart = new Date(now)
    dayStart.setDate(dayStart.getDate() - i)
    dayStart.setHours(0, 0, 0, 0)
    const dayEnd = new Date(dayStart)
    dayEnd.setDate(dayEnd.getDate() + 1)
    const dayOrders = orders.filter(
      (o) => o.status !== 'cancelled' && o.placedAt >= dayStart && o.placedAt < dayEnd,
    )
    out.push({
      label: dayStart.toLocaleDateString('en-PH', { month: 'short', day: 'numeric' }),
      revenue: dayOrders.reduce((s, o) => s + o.total, 0),
      orders: dayOrders.length,
    })
  }
  return out
}

export function monthlySeries(monthsBack: number) {
  const out: { label: string; revenue: number; orders: number }[] = []
  for (let i = monthsBack - 1; i >= 0; i--) {
    const ref = new Date()
    ref.setDate(1)
    ref.setMonth(ref.getMonth() - i)
    const start = new Date(ref.getFullYear(), ref.getMonth(), 1)
    const end = new Date(ref.getFullYear(), ref.getMonth() + 1, 1)
    const monthOrders = orders.filter(
      (o) =>
        o.status !== 'cancelled' &&
        o.placedAt.getTime() >= Math.max(start.getTime(), ordersMinTime()) &&
        o.placedAt < end,
    )
    out.push({
      label: start.toLocaleDateString('en-PH', { month: 'short' }),
      revenue: monthOrders.reduce((s, o) => s + o.total, 0),
      orders: monthOrders.length,
    })
  }
  return out
}

function ordersMinTime(): number {
  return Date.now() - 45 * 24 * 3600 * 1000
}

export function topVendors(limit: number) {
  return [...vendors]
    .filter((v) => v.status === 'approved')
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, limit)
}

export function bestSellers(limit: number): ProductSales[] {
  const agg = new Map<string, ProductSales>()
  for (const o of orders) {
    if (o.status === 'cancelled') continue
    const vendor = getVendor(o.vendorId)
    for (const item of o.items) {
      const key = `${o.vendorId}:${item.name}`
      const cur = agg.get(key) ?? {
        name: item.name,
        vendorId: o.vendorId,
        vendorName: vendor?.storeName ?? '',
        unitsSold: 0,
        revenue: 0,
      }
      cur.unitsSold += item.qty
      cur.revenue += item.qty * item.price
      agg.set(key, cur)
    }
  }
  return [...agg.values()].sort((a, b) => b.unitsSold - a.unitsSold).slice(0, limit)
}

export function customerById(id: string): Customer | undefined {
  return customerMap.get(id)
}

// ---------------------------------------------------------------- Live simulation

let simSeq = 1091

/**
 * Advances mock activity once per auto-refresh tick: moves random live
 * orders one step forward through the status flow and occasionally drops
 * in a brand-new pending order. This makes the dashboard feel alive
 * without any real backend connection (per Stage 1 rules).
 */
export function tickSimulation(): void {
  const live = orders.filter((o) => isLive(o.status))
  const advance = live[Math.floor(Math.random() * live.length)]
  if (advance && Math.random() < 0.75) {
    const idx = ORDER_FLOW.indexOf(advance.status)
    if (idx >= 0 && idx < ORDER_FLOW.length - 1) {
      advance.status = ORDER_FLOW[idx + 1]
    } else if (advance.status === 'delivered') {
      advance.status = 'completed'
    }
  }

  if (Math.random() < 0.3) {
    const o = makeOrder('pending', 0)
    o.id = `ORD-${simSeq++}`
    orders.unshift(o)
  }
}
