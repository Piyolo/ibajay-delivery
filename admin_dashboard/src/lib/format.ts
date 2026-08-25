const peso = new Intl.NumberFormat('en-PH', {
  style: 'currency',
  currency: 'PHP',
  maximumFractionDigits: 0,
})

const pesoCents = new Intl.NumberFormat('en-PH', {
  style: 'currency',
  currency: 'PHP',
  minimumFractionDigits: 2,
})

export function money(n: number): string {
  return peso.format(n)
}

export function moneyPrecise(n: number): string {
  return pesoCents.format(n)
}

export function num(n: number): string {
  return new Intl.NumberFormat('en-US').format(n)
}

const dateFmt = new Intl.DateTimeFormat('en-PH', {
  month: 'short',
  day: 'numeric',
  year: 'numeric',
})

const dateTimeFmt = new Intl.DateTimeFormat('en-PH', {
  month: 'short',
  day: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
})

export function fmtDate(d: string | Date): string {
  return dateFmt.format(new Date(d))
}

export function fmtDateTime(d: string | Date): string {
  return dateTimeFmt.format(new Date(d))
}

export function timeAgo(d: string | Date | number): string {
  const then = new Date(d).getTime()
  const secs = Math.max(1, Math.floor((Date.now() - then) / 1000))
  if (secs < 60) return `${secs}s ago`
  const mins = Math.floor(secs / 60)
  if (mins < 60) return `${mins}m ago`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  if (days < 30) return `${days}d ago`
  return fmtDate(new Date(then))
}

export function pct(n: number): string {
  const sign = n > 0 ? '+' : ''
  return `${sign}${n.toFixed(1)}%`
}
