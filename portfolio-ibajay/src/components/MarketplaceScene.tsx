import { useEffect, useRef } from 'react'
import {
  motion,
  useReducedMotion,
  useScroll,
  useSpring,
  useTransform,
  type MotionValue,
} from 'framer-motion'
import { DEMO_FOOD, DEMO_VENDORS, type DemoFood, type DemoVendor } from '../lib/demoData'

/**
 * A tall scroll-driven scene: the visitor watches one sample order travel
 * through the marketplace — customer discovers a store → vendor accepts →
 * kitchen prepares → vendor delivery or pickup completes the loop.
 *
 * Depth layers (back → front):
 *   sky + town silhouette  (slowest parallax)
 *   barangay buildings + roads
 *   delivery route + scooter
 *   food & vendor cards    (fastest — feels closest to the viewer)
 *
 * All content is labeled sample/illustrative. No real businesses.
 */

const SECTION_HEIGHT = '420vh' // scroll runway for the whole journey

function SampleTag({ className = '' }: { className?: string }) {
  return (
    <span
      className={`rounded-full border border-white/15 bg-black/40 px-2 py-0.5 font-mono text-[9px] uppercase tracking-widest text-white/50 ${className}`}
    >
      sample
    </span>
  )
}

/* ---------------- foreground cards ---------------- */

function FoodCard({ item, index }: { item: DemoFood; index: number }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-60px' }}
      transition={{ duration: 0.55, delay: index * 0.08 }}
      whileHover={{ y: -5, rotate: index % 2 ? 0.8 : -0.8 }}
      className="pointer-events-auto w-40 overflow-hidden rounded-2xl border border-white/10 bg-ink-card/95 shadow-xl shadow-black/50 backdrop-blur-sm"
    >
      {/* photo block leads — food is the hero */}
      <div
        className="flex h-20 items-center justify-center"
        style={{ background: `linear-gradient(135deg, ${item.tint}40, #FFB84522)` }}
      >
        <span className="text-4xl drop-shadow-lg" aria-hidden>
          {item.emoji}
        </span>
      </div>
      <div className="p-3 pt-2">
        <div className="flex items-start justify-between gap-2">
          <p className="text-sm font-bold leading-tight text-cream">{item.name}</p>
          <SampleTag />
        </div>
        <div className="mt-1 flex items-center justify-between">
          <p className="text-[11px] text-white/45">{item.store}</p>
          <p className="font-mono text-xs font-bold" style={{ color: item.tint }}>{item.price.split(' ')[0]}</p>
        </div>
      </div>
    </motion.div>
  )
}

function VendorStorefront({ vendor, index }: { vendor: DemoVendor; index: number }) {
  return (
    <motion.div
      initial={{ opacity: 0, x: 40 }}
      whileInView={{ opacity: 1, x: 0 }}
      viewport={{ once: true, margin: '-40px' }}
      transition={{ duration: 0.55, delay: 0.15 + index * 0.09 }}
      whileHover={{ y: -4 }}
      className="pointer-events-auto w-52 overflow-hidden rounded-2xl border border-white/10 bg-ink-card/95 shadow-xl shadow-black/50 backdrop-blur-sm"
    >
      {/* storefront banner */}
      <div
        className="relative flex h-14 items-center gap-2 px-3"
        style={{ background: `linear-gradient(120deg, ${vendor.tint}55, ${vendor.tint}18)` }}
      >
        <span
          className="flex h-9 w-9 items-center justify-center rounded-xl bg-black/30 text-xl"
          aria-hidden
        >
          {vendor.emoji}
        </span>
        <div className="min-w-0">
          <p className="truncate text-sm font-bold leading-tight text-cream">{vendor.kind}</p>
          <p className="flex items-center gap-1 truncate text-[10px] leading-none text-white/50">
            {vendor.mode === 'delivery' ? '🛵 delivery · pickup' : '🚶 pickup'}
          </p>
        </div>
        <SampleTag className="ml-auto shrink-0" />
      </div>
      {/* mini menu preview */}
      <div className="space-y-1 px-3 py-2">
        <p className="text-[9px] font-semibold uppercase tracking-widest text-white/35">Menu preview</p>
        {vendor.menu.map(([name, price]) => (
          <div key={name} className="flex items-baseline justify-between gap-2">
            <span className="truncate text-[11px] text-white/70">{name}</span>
            <span className="shrink-0 font-mono text-[10px] font-semibold" style={{ color: vendor.tint }}>
              {price}
            </span>
          </div>
        ))}
        <p className="pt-0.5 text-[9px] italic text-white/35">{vendor.blurb}</p>
      </div>
    </motion.div>
  )
}

/* ---------------- background layers ---------------- */

function TownSilhouette({ y }: { y?: MotionValue<string | number> }) {
  return (
    <motion.div style={{ y } as never} className="absolute inset-x-0 top-[6%] flex justify-center">
      <svg width="1100" height="220" viewBox="0 0 1100 220" fill="none" aria-hidden className="max-w-none">
        {/* church + town hall + nipa houses silhouette */}
        <g fill="#171310">
          <rect x="80" y="120" width="90" height="100" />
          <path d="M70 120 L125 78 L180 120 Z" />
          <rect x="125" y="52" width="10" height="34" />
          <path d="M130 44 l7 12 h-14 z" />
          {/* town hall */}
          <rect x="300" y="140" width="150" height="80" />
          <path d="M290 140 L375 104 L460 140 Z" />
          {/* plaza arch */}
          <path d="M520 220 v-60 a24 24 0 0 1 48 0 v60" />
          {/* nipa houses */}
          {[650, 750, 850, 960].map((x, i) => (
            <g key={x}>
              <rect x={x} y={150 + i * 6} width="64" height={70 - i * 6} />
              <path d={`M${x - 8} ${150 + i * 6} L${x + 32} ${118 + i * 6} L${x + 72} ${150 + i * 6} Z`} />
            </g>
          ))}
          {/* coconut trees */}
          {[240, 280, 590].map((x) => (
            <g key={x} stroke="#171310" strokeWidth="5" strokeLinecap="round">
              <path d={`M${x} 220 q-4 -46 8 -74`} />
              <path d={`M${x + 8} 146 q-18 -10 -30 -2`} />
              <path d={`M${x + 8} 146 q20 -12 32 -2`} />
            </g>
          ))}
        </g>
      </svg>
    </motion.div>
  )
}

/* ---------------- main scene ---------------- */

export default function MarketplaceScene() {
  const ref = useRef<HTMLDivElement>(null)
  const scooterRef = useRef<SVGGElement>(null)
  const reduce = useReducedMotion()

  // scroll progress through the scene drives everything
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ['start start', 'end end'],
  })
  const p = useSpring(scrollYProgress, { stiffness: 80, damping: 26, restDelta: 0.0005 })

  /* parallax offsets per depth layer */
  const skyY = useTransform(p, [0, 1], ['0%', '-6%'])
  const townY = useTransform(p, [0, 1], ['0%', '-14%'])
  const midY = useTransform(p, [0, 1], ['0%', '-24%'])
  const fgY = useTransform(p, [0, 1], ['0%', '-38%'])

  /* scooter travels the delivery route as you scroll */
  // framer-motion v11 doesn't map offsetDistance from MotionValues — drive it via ref.
  // A plain scroll listener is used because it must also work while Lenis drives scrolling.
  useEffect(() => {
    if (reduce) return
    const update = () => {
      const el = ref.current
      const g = scooterRef.current
      if (!el || !g) return
      const rect = el.getBoundingClientRect()
      // progress of the sticky scene through the viewport: 0 when top hits top, 1 when bottom hits bottom
      const runway = rect.height - window.innerHeight
      if (runway <= 0) return
      const prog = Math.min(1, Math.max(0, -rect.top / runway))
      const t = Math.min(1, Math.max(0, (prog - 0.42) / (0.88 - 0.42)))
      g.style.offsetDistance = `${t * 100}%`
    }
    update()
    window.addEventListener('scroll', update, { passive: true })
    window.addEventListener('resize', update)
    return () => {
      window.removeEventListener('scroll', update)
      window.removeEventListener('resize', update)
    }
  }, [reduce])

  /* order-journey stage highlight */
  const stageDiscover = useTransform(p, [0.02, 0.16, 0.3], [1, 1, 0.25])
  const stageOrder = useTransform(p, [0.16, 0.3, 0.42], [0.25, 1, 1])
  const stagePrepare = useTransform(p, [0.3, 0.42, 0.56], [0.25, 1, 1])
  const stageFulfill = useTransform(p, [0.44, 0.58, 0.86, 1], [0.25, 0.25, 1, 1])

  const stages = [
      { label: 'Customer discovers a vendor', icon: '👀', opacity: stageDiscover },
      { label: 'Views the menu, builds an order', icon: '📖', opacity: stageOrder },
      { label: 'Vendor prepares it', icon: '🍳', opacity: stagePrepare },
      { label: 'Pickup or vendor delivery', icon: '🛵', opacity: stageFulfill },
    ]

  return (
    <section id="marketplace" ref={ref} className="relative z-10" style={{ height: reduce ? 'auto' : SECTION_HEIGHT }}>
      {/* sticky viewport that the story plays inside */}
      <div className="sticky top-0 flex h-screen items-center overflow-hidden py-20">
        {/* ---- background layer: sky tint + town silhouette ---- */}
        <motion.div style={{ y: skyY }} className="absolute inset-0" aria-hidden>
          <div className="absolute inset-x-0 top-0 h-64 bg-gradient-to-b from-[#1A1410] to-transparent opacity-70" />
        </motion.div>
        <TownSilhouette y={(reduce ? undefined : townY) as never} />

        {/* ---- midground: roads + route (SVG, full bleed) ---- */}
        <motion.div style={{ y: reduce ? undefined : midY }} className="absolute inset-x-[-4%] bottom-[8%]" aria-hidden>
          <svg viewBox="0 0 1200 260" fill="none" className="w-full" preserveAspectRatio="xMidYMax meet">
            {/* road */}
            <path d="M-20 190 C 260 150 480 230 760 185 C 940 158 1080 195 1220 170" stroke="#241D19" strokeWidth="30" strokeLinecap="round" />
            <path
              d="M-20 190 C 260 150 480 230 760 185 C 940 158 1080 195 1220 170"
              stroke="#E85D2A"
              strokeOpacity="0.35"
              strokeWidth="1.8"
              strokeDasharray="8 10"
            />
            {/* pickup footpath branching up to a house */}
            <path d="M420 178 C 470 130 520 105 590 82" stroke="#2AA184" strokeOpacity="0.5" strokeWidth="1.6" strokeDasharray="3 7" strokeLinecap="round" />
            {/* houses along the road */}
            <g>
              <path d="M575 62 L600 42 L625 62 Z" fill="#1F1915" />
              <rect x="581" y="62" width="38" height="26" rx="2" fill="#1F1915" />
              <rect x="592" y="70" width="14" height="18" rx="1" fill="#FFB845" opacity="0.35" />
              <path d="M905 128 L930 108 L955 128 Z" fill="#1F1915" />
              <rect x="911" y="128" width="38" height="26" rx="2" fill="#1F1915" />
            </g>
            {/* scooter on the route (scroll-driven; skipped entirely on reduced motion) */}
            {!reduce && (
              <g>
                <g
                  ref={scooterRef}
                  style={{
                    offsetPath: 'path("M-20 190 C 260 150 480 230 760 185 C 940 158 1080 195 1220 170")',
                  }}
                >
                  <rect x="-8" y="-14" width="16" height="10" rx="2" fill="#E85D2A" />
                  <circle cx="-5" cy="-2" r="3.4" fill="#0C0A09" stroke="#F07A4E" strokeWidth="1.5" />
                  <circle cx="5" cy="-2" r="3.4" fill="#0C0A09" stroke="#F07A4E" strokeWidth="1.5" />
                  <motion.circle
                    cy="-8"
                    fill="none"
                    stroke="#E85D2A"
                    animate={{ opacity: [0.5, 0], r: [7, 15] }}
                    transition={{ duration: 2.2, repeat: Infinity, ease: 'easeOut' }}
                  />
                </g>
              </g>
            )}
          </svg>
        </motion.div>

        {/* ---- foreground: food cards (left cluster) + vendor chips (right) ---- */}
        <motion.div style={{ y: reduce ? undefined : fgY }} className="pointer-events-none absolute inset-x-0 top-[16%] px-6 lg:px-14">
          <div className="mx-auto grid max-w-[88rem] gap-10 lg:grid-cols-[1fr_auto]">
            {/* food column */}
            <div>
              <p className="mb-4 flex items-center gap-2 font-mono text-[10px] uppercase tracking-[0.25em] text-white/40">
                Around town right now <SampleTag />
              </p>
              <div className="flex flex-wrap gap-3 sm:max-w-md">
                {DEMO_FOOD.map((item, i) => (
                  <FoodCard key={item.name} item={item} index={i} />
                ))}
              </div>

              {/* live order journey readout */}
              <div className="mt-10 max-w-md space-y-2.5">
                <p className="font-mono text-[10px] uppercase tracking-[0.25em] text-white/40">
                  One order, start to finish
                </p>
                {stages.map((s, i) => (
                  <motion.div
                        key={s.label}
                        style={{ opacity: reduce ? 1 : s.opacity }}
                        className="flex items-center gap-3 rounded-xl border border-white/[0.07] bg-black/30 px-4 py-2.5 backdrop-blur-sm transition-colors"
                      >
                    <span className="font-mono text-[10px] text-white/35">0{i + 1}</span>
                    <span aria-hidden>{s.icon}</span>
                    <span className="text-sm font-medium text-white/85">{s.label}</span>
                  </motion.div>
                ))}
                <p className="pt-1 font-mono text-[10px] text-white/35">
                  Illustrative flow — shows how an order moves through Ibajay Eats.
                </p>
              </div>
            </div>

            {/* vendor column */}
            <div className="hidden flex-col items-end gap-3 lg:flex">
              <p className="mb-1 flex items-center gap-2 font-mono text-[10px] uppercase tracking-[0.25em] text-white/40">
                Kinds of stores you'll find <SampleTag />
              </p>
              {DEMO_VENDORS.map((v, i) => (
                <VendorStorefront key={v.kind} vendor={v} index={i} />
              ))}
            </div>
          </div>
        </motion.div>

        {/* mobile vendor strip (in-flow on small screens so it never overlaps the journey list) */}
        <div className="absolute inset-x-0 bottom-[2%] flex gap-2 overflow-x-auto px-6 pb-2 sm:hidden">
          {DEMO_VENDORS.map((v) => (
            <span
              key={v.kind}
              className="flex shrink-0 items-center gap-1.5 rounded-full border border-white/10 bg-black/50 px-3 py-1.5 text-xs text-white/75 backdrop-blur-sm"
            >
              <span aria-hidden>{v.emoji}</span> {v.kind}
              <SampleTag />
            </span>
          ))}
        </div>
      </div>
    </section>
  )
}
