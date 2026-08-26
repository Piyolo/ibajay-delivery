import { motion } from 'framer-motion'

/**
 * Floating food + vendor cards that orbit the hero phone.
 * All content is demonstrative: every card carries a "sample" marker so
 * nothing reads as a real partner business. Pure CSS/Framer — no WebGL.
 */

type FoodCard = {
  name: string
  store: string
  price: string
  emoji: string
  tint: string
  /** placement class relative to the phone column */
  pos: string
  depth: number // -1 far, 0 mid, 1 near → drives parallax strength
}

const FOODS: FoodCard[] = [
  { name: 'Chicken Adobo', store: 'Carinderia', price: '₱65', emoji: '🍗', tint: '#E85D2A', pos: '-left-40 top-24 hidden xl:block', depth: 1 },
  { name: 'Halo-halo', store: 'Dessert stand', price: '₱55', emoji: '🍨', tint: '#2AA184', pos: '-left-32 bottom-28 hidden xl:block', depth: -1 },
  { name: 'Pandesal · 6 pcs', store: 'Bakery', price: '₱25', emoji: '🥖', tint: '#E0A72E', pos: '-right-28 top-10 hidden xl:block', depth: -1 },
]

const MOBILE_FOODS = [
  { name: 'Chicken Adobo', price: '₱65', emoji: '🍗', tint: '#E85D2A' },
  { name: 'Halo-halo', price: '₱55', emoji: '🍨', tint: '#2AA184' },
  { name: 'Milk Tea', price: '₱70', emoji: '🧋', tint: '#C98A5B' },
  { name: 'Burger w/ egg', price: '₱45', emoji: '🍔', tint: '#FFB845' },
]

export function HeroFoodCards({ shiftX }: { shiftX?: import('framer-motion').MotionValue<number> }) {
  return (
    <>
      {/* desktop: floating around the phone */}
      {FOODS.map((f, i) => (
        <motion.div
          key={f.name}
          initial={{ opacity: 0, y: 30, scale: 0.9 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ duration: 0.7, delay: 0.9 + i * 0.15 }}
          className={`absolute z-20 ${f.pos}`}
          style={{ transformStyle: 'preserve-3d', ...(shiftX ? { x: shiftX } : {}) }}
        >
          <motion.div
            className="animate-float"
            style={{ animationDelay: `${i * 1.3}s` }}
          >
            <div className="w-40 overflow-hidden rounded-2xl border border-white/12 bg-[#1B1614]/95 shadow-2xl shadow-black/60 backdrop-blur-sm">
              <div className="relative flex h-16 items-center justify-center" style={{ background: `linear-gradient(135deg, ${f.tint}45, ${f.tint}12)` }}>
                <span className="text-3xl drop-shadow-md" aria-hidden>{f.emoji}</span>
                <span className="absolute right-1.5 top-1.5 rounded-full bg-black/50 px-1.5 py-[1px] font-mono text-[7px] uppercase tracking-widest text-white/50">
                  sample
                </span>
              </div>
              <div className="px-2.5 py-2">
                <p className="truncate text-xs font-bold text-cream">{f.name}</p>
                <div className="mt-0.5 flex items-center justify-between">
                  <p className="truncate text-[10px] text-white/45">{f.store}</p>
                  <p className="font-mono text-[11px] font-bold" style={{ color: f.tint }}>{f.price}</p>
                </div>
              </div>
            </div>
          </motion.div>
        </motion.div>
      ))}

      {/* mobile/tablet: compact horizontal strip under the copy */}
      <div className="mt-8 flex gap-2 overflow-x-auto pb-2 xl:hidden">
        {MOBILE_FOODS.map((f) => (
          <div key={f.name} className="shrink-0 rounded-xl border border-white/10 bg-[#1B1614]/90 p-2 pr-3 backdrop-blur-sm">
            <div className="flex items-center gap-2">
              <span className="flex h-9 w-9 items-center justify-center rounded-lg text-lg" style={{ backgroundColor: `${f.tint}26` }} aria-hidden>
                {f.emoji}
              </span>
              <span>
                <span className="block text-[11px] font-bold leading-none text-cream">{f.name}</span>
                <span className="mt-1 block font-mono text-[10px] leading-none" style={{ color: f.tint }}>{f.price}</span>
              </span>
            </div>
          </div>
        ))}
        <span className="flex shrink-0 items-center rounded-full border border-white/10 px-2 font-mono text-[8px] uppercase tracking-widest text-white/35">
          sample items
        </span>
      </div>
    </>
  )
}

/** Mini storefront markers for the background map — category + icon + label. */
export function HeroStorefronts() {
  // positioned over the map/road area (right side), clear of the headline column
  const stores = [
    { kind: 'Carinderia', emoji: '🍲', x: '46%', y: '72%' },
    { kind: 'Bakery', emoji: '🥖', x: '66%', y: '30%' },
    { kind: 'Cafe', emoji: '☕', x: '86%', y: '58%' },
    { kind: 'Milk Tea Shop', emoji: '🧋', x: '56%', y: '20%' },
    { kind: 'Restaurant', emoji: '🍽️', x: '76%', y: '84%' },
  ]
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 hidden lg:block">
      {stores.map((s, i) => (
        <motion.div
          key={s.kind}
          initial={{ opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 1.4 + i * 0.18 }}
          className="absolute"
          style={{ left: s.x, top: s.y }}
        >
          <motion.div animate={{ y: [0, -5, 0] }} transition={{ duration: 5 + i, repeat: Infinity, ease: 'easeInOut' }}>
            <div className="flex items-center gap-1.5 rounded-lg border border-white/[0.07] bg-black/45 px-2 py-1 backdrop-blur-sm">
              <span className="text-sm" aria-hidden>{s.emoji}</span>
              <span className="text-[9px] font-semibold text-white/55">{s.kind}</span>
            </div>
          </motion.div>
        </motion.div>
      ))}
    </div>
  )
}

/** Rotating activity toast — shows one marketplace event at a time (vendor delivery / pickup). */
export function HeroActivityToast() {
  const events = [
    { icon: '🛵', label: 'Vendor delivery heading out', sub: 'order #IBJ-1042' },
    { icon: '🚶', label: 'Ready for pickup', sub: 'order #IBJ-1038' },
    { icon: '🍳', label: 'Kitchen preparing', sub: '2 orders in the queue' },
  ]
  return (
    <div className="pointer-events-none absolute bottom-10 right-8 z-20 hidden lg:block">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: [0, 1, 1, 0], y: [20, 0, 0, -8] }}
        transition={{ duration: 9, times: [0, 0.08, 0.85, 1], repeat: Infinity, repeatDelay: 1.5 }}
        className="glass flex items-center gap-3 rounded-2xl px-4 py-3 shadow-xl"
      >
        <span className="text-xl" aria-hidden>{events[0].icon}</span>
        <span>
          <span className="block text-xs font-bold text-cream">{events[0].label}</span>
          <span className="mt-0.5 block font-mono text-[9px] text-white/40">{events[0].sub} · illustrative</span>
        </span>
        <span className="ml-2 h-2 w-2 rounded-full bg-moss-bright animate-pulse-glow" />
      </motion.div>
    </div>
  )
}
