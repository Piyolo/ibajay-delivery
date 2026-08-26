import { useEffect, useMemo, useState } from 'react'
import { HashRouter, Navigate, Route, Routes } from 'react-router-dom'
import type { ReactNode } from 'react'
import { AuthContext, loginAdmin, restoreAdminSession } from './state/auth'
import type { AdminUser } from './state/auth'
import type { Role } from './types'
import { clearToken } from './lib/api'
import { LiveProvider } from './state/live'
import { AdminLayout } from './components/layout/AdminLayout'
import { LoginPage } from './pages/LoginPage'
import { DashboardHomePage } from './pages/DashboardHomePage'
import { VendorsPage } from './pages/VendorsPage'
import { VendorDetailPage } from './pages/VendorDetailPage'
import { OrdersPage } from './pages/OrdersPage'
import { CustomersPage } from './pages/CustomersPage'
import { AnalyticsOverviewPage, VendorAnalyticsPage } from './pages/analytics/AnalyticsPages'
import { SalesAnalyticsPage } from './pages/analytics/SalesAnalyticsPage'
import { StaffPage } from './pages/StaffPage'
import { CategoriesPage } from './pages/CategoriesPage'
import { ReviewsPage } from './pages/ReviewsPage'
import { SubscriptionsPage } from './pages/SubscriptionsPage'
import { SettingsPage } from './pages/SettingsPage'
import { AuditLogPage } from './pages/AuditLogPage'

export default function App() {
  const [user, setUser] = useState<AdminUser | null>(null)
  const [booting, setBooting] = useState(true)

  // Restore the session on load by validating the stored token against
  // /auth/me — closing the tab no longer logs the admin out.
  useEffect(() => {
    let alive = true
    restoreAdminSession().then((restored) => {
      if (!alive) return
      setUser(restored)
      setBooting(false)
    })
    return () => {
      alive = false
    }
  }, [])

  const auth = useMemo(
    () => ({
      user,
      signInWithPassword: async (mobile: string, password: string) => {
        const u = await loginAdmin(mobile, password)
        setUser(u)
      },
      signOut: () => {
        clearToken()
        setUser(null)
      },
    }),
    [user],
  )

  if (booting) {
    return (
      <div className="login-wrap">
        <p className="muted">Restoring session…</p>
      </div>
    )
  }

  return (
    <AuthContext.Provider value={auth}>
      <LiveProvider>
        <HashRouter>
          <Routes>
            <Route
              path="/login"
              element={user ? <Navigate to="/" replace /> : <LoginPage />}
            />
            <Route
              path="*"
              element={
                user ? (
                  <AdminLayout>
                    <GuardedRoutes role={user.role} />
                  </AdminLayout>
                ) : (
                  <Navigate to="/login" replace />
                )
              }
            />
          </Routes>
        </HashRouter>
      </LiveProvider>
    </AuthContext.Provider>
  )
}

function GuardedRoutes({ role }: { role: Role }) {
  return (
    <Routes>
      <Route path="/" element={<DashboardHomePage />} />
      <Route path="/orders" element={<OrdersPage />} />
      <Route path="/vendors" element={<VendorsPage />} />
      <Route path="/vendors/:id" element={<VendorDetailPage />} />
      <Route path="/customers" element={<CustomersPage />} />
      <Route path="/analytics" element={<AnalyticsOverviewPage />} />
      <Route path="/analytics/sales" element={<SalesAnalyticsPage />} />
      <Route path="/analytics/vendors" element={<VendorAnalyticsPage />} />

      <Route
        path="/staff"
        element={
          <RequireRole role={role} allow={['developer', 'manager']}>
            <StaffPage />
          </RequireRole>
        }
      />
      <Route
        path="/categories"
        element={
          <RequireRole role={role} allow={['developer', 'manager']}>
            <CategoriesPage />
          </RequireRole>
        }
      />
      <Route path="/reviews" element={<ReviewsPage />} />
      <Route
        path="/subscriptions"
        element={
          <RequireRole role={role} allow={['developer', 'manager']}>
            <SubscriptionsPage />
          </RequireRole>
        }
      />
      <Route
        path="/settings"
        element={
          <RequireRole role={role} allow={['developer']}>
            <SettingsPage />
          </RequireRole>
        }
      />
      <Route
        path="/audit-log"
        element={
          <RequireRole role={role} allow={['developer']}>
            <AuditLogPage />
          </RequireRole>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

function RequireRole({
  role,
  allow,
  children,
}: {
  role: Role
  allow: Role[]
  children: ReactNode
}) {
  if (!allow.includes(role)) {
    return <Navigate to="/" replace />
  }
  return <>{children}</>
}
