import type { CSSProperties, ReactNode } from 'react'

export { Badge, statusLabel, statusTone } from './Badge'

export function Card({
  children,
  style,
  className,
}: {
  children: ReactNode
  style?: CSSProperties
  className?: string
}) {
  return (
    <div className={`card ${className ?? ''}`} style={style}>
      {children}
    </div>
  )
}

export function CardHead({
  title,
  action,
}: {
  title: string
  action?: ReactNode
}) {
  return (
    <div className="card-head">
      <h3>{title}</h3>
      {action}
    </div>
  )
}

export function KpiCard({
  label,
  value,
  delta,
  deltaGoodDirection = 'up',
}: {
  label: string
  value: string | number
  delta?: number
  deltaGoodDirection?: 'up' | 'down'
}) {
  let deltaEl = null
  if (delta !== undefined) {
    const rounded = Math.round(delta * 10) / 10
    const cls =
      Math.abs(rounded) < 0.05
        ? 'flat'
        : (rounded > 0) === (deltaGoodDirection === 'up')
          ? 'up'
          : 'down'
    const arrow = rounded > 0 ? '▲' : rounded < 0 ? '▼' : ''
    deltaEl = (
      <span className={`delta ${cls}`}>
        {arrow} {Math.abs(rounded)}% vs yesterday
      </span>
    )
  }
  return (
    <div className="card kpi">
      <div className="label">{label}</div>
      <div className="value">{value}</div>
      {deltaEl}
    </div>
  )
}

export function PageHeader({
  title,
  description,
  actions,
}: {
  title: string
  description?: string
  actions?: ReactNode
}) {
  return (
    <div className="page-head">
      <div>
        <h1>{title}</h1>
        {description && <p className="desc">{description}</p>}
      </div>
      {actions && <div className="actions">{actions}</div>}
    </div>
  )
}

export function EmptyState({ message }: { message: string }) {
  return <div className="empty">{message}</div>
}

export function Pagination({
  page,
  pageCount,
  total,
  onPage,
}: {
  page: number
  pageCount: number
  total: number
  onPage: (p: number) => void
}) {
  if (total === 0) return null
  const start = (page - 1) * PAGE_SIZE + 1
  const end = Math.min(page * PAGE_SIZE, total)
  const buttons: number[] = []
  const from = Math.max(1, Math.min(page - 2, pageCount - 4))
  for (let p = from; p < from + Math.min(5, pageCount); p++) buttons.push(p)

  return (
    <div className="pagination">
      <span className="info">
        Showing {start}–{end} of {total}
      </span>
      <button
        className="page-btn"
        disabled={page === 1}
        onClick={() => onPage(page - 1)}
      >
        ‹
      </button>
      {buttons.map((p) => (
        <button
          key={p}
          className={`page-btn ${p === page ? 'current' : ''}`}
          onClick={() => onPage(p)}
        >
          {p}
        </button>
      ))}
      <button
        className="page-btn"
        disabled={page === pageCount}
        onClick={() => onPage(page + 1)}
      >
        ›
      </button>
    </div>
  )
}

export const PAGE_SIZE = 10

export function SearchBox({
  value,
  onChange,
  placeholder,
}: {
  value: string
  onChange: (v: string) => void
  placeholder?: string
}) {
  return (
    <div className="search-box">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <circle cx="11" cy="11" r="7" />
        <path d="m21 21-4.3-4.3" />
      </svg>
      <input
        className="input"
        value={value}
        placeholder={placeholder ?? 'Search…'}
        onChange={(e) => onChange(e.target.value)}
      />
    </div>
  )
}

export function Stars({ rating }: { rating: number }) {
  return (
    <span className="rating-stars">
      <svg viewBox="0 0 24 24">
        <path d="M12 2l2.9 6.6 7.1.6-5.4 4.7 1.6 7-6.2-3.7-6.2 3.7 1.6-7L2 9.2l7.1-.6z" />
      </svg>
      {rating > 0 ? rating.toFixed(1) : '—'}
    </span>
  )
}

export function initials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0])
    .join('')
    .toUpperCase()
}
