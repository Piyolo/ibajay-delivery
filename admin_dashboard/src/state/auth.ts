import { createContext, useContext } from 'react'
import type { Role } from '../types'

export interface AdminUser {
  name: string
  email: string
  role: Role
}

export const DEMO_USERS: Record<Role, AdminUser> = {
  developer: { name: 'Piolo Mangilog', email: 'piolo@ibaeats.ph', role: 'developer' },
  manager: { name: 'Aileen Vega', email: 'aileen@ibaeats.ph', role: 'manager' },
  staff: { name: 'Marco Dizon', email: 'marco@ibaeats.ph', role: 'staff' },
}

/** Action-level permissions, per the Beta admin spec. */
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
  signIn: (role: Role) => void
  signOut: () => void
}

export const AuthContext = createContext<AuthContextValue>({
  user: null,
  signIn: () => undefined,
  signOut: () => undefined,
})

export function useAuth(): AuthContextValue {
  return useContext(AuthContext)
}
