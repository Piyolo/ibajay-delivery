import { useEffect, useRef } from 'react'
import { animate, motion, useInView } from 'framer-motion'

type Stat = {
  value: number
  suffix: string
  label: string
  color: string
}

const STATS: Stat[] = [
  { value: 1, suffix: '', label: 'Town at the center of everything: Ibajay', color: '#F07A4E' },
  { value: 2, suffix: '', label: 'Ways your food reaches you — vendor delivery or pickup', color: '#FFB845' },
  { value: 100, suffix: '%', label: 'Of the stores on here are local', color: '#2AA184' },
  { value: 0, suffix: '', label: 'Outside corporations — just our community', color: '#F07A4E' },
]

function Counter({ stat }: { stat: Stat }) {
  const ref = useRef<HTMLSpanElement>(null)
  const inView = useInView(ref, { once: true, margin: '-80px' })

  useEffect(() => {
    if (!inView || !ref.current) return
    const controls = animate(0, stat.value, {
      duration: 1.8,
      ease: [0.22, 1, 0.36, 1],
      onUpdate: (v) => {
        if (ref.current) ref.current.textContent = `${Math.round(v)}${stat.suffix}`
      },
    })
    return () => controls.stop()
  }, [inView, stat])

  return (
    <span ref={ref} className="font-display text-5xl font-bold sm:text-6xl" style={{ color: stat.color }}>
      0{stat.suffix}
    </span>
  )
}

export default function Stats() {
  return (
    <section className="relative z-10 py-24">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-80px' }}
          transition={{ duration: 0.8 }}
          className="grid grid-cols-2 gap-x-6 gap-y-12 lg:grid-cols-4"
        >
          {/* Marketplace facts — true by design, no invented launch metrics */}
          {STATS.map((s) => (
            <div key={s.label} className="text-center lg:text-left">
              <Counter stat={s} />
              <p className="mt-3 text-sm leading-snug text-white/50">{s.label}</p>
            </div>
          ))}
        </motion.div>
      </div>
    </section>
  )
}
