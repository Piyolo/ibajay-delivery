import { NavLink } from 'react-router-dom'
import {
  BarChart3,
  ClipboardList,
  Flame,
  FolderTree,
  LayoutDashboard,
  MessageSquareWarning,
  Settings,
  ShieldCheck,
  Star,
  Store,
  Users,
} from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import type { Role } from '../../types'
import { useAuth } from '../../state/auth'
import { useAsyncData } from '../../state/live'
import { api } from '../../lib/api'

interface OverviewMini {
  orders_today: number
  orders_active: number
  vendors_total: number
  vendors_verified: number
  customers_total: number
}

interface NavItem {
  to: string
  label: string
  icon: LucideIcon
  roles: Role[]
  end?: boolean
}

interface NavSection {
  label: string
  items: NavItem[]
}

const ALL: Role[] = ['developer', 'manager', 'staff']
const DEV_ONLY: Role[] = ['developer']
const DEV_MGR: Role[] = ['developer', 'manager']

const SECTIONS: NavSection[] = [
  {
    label: '',
    items: [{ to: '/', label: 'Dashboard', icon: LayoutDashboard, roles: ALL }],
  },
  {
    label: 'Operations',
    items: [
      { to: '/orders', label: 'Orders', icon: ClipboardList, roles: ALL },
      { to: '/vendors', label: 'Vendors', icon: Store, roles: ALL },
      { to: '/customers', label: 'Customers', icon: Users, roles: ALL },
    ],
  },
  {
    label: 'Analytics',
    items: [
      { to: '/analytics', label: 'Overview', icon: BarChart3, roles: ALL },
      { to: '/analytics/sales', label: 'Sales', icon: BarChart3, roles: ALL },
      { to: '/analytics/vendors', label: 'Vendors', icon: Store, roles: ALL },
    ],
  },
  {
    label: 'Management',
    items: [
      { to: '/staff', label: 'Staff', icon: ShieldCheck, roles: DEV_MGR },
      { to: '/categories', label: 'Categories', icon: FolderTree, roles: DEV_MGR },
      { to: '/reviews', label: 'Reviews', icon: MessageSquareWarning, roles: ALL },
    ],
  },
  {
    label: 'Platform',
    items: [
      { to: '/subscriptions', label: 'Subscriptions', icon: Star, roles: DEV_MGR },
      { to: '/settings', label: 'Settings', icon: Settings, roles: DEV_ONLY },
      { to: '/audit-log', label: 'Audit Logs', icon: ClipboardList, roles: DEV_ONLY },
    ],
  },
]

export function Sidebar() {
  const { user } = useAuth()
  const role = user?.role ?? 'staff'
  const overview = useAsyncData(async () => {
    try {
      return await api<OverviewMini>('/admin/overview')
    } catch {
      return null
    }
  }).data
  const pending = overview ? Math.max(0, overview.vendors_total - overview.vendors_verified) : 0

  return (
    <aside className="sidebar">
      <div className="sb-brand">
        <div className="mark">
          <Flame size={16} />
        </div>
        <div>
          <div className="name">Ibajay Eats</div>
          <div className="sub">Admin Console</div>
        </div>
      </div>

      <nav className="sb-scroll">
        {SECTIONS.map((section, si) => {
          const items = section.items.filter((it) => it.roles.includes(role))
          if (!items.length) return null
          return (
            <div key={si}>
              {section.label && <div className="sb-label">{section.label}</div>}
              {items.map((it) => (
                <NavLink
                  key={it.to}
                  to={it.to}
                  end={it.to === '/' || it.to.startsWith('/analytics')}
                  className={({ isActive }) =>
                    `sb-item ${isActive ? 'active' : ''}`
                  }
                >
                  <it.icon />
                  {it.label}
                  {it.to === '/vendors' && pending > 0 && (
                    <span className="count">{pending}</span>
                  )}
                </NavLink>
              ))}
            </div>
          )
        })}
      </nav>

      <div className="sb-footer">
        {overview
          ? `${overview.orders_today} orders today · ${overview.orders_active} live`
          : 'Connecting…'}
        <br />
        Live backend · admin console
      </div>
    </aside>
  )
}
