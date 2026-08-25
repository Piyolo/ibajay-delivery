export type Role = 'developer' | 'manager' | 'staff'

export type VendorStatus = 'pending' | 'approved' | 'rejected' | 'suspended'
export type Verification = 'verified' | 'unverified'
export type Plan = 'free' | 'plus' | 'founding'
export type SubState = 'active' | 'grace' | 'expired'

export interface Vendor {
  id: string
  storeName: string
  ownerName: string
  mobile: string
  email: string
  barangay: string
  description: string
  status: VendorStatus
  verification: Verification
  plan: Plan
  subState: SubState
  renewalDate?: string
  ordersCount: number
  revenue: number
  rating: number
  productCount: number
  categoryCount: number
  joinedAt: string
  pilot?: boolean
  rejectionReason?: string
}

export type OrderStatus =
  | 'pending'
  | 'accepted'
  | 'preparing'
  | 'ready'
  | 'out_for_delivery'
  | 'delivered'
  | 'completed'
  | 'cancelled'

export const ORDER_FLOW: OrderStatus[] = [
  'pending',
  'accepted',
  'preparing',
  'ready',
  'out_for_delivery',
  'delivered',
  'completed',
]

export type Method = 'delivery' | 'pickup' | 'scheduled'
export type Payment = 'cod' | 'cash_on_pickup'

export interface OrderItem {
  name: string
  qty: number
  price: number
}

export interface Order {
  id: string
  vendorId: string
  customerId: string
  items: OrderItem[]
  subtotal: number
  deliveryFee: number
  total: number
  method: Method
  payment: Payment
  status: OrderStatus
  placedAt: Date
  scheduledFor?: Date
  address: string
  cancelReason?: string
}

export interface Customer {
  id: string
  name: string
  mobile: string
  email: string
  barangay: string
  ordersCount: number
  totalSpent: number
  joinedAt: string
  lastOrderAt: string
}

export interface StaffUser {
  id: string
  name: string
  email: string
  role: Role
  status: 'active' | 'invited' | 'disabled'
  lastActiveAt: Date
}

export interface Review {
  id: string
  vendorId: string
  customerName: string
  rating: number
  comment: string
  responded: boolean
  flagged: boolean
  hidden: boolean
  createdAt: string
}

export interface Category {
  id: string
  name: string
  productCount: number
  vendorCount: number
  active: boolean
}

export interface AuditEntry {
  id: string
  at: Date
  actorName: string
  actorRole: Role
  action: string
  target: string
  detail: string
}

export interface ProductSales {
  name: string
  vendorId: string
  vendorName: string
  unitsSold: number
  revenue: number
}

export interface Kpis {
  todayOrders: number
  todayOrdersDelta: number
  todayRevenue: number
  todayRevenueDelta: number
  activeVendors: number
  verifiedVendors: number
  activeCustomers: number
  pendingApprovals: number
  liveOrders: number
}

export interface Point {
  label: string
  revenue: number
  orders: number
}
