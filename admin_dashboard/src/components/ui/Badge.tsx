import type { ReactNode } from 'react'

type Tone = 'gray' | 'green' | 'amber' | 'red' | 'blue' | 'purple' | 'orange'

const TONES: Record<Tone, string> = {
  gray: 'b-gray',
  green: 'b-green',
  amber: 'b-amber',
  red: 'b-red',
  blue: 'b-blue',
  purple: 'b-purple',
  orange: 'b-orange',
}

export function Badge({
  tone = 'gray',
  dot = true,
  children,
}: {
  tone?: Tone
  dot?: boolean
  children: ReactNode
}) {
  return (
    <span className={`badge ${TONES[tone]}`}>
      {dot && <span className="dot" />}
      {children}
    </span>
  )
}

export function statusTone(status: string): Tone {
  switch (status) {
    case 'approved':
    case 'verified':
    case 'completed':
    case 'delivered':
    case 'active':
      return 'green'
    case 'pending':
    case 'grace':
      return 'amber'
    case 'rejected':
    case 'suspended':
    case 'cancelled':
    case 'expired':
    case 'disabled':
      return 'red'
    case 'accepted':
      return 'blue'
    case 'preparing':
      return 'purple'
    case 'ready':
      return 'green'
    case 'out_for_delivery':
      return 'orange'
    default:
      return 'gray'
  }
}

export function statusLabel(status: string): string {
  return status.replaceAll('_', ' ')
}
