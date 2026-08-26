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
    title: 'Every store gets a storefront',
    body: 'Photos, menus, hours, and delivery fees — the same digital presence big chains pay for, available to the carinderia on your street.',
    span: 'md:col-span-2',
    tint: '#E85D2A',
    icon: icon(<><path d="M3 9l1.5-5h15L21 9M3 9v11h18V9M3 9h18M9 20v-6h6v6" /></>),
  },
  {
    title: 'Vendor delivery or pickup',
    body: 'You choose at checkout — pick it up yourself on your usual route, or have the vendor\'s own delivery person bring it over.',
    tint: '#FFB845',
    icon: icon(<><rect x="3" y="6" width="13" height="10" rx="2" /><path d="M16 9h3l2 3v4h-5z" /><circle cx="7" cy="18" r="1.6" /><circle cx="17.5" cy="18" r="1.6" /></>),
  },
  {
    title: 'Discovery by barangay',
    body: 'Find who\'s cooking near you — vendors draw their own coverage from Poblacion to Aparicio, so you only see what actually reaches you.',
    span: 'md:col-span-2',
    tint: '#3378C9',
    icon: icon(<><path d="M12 21s-7-5.5-7-11a7 7 0 0 1 14 0c0 5.5-7 11-7 11z" /><circle cx="12" cy="10" r="2.5" /></>),
  },
  {
    title: 'Talk straight to the source',
    body: 'Customers and vendors chat directly — extra rice, gate codes, "malapit na po?" No call center in between.',
    tint: '#FFB845',
    icon: icon(<><path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 8.6 8.6 0 0 1-3.7-.8L3 20l1-4.9a8.4 8.4 0 1 1 17-3.6z" /></>),
  },
  {
    title: 'Built by locals',
    body: 'Developed here in Ibajay, for Ibajay — feedback goes to people you can actually bump into at the palengke.',
    tint: '#2AA184',
    icon: icon(<><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75" /></>),
  },
  {
    title: 'Room to grow together',
    body: 'Food first — then drinks, desserts, and other local products as more of the community joins.',
    tint: '#8A5CF6',
    icon: icon(<><path d="M12 2v20M2 12h20" /><circle cx="12" cy="12" r="9" opacity="0.35" /></>),
  },
  {
    title: 'Track every order',
    body: 'A 7-step live status keeps customers and vendors in sync, pushed instantly over WebSockets.',
    tint: '#E85D2A',
    icon: icon(<><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3" /></>),
  },
]

export default function BentoGrid() {
  return (
    <section className="relative z-10 py-16 sm:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-80px' }}
          transition={{ duration: 0.8 }}
          className="max-w-2xl"
        >
          <span className="section-chip">One marketplace</span>
          <h2 className="mt-5 font-display text-4xl font-bold tracking-tight sm:text-5xl">
            A small square,
            <br />
            <span className="text-gradient">done properly.</span>
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
