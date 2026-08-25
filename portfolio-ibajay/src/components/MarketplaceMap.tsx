import { motion, useReducedMotion } from 'framer-motion'

/**
 * Fixed full-page background: an illustrated (fictional) small-town
 * Philippine marketplace — storefronts, houses, roads, and the two
 * fulfillment routes Ibajay Eats actually supports:
 *   vendor delivery  (scooter along the road)
 *   customer pickup  (dashed walking path to the store)
 * Pure SVG + CSS/Framer Motion — no WebGL. The layout is deliberately
 * NOT a real map of Ibajay.
 */

const ROUTE_DUR = 14

function Storefront({
  x,
  y,
  label,
  color,
}: {
  x: number
  y: number
  label: string
  color: string
}) {
  return (
    <g transform={`translate(${x} ${y})`}>
      {/* awning */}
      <path d="M-16 -2 h32 l4 8 h-40 z" fill={color} opacity="0.9" />
      {/* body */}
      <rect x="-13" y="6" width="26" height="20" rx="1.5" fill="#1B1614" stroke={color} strokeWidth="1.4" />
      <rect x="-8" y="12" width="7" height="7" rx="0.8" fill={color} opacity="0.35" />
      <rect x="2" y="12" width="7" height="14" rx="0.8" fill={color} opacity="0.55" />
      <text y="-6" textAnchor="middle" fontSize="6" fill="#FAF7F4" opacity="0.5" fontFamily="Inter, sans-serif">
        {label}
      </text>
    </g>
  )
}

function House({ x, y, scale = 1 }: { x: number; y: number; scale?: number }) {
  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`}>
      <path d="M-9 0 L0 -8 L9 0 Z" fill="#E85D2A" opacity="0.75" />
      <rect x="-7" y="0" width="14" height="10" rx="1" fill="#1B1614" stroke="#3A322C" strokeWidth="1.2" />
      <rect x="-2.5" y="3" width="5" height="7" rx="0.6" fill="#FFB845" opacity="0.4" />
    </g>
  )
}

/** Scooter travelling the delivery road; hidden on reduced-motion. */
function DeliveryScooter() {
  const reduce = useReducedMotion()
  if (reduce) return null
  return (
    <g>
      <motion.g
        animate={{ offsetDistance: ['0%', '100%'] }}
        transition={{ duration: ROUTE_DUR, repeat: Infinity, ease: 'linear' }}
        style={{ offsetPath: 'path("M60 300 C 220 260 340 330 520 290 C 650 260 720 300 900 270")' }}
      >
        {/* box + wheels */}
        <rect x="-7" y="-11" width="14" height="9" rx="2" fill="#E85D2A" />
        <circle cx="-4.5" cy="-1" r="3" fill="#0C0A09" stroke="#F07A4E" strokeWidth="1.4" />
        <circle cx="4.5" cy="-1" r="3" fill="#0C0A09" stroke="#F07A4E" strokeWidth="1.4" />
        <path d="M-4 -8 L4 -8 L1 -13 L-3 -13 Z" fill="#FFB845" opacity="0.85" />
        {/* soft pulse so it reads as "live" */}
        <motion.circle
          r="10"
          cy="-6"
          fill="none"
          stroke="#E85D2A"
          animate={{ opacity: [0.5, 0], r: [6, 14] }}
          transition={{ duration: 2, repeat: Infinity, ease: 'easeOut' }}
        />
      </motion.g>
    </g>
  )
}

export default function MarketplaceMap() {
  return (
    <div aria-hidden="true" className="pointer-events-none fixed inset-0 z-0 overflow-hidden">
      <svg
        className="h-full w-full"
        viewBox="0 0 1000 700"
        preserveAspectRatio="xMidYMid slice"
        fill="none"
      >
        {/* ground tint */}
        <rect width="1000" height="700" fill="#0C0A09" />

        {/* barangay blocks */}
        {[
          [70, 90, 240, 130],
          [420, 60, 250, 110],
          [780, 120, 170, 150],
          [90, 430, 200, 160],
          [700, 430, 230, 140],
          [400, 480, 180, 120],
        ].map(([x, y, w, h], i) => (
          <rect key={i} x={x} y={y} width={w} height={h} rx="14" fill="#151110" stroke="#241D19" strokeWidth="1.5" />
        ))}

        {/* main road */}
        <path
          d="M60 300 C 220 260 340 330 520 290 C 650 260 720 300 900 270"
          stroke="#2A2320"
          strokeWidth="26"
          strokeLinecap="round"
        />
        <path
          d="M60 300 C 220 260 340 330 520 290 C 650 260 720 300 900 270"
          stroke="#E85D2A"
          strokeOpacity="0.25"
          strokeWidth="1.6"
          strokeDasharray="7 9"
        />

        {/* pickup path: house → carinderia */}
        <path
          d="M180 500 C 240 450 280 420 330 380"
          stroke="#2AA184"
          strokeOpacity="0.45"
          strokeWidth="1.6"
          strokeDasharray="3 7"
          strokeLinecap="round"
        />

        {/* connector lanes */}
        <path d="M340 190 V 285 M640 270 V 430 M300 300 V 440" stroke="#241D19" strokeWidth="10" strokeLinecap="round" />

        {/* vendor markers */}
        <Storefront x={340} y={165} label="Carinderia" color="#E85D2A" />
        <Storefront x={530} y={135} label="BBQ Stand" color="#FFB845" />
        <Storefront x={860} y={195} label="Halo-halo" color="#2AA184" />

        {/* houses / customer destinations */}
        <House x={150} y={140} />
        <House x={250} y={175} scale={0.85} />
        <House x={470} y={115} scale={0.9} />
        <House x={800} y={95} scale={0.8} />
        <House x={180} y={500} />
        <House x={760} y={480} scale={0.9} />

        {/* easter egg: future local-products store marker — subtle, off the main path */}
        <g transform="translate(905 615)" className="opacity-25">
          <rect x="-10" y="-8" width="20" height="18" rx="2" fill="#151110" stroke="#716A63" strokeWidth="1.2" />
          <text y="4" textAnchor="middle" fontSize="8">
            🏪
          </text>
          <text y="22" textAnchor="middle" fontSize="5" fill="#716A63" fontFamily="Inter, sans-serif">
            soon
          </text>
        </g>

        <DeliveryScooter />
      </svg>

      {/* vignette so foreground content stays readable */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,transparent_0%,rgba(12,10,9,0.72)_78%)]" />
    </div>
  )
}
