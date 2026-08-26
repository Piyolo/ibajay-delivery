import type { Vendor } from '../types'

/** Vendor row shape returned by GET /api/v1/admin/vendors. */
export interface AdminVendorRow {
  id: string
  store_name: string
  address: string
  logo_url: string | null
  is_open: boolean
  is_paused: boolean
  is_verified: boolean
  average_rating: number
  total_reviews: number
  owner_name: string | null
  owner_email: string | null
  owner_mobile: string | null
  menu_count: number
}

export type VendorRuntimeStatus = 'open' | 'closed' | 'paused'

export function vendorStatusOf(v: Pick<AdminVendorRow, 'is_open' | 'is_paused'>): VendorRuntimeStatus {
  if (v.is_paused) return 'paused'
  return v.is_open ? 'open' : 'closed'
}

export function statusToneOf(s: string): 'green' | 'amber' | 'red' | 'gray' | 'blue' {
  switch (s) {
    case 'open':
    case 'approved':
    case 'active':
      return 'green'
    case 'closed':
    case 'pending':
    case 'grace':
      return 'amber'
    case 'paused':
    case 'rejected':
    case 'suspended':
    case 'expired':
      return 'red'
    default:
      return 'gray'
  }
}

export function statusLabelOf(s: string): string {
  return s.charAt(0).toUpperCase() + s.slice(1)
}

/** Compatibility shim for pages still on prototype data. */
export function legacyVendorStatus(v: Vendor): string {
  return v.status
}
