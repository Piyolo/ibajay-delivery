import { useRef, useState } from 'react'
import { motion, useMotionValueEvent, useScroll, useTransform } from 'framer-motion'

const STEPS = [
  { key: 'pending', label: 'Pending', desc: 'Order lands at the store', color: '#E0A72E' },
  { key: 'accepted', label: 'Accepted', desc: 'Vendor confirms the order', color: '#3378C9' },
  { key: 'preparing', label: 'Preparing', desc: 'Kusina fires up', color: '#8A5CF6' },
  { key: 'ready', label: 'Ready', desc: 'Food is packed and good to go', color: '#1F6F5C' },
  { key: 'out_for_delivery', label: 'Out for delivery', desc: "The vendor's delivery person is on the road", color: '#E85D2A' },
  { key: 'delivered', label: 'Delivered', desc: 'Handed over, still warm', color: '#2E9E5B' },
  { key: 'completed', label: 'Completed', desc: 'Rate, review, repeat', color: '#2E9E5B' },
]

export default function HowItWorks() {
  const ref = useRef<HTMLDivElement>(null)
  const [litCount, setLitCount] = useState(1)

  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ['start 0.85', 'end 0.45'],
  })

  useMotionValueEvent(scrollYProgress, 'change', (v) => {
    setLitCount(Math.max(1, Math.min(STEPS.length, Math.ceil(v * STEPS.length))))
  })

  const lineScale = useTransform(scrollYProgress, [0, 1], [0, 1])

  return (
    <section id="how" className="relative z-10 py-16 sm:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-80px' }}
          transition={{ duration: 0.8 }}
          className="text-center"
        >
          <span className="section-chip">The order lifecycle</span>
          <h2 className="mt-5 font-display text-4xl font-bold tracking-tight sm:text-5xl">
            From <span className="text-gradient">craving</span> to{' '}
            <span className="text-gradient-moss">kain na.</span>
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-white/55">
            Every order moves through seven live statuses — synced in real time between
            customer and vendor over WebSockets. You choose: pick the order up yourself,
            or the vendor's own delivery person brings it to you.
          </p>
        </motion.div>

        <div ref={ref} className="relative mt-20">
          {/* connector line (desktop) */}
          <div className="absolute left-0 right-0 top-7 hidden h-px bg-white/10 md:block">
            <motion.div
              className="h-px origin-left bg-gradient-to-r from-gold via-ember to-emerald-400"
              style={{ scaleX: lineScale }}
            />
          </div>
          {/* connector line (mobile) */}
          <div className="absolute bottom-4 left-[27px] top-4 w-px bg-white/10 md:hidden">
            <motion.div
              className="w-px origin-top bg-gradient-to-b from-gold via-ember to-emerald-400"
              style={{ scaleY: lineScale }}
            />
          </div>

          <ol className="grid gap-10 md:grid-cols-7 md:gap-3">
            {STEPS.map((step, i) => {
              const lit = i < litCount
              return (
                <motion.li
                  key={step.key}
                  initial={{ opacity: 0, y: 24 }}
                  whileInView={{ opacity: 1, y: 0 }}
                  viewport={{ once: true, margin: '-60px' }}
                  transition={{ duration: 0.55, delay: 0.06 * i }}
                  className="relative flex items-start gap-4 md:flex-col md:items-center md:text-center"
                >
                  <span
                    className={`z-10 flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl font-display text-sm font-bold transition-all duration-500 ${
                      lit ? 'scale-110 text-white shadow-lg' : 'border border-dashed text-transparent'
                    }`}
                    style={
                      lit
                        ? {
                            backgroundColor: `${step.color}22`,
                            borderColor: step.color,
                            boxShadow: `0 0 30px -6px ${step.color}88`,
                            color: step.color,
                          }
                        : undefined
                    }
                  >
                    {String(i + 1).padStart(2, '0')}
                  </span>
                  <div className="md:mt-4">
                    <p className={`font-display text-base font-bold transition-colors duration-500 ${lit ? 'text-white' : 'text-white/35'}`}>
                      {step.label}
                    </p>
                    <p className="mt-1 hidden text-xs leading-snug text-white/45 lg:block">{step.desc}</p>
                  </div>
                </motion.li>
              )
            })}
          </ol>
        </div>
      </div>
    </section>
  )
}
