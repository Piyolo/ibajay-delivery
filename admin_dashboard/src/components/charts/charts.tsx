import {
  Area,
  AreaChart,
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts'
import { money, num } from '../../lib/format'

export const SERIES_COLORS = ['#e85d2a', '#1f6f5c', '#3378c9', '#8a5cf6']

const axisStyle = { fontSize: 11, fill: '#716a63' }
const gridStroke = '#e7e1db'

function TooltipBox({
  active,
  payload,
  label,
}: {
  active?: boolean
  payload?: Array<{ name?: string; value?: number | string; color?: string }>
  label?: string | number
}) {
  if (!active || !payload?.length) return null
  return (
    <div
      style={{
        background: '#fff',
        border: '1px solid #e7e1db',
        borderRadius: 6,
        padding: '8px 12px',
        fontSize: 12,
        boxShadow: '0 2px 10px rgba(29,26,23,0.08)',
      }}
    >
      <div style={{ fontWeight: 700, marginBottom: 4 }}>{label}</div>
      {payload.map((p, i) => (
        <div key={i} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: 2,
              background: p.color,
              display: 'inline-block',
            }}
          />
          <span>{p.name}:</span>
          <span style={{ fontWeight: 600 }}>
            {typeof p.value === 'number' && p.name?.toLowerCase().includes('revenue')
              ? money(p.value)
              : num(Number(p.value ?? 0))}
          </span>
        </div>
      ))}
    </div>
  )
}

export function RevenueAreaChart({
  data,
  height = 240,
}: {
  data: Array<{ label: string; revenue: number }>
  height?: number
}) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 8, right: 12, left: -6, bottom: 0 }}>
        <defs>
          <linearGradient id="revFill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#e85d2a" stopOpacity={0.18} />
            <stop offset="100%" stopColor="#e85d2a" stopOpacity={0.01} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke={gridStroke} vertical={false} />
        <XAxis dataKey="label" tick={axisStyle} tickLine={false} axisLine={{ stroke: gridStroke }} />
        <YAxis
          tick={axisStyle}
          tickLine={false}
          axisLine={false}
          width={54}
          tickFormatter={(v: number) => (v >= 1000 ? `${Math.round(v / 1000)}k` : String(v))}
        />
        <Tooltip content={<TooltipBox />} />
        <Area
          type="monotone"
          dataKey="revenue"
          name="Revenue"
          stroke="#e85d2a"
          strokeWidth={2}
          fill="url(#revFill)"
        />
      </AreaChart>
    </ResponsiveContainer>
  )
}

export function OrdersBarChart({
  data,
  height = 240,
}: {
  data: Array<{ label: string; orders: number }>
  height?: number
}) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <BarChart data={data} margin={{ top: 8, right: 12, left: -14, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke={gridStroke} vertical={false} />
        <XAxis dataKey="label" tick={axisStyle} tickLine={false} axisLine={{ stroke: gridStroke }} />
        <YAxis tick={axisStyle} tickLine={false} axisLine={false} width={40} allowDecimals={false} />
        <Tooltip content={<TooltipBox />} cursor={{ fill: 'rgba(232,93,42,0.06)' }} />
        <Bar dataKey="orders" name="Orders" fill="#1f6f5c" radius={[3, 3, 0, 0]} maxBarSize={22} />
      </BarChart>
    </ResponsiveContainer>
  )
}

export function GrowthLineChart({
  data,
  color = '#3378c9',
  dataKey = 'count',
  height = 220,
}: {
  data: Array<{ label: string } & Record<string, number | string>>
  color?: string
  dataKey?: string
  height?: number
}) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 8, right: 12, left: -14, bottom: 0 }}>
        <defs>
          <linearGradient id={`fill-${dataKey}`} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity={0.16} />
            <stop offset="100%" stopColor={color} stopOpacity={0.01} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke={gridStroke} vertical={false} />
        <XAxis dataKey="label" tick={axisStyle} tickLine={false} axisLine={{ stroke: gridStroke }} />
        <YAxis tick={axisStyle} tickLine={false} axisLine={false} width={40} allowDecimals={false} />
        <Tooltip content={<TooltipBox />} />
        <Area
          type="monotone"
          dataKey={dataKey}
          name="Vendors"
          stroke={color}
          strokeWidth={2}
          fill={`url(#fill-${dataKey})`}
        />
      </AreaChart>
    </ResponsiveContainer>
  )
}

export function DonutChart({
  data,
  height = 210,
}: {
  data: Array<{ label: string; value: number }>
  height?: number
}) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <PieChart>
        <Pie
          data={data}
          dataKey="value"
          nameKey="label"
          innerRadius="58%"
          outerRadius="85%"
          paddingAngle={2}
          strokeWidth={0}
        >
          {data.map((_, i) => (
            <Cell key={i} fill={SERIES_COLORS[i % SERIES_COLORS.length]} />
          ))}
        </Pie>
        <Tooltip content={<TooltipBox />} />
      </PieChart>
    </ResponsiveContainer>
  )
}

export function ChartLegend({ items }: { items: Array<{ label: string; color: string }> }) {
  return (
    <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', marginTop: 8 }}>
      {items.map((it) => (
        <span key={it.label} className="small muted row-flex" style={{ gap: 6 }}>
          <span
            style={{ width: 9, height: 9, borderRadius: 3, background: it.color, display: 'inline-block' }}
          />
          {it.label}
        </span>
      ))}
    </div>
  )
}
