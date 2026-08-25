import { useEffect, useState } from 'react'
import { LogOut, RefreshCw } from 'lucide-react'
import { useLocation } from 'react-router-dom'
import { roleLabel, useAuth } from '../../state/auth'
import { useLive } from '../../state/live'
import { timeAgo } from '../../lib/format'

const TITLES: Array<[string, string]> = [
  ['/analytics/sales', 'Analytics / Sales'],
  ['/analytics/vendors', 'Analytics / Vendors'],
  ['/analytics', 'Analytics / Overview'],
  ['/vendors/:id', 'Vendors'],
  ['/vendors', 'Vendors'],
  ['/orders', 'Orders'],
  ['/customers', 'Customers'],
  ['/staff', 'Staff'],
  ['/categories', 'Categories'],
  ['/reviews', 'Reviews'],
  ['/subscriptions', 'Subscriptions'],
  ['/settings', 'Platform Settings'],
  ['/audit-log', 'Audit Logs'],
  ['/', 'Dashboard'],
]

export function Topbar() {
  const { user, signOut } = useAuth()
  const location = useLocation()
  const { lastUpdatedAt, tick } = useLive()
  const [, force] = useState(0)

  useEffect(() => {
    const t = window.setInterval(() => force((n) => n + 1), 5000)
    return () => window.clearInterval(t)
  }, [])

  const entry =
    TITLES.find(([path]) =>
      path.includes(':')
        ? location.pathname.match(new RegExp(`^${path.replace(':id', '[^/]+')}$`))
        : location.pathname === path,
    ) ?? TITLES[TITLES.length - 1]

  return (
    <header className="topbar">
      <span className="tb-breadcrumb">Admin</span>
      <span className="tb-title">/ {entry[1]}</span>
      <div className="tb-spacer" />
      <div className="tb-refresh" title="Simulated auto-refresh every 30 seconds">
        <RefreshCw key={tick} size={13} className="spin-once" style={{ animation: 'spin 700ms ease' }} />
        Updated {timeAgo(lastUpdatedAt)}
      </div>
      <div className="tb-user">
        <div className="avatar dark">{userInitials(user?.name ?? '')}</div>
        <div className="meta">
          <div className="n">{user?.name}</div>
          <div className="r">{user ? roleLabel(user.role) : ''}</div>
        </div>
        <button className="icon-btn" title="Sign out" onClick={signOut}>
          <LogOut />
        </button>
      </div>
    </header>
  )
}

function userInitials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0])
    .join('')
    .toUpperCase()
}
