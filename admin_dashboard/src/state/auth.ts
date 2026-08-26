import { createContext, useContext } from 'react'
import { api, clearToken, getToken, setToken } from '../lib/api'
import type { Role } from '../types'

export interface AdminUser {
  name: string
  email: string
  role: Role
}

/** Action-level permissions. The backend has a single `admin` role; the
 * console maps it to the developer (full-access) persona. Manager/staff
 * personas return when the backend grows granular admin roles. */
const PERMISSIONS: Record<string, Role[]> = {
  'vendors.approve': ['developer', 'manager'],
  'vendors.verify': ['developer', 'manager'],
  'categories.manage': ['developer', 'manager'],
  'reviews.moderate': ['developer', 'manager'],
  'staff.manage': ['developer'],
  'settings.edit': ['developer'],
}

export function can(role: Role, permission: keyof typeof PERMISSIONS | string): boolean {
  return PERMISSIONS[permission]?.includes(role) ?? false
}

export function roleLabel(role: Role): string {
  return role.charAt(0).toUpperCase() + role.slice(1)
}

export interface AuthContextValue {
  user: AdminUser | null
  /** Real login against POST /auth/login — the account must carry the
   * backend's `admin` role. */
  signInWithPassword: (email: string, password: string) => Promise<void>
  signOut: () => void
}

export const AuthContext = createContext<AuthContextValue>({
  user: null,
  signInWithPassword: async () => undefined,
  signOut: () => undefined,
})

export function useAuth(): AuthContextValue {
  return useContext(AuthContext)
}

/** Restores a saved session by validating the stored token /auth/me. */
export async function restoreAdminSession(): Promise<AdminUser | null> {
  if (!getToken()) return null
  try {
    const me = await api<{ id: string; full_name: string; email: string; role: string }>('/auth/me')
    if (me.role !== 'admin') {
      clearToken()
      return null
    }
    return { name: me.full_name, email: me.email, role: 'developer' }
  } catch {
    return null
  }
}

export async function loginAdmin(mobileNumber: string, password: string): Promise<AdminUser> {
  const tokens = await api<{ access_token: string; refresh_token: string }>('/auth/login', {
    method: 'POST',
    body: { mobile_number: mobileNumber, password },
  })
  setToken(tokens.access_token)

  try {
    const me = await api<{ full_name: string; email: string; role: string }>('/auth/me')
    if (me.role !== 'admin') {
      clearToken()
      throw new Error('This account is not an administrator.')
    }
    return { name: me.full_name, email: me.email, role: 'developer' }
  } catch (e) {
    clearToken()
    throw e
  }
}
