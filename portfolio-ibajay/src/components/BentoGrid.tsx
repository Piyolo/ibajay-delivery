import { motion } from 'framer-motion'
import type { ReactNode } from 'react'

type Card = {
  title: string
  body: string
  icon: ReactNode
  span?: string
  tint: string
}

const icon = (path: ReactNode) => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
    {path}
  </svg>
)

const CARDS: Card[] = [
  {
    title: 'Live order tracking',
    body: 'A 7-step status engine keeps customers, vendors, and riders in sync — pushed instantly over WebSockets.',
    span: 'md:col-span-2',
    tint: '#E85D2A',
    icon: icon(<><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3" /></>),
  },
  {
    title: 'Real-time chat',
    body: 'Customers and vendors talk it out — extra rice, gate codes, "malapit na po?"',
    tint: '#FFB845',
    icon: icon(<><path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 8.6 8.6 0 0 1-3.7-.8L3 20l1-4.9a8.4 8.4 0 1 1 17-3.6z" /></>),
  },
  {
    title: 'OTP + JWT auth',
    body: 'Email OTP verification and token sessions for every account.',
    tint: '#2AA184',
    icon: icon(<><rect x="4" y="10" width="16" height="10" rx="2" /><path d="M8 10V7a4 4 0 0 1 8 0v3" /></>),
  },
  {
    title: 'Scheduled orders',
    body: 'Order lunch now, schedule it for the fiesta next week.',
    tint: '#F07A4E',
    icon: icon(<><rect x="3" y="5" width="18" height="16" rx="2" /><path d="M8 3v4M16 3v4M3 10h18" /></>),
  },
  {
    title: 'Delivery zones per barangay',
    body: 'Vendors draw their own coverage — Poblacion to Aparicio — with radius and per-km fees.',
    span: 'md:col-span-2',
    tint: '#3378C9',
    icon: icon(<><path d="M12 21s-7-5.5-7-11a7 7 0 0 1 14 0c0 5.5-7 11-7 11z" /><circle cx="12" cy="10" r="2.5" /></>),
  },
  {
    title: 'Vendor analytics',
    body: 'Revenue charts, top sellers, and order volume at a glance.',
    tint: '#8A5CF6',
    icon: icon(<><path d="M4 19V5M4 19h16" /><path d="M8 15l3-4 3 2 4-6" /></>),
  },
  {
    title: 'Push notifications',
    body: 'Firebase-powered alerts from "order accepted" to "kain na!"',
    tint: '#2AA184',
    icon: icon(<><path d="M18 8a6 6 0 1 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M10 21a2 2 0 0 0 4 0" /></>),
  },
]

export default function BentoGrid() {
  return (
    <section className="relative z-10 py-28">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-80px' }}
          transition={{ duration: 0.8 }}
          className="max-w-2xl"
        >
          <span className="section-chip">Under the hood</span>
          <h2 className="mt-5 font-display text-4xl font-bold tracking-tight sm:text-5xl">
            Small town app.
            <br />
            <span className="text-gradient">Big city engineering.</span>
          </h2>
        </motion.div>

        <div className="mt-14 grid gap-4 md:grid-cols-3">
          {CARDS.map((card, i) => (
            <motion.article
              key={card.title}
              initial={{ opacity: 0, y: 34 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: '-40px' }}
              transition={{ duration: 0.65, delay: (i % 3) * 0.09 }}
              whileHover={{ y: -6 }}
              className={`group relative overflow-hidden rounded-3xl border border-white/[0.08] bg-white/[0.03] p-7 backdrop-blur-sm transition-colors duration-500 hover:border-white/20 ${card.span ?? ''}`}
            >
              {/* hover glow */}
              <div
                className="pointer-events-none absolute -right-16 -top-16 h-44 w-44 rounded-full opacity-0 blur-3xl transition-opacity duration-700 group-hover:opacity-25"
                style={{ backgroundColor: card.tint }}
              />
              <div
                className="flex h-11 w-11 items-center justify-center rounded-xl transition-transform duration-500 group-hover:-rotate-6 group-hover:scale-110"
                style={{ color: card.tint, backgroundColor: `${card.tint}1f`, border: `1px solid ${card.tint}45` }}
              >
                {card.icon}
              </div>
              <h3 className="mt-5 font-display text-lg font-bold">{card.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-white/55">{card.body}</p>
            </motion.article>
          ))}
        </div>
      </div>
    </section>
  )
}
