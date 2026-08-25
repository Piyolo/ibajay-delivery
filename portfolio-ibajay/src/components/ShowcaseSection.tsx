import { useRef, useState } from 'react'
import {
  AnimatePresence,
  motion,
  useMotionValueEvent,
  useScroll,
  useTransform,
} from 'framer-motion'
import PhoneFrame from './PhoneFrame'

export type ShowcaseStep = {
  title: string
  body: string
  screen: React.ReactNode
}

export default function ShowcaseSection({
  id,
  chip,
  chipClass,
  heading,
  accent,
  steps,
}: {
  id: string
  chip: string
  chipClass: string
  heading: React.ReactNode
  accent: 'ember' | 'moss'
  steps: ShowcaseStep[]
}) {
  const ref = useRef<HTMLElement>(null)
  const [active, setActive] = useState(0)

  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ['start start', 'end end'],
  })

  useMotionValueEvent(scrollYProgress, 'change', (v) => {
    const idx = Math.min(steps.length - 1, Math.floor(v * steps.length))
    setActive(idx < 0 ? 0 : idx)
  })

  const rotateY = useTransform(scrollYProgress, [0, 1], [7, -7])
  const yDrift = useTransform(scrollYProgress, [0, 1], [30, -30])

  return (
    <section ref={ref} id={id} className="relative z-10" style={{ height: `${steps.length * 88}vh` }}>
      <div className="sticky top-0 flex h-screen items-center overflow-hidden">
        <div className="mx-auto grid w-full max-w-6xl items-center gap-10 px-6 lg:grid-cols-2">
          {/* text column */}
          <div className="order-2 lg:order-1">
            <span className={`section-chip ${chipClass}`}>{chip}</span>
            <h2 className="mt-5 font-display text-4xl font-bold leading-tight tracking-tight sm:text-5xl">
              {heading}
            </h2>

            <div className="relative mt-9 min-h-[300px]">
              {/* progress rail */}
              <div className="absolute -left-4 top-1 hidden h-[calc(100%-8px)] w-px bg-white/10 sm:block">
                <motion.div
                  className={`w-px ${accent === 'ember' ? 'bg-gradient-to-b from-ember to-gold' : 'bg-gradient-to-b from-moss-bright to-moss'}`}
                  style={{ scaleY: scrollYProgress, originY: 0 }}
                  />
              </div>

              <AnimatePresence mode="wait">
                <motion.div
                  key={active}
                  initial={{ opacity: 0, x: 28 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -20 }}
                  transition={{ duration: 0.45, ease: [0.22, 1, 0.36, 1] }}
                  className="pl-4 sm:pl-8"
                >
                  <p className="font-display text-sm font-semibold uppercase tracking-widest text-white/35">
                    {String(active + 1).padStart(2, '0')} / {String(steps.length).padStart(2, '0')}
                  </p>
                  <h3
                    className={`mt-2 font-display text-2xl font-bold sm:text-3xl ${
                      accent === 'ember' ? 'text-gradient' : 'text-gradient-moss'
                    }`}
                  >
                    {steps[active].title}
                  </h3>
                  <p className="mt-4 max-w-md text-base leading-relaxed text-white/60">
                    {steps[active].body}
                  </p>
                </motion.div>
              </AnimatePresence>
            </div>

            {/* step dots */}
            <div className="mt-8 flex gap-2 pl-4 sm:pl-8">
              {steps.map((_, i) => (
                <button
                  key={i}
                  onClick={() => {
                    const el = document.getElementById(id)
                    if (!el) return
                    const target =
                      el.offsetTop + (window.innerHeight * el.clientHeight * (i / steps.length)) / 1
                    window.scrollTo({ top: target + 4, behavior: 'smooth' })
                  }}
                  aria-label={`Go to step ${i + 1}`}
                  className={`h-1.5 rounded-full transition-all duration-500 ${
                    i === active
                      ? `w-10 ${accent === 'ember' ? 'bg-ember' : 'bg-moss-bright'}`
                      : 'w-4 bg-white/15 hover:bg-white/30'
                  }`}
                />
              ))}
            </div>
          </div>

          {/* phone column */}
          <div className="order-1 flex justify-center lg:order-2" style={{ perspective: 1400 }}>
            <motion.div style={{ rotateY, y: yDrift, transformStyle: 'preserve-3d' }} className="animate-float-slow">
              <PhoneFrame glow={accent}>
                <AnimatePresence mode="wait">
                  <motion.div
                    key={active}
                    initial={{ opacity: 0, scale: 0.96, y: 14 }}
                    animate={{ opacity: 1, scale: 1, y: 0 }}
                    exit={{ opacity: 0, scale: 1.03, y: -10 }}
                    transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
                    className="h-full"
                  >
                    {steps[active].screen}
                  </motion.div>
                </AnimatePresence>
              </PhoneFrame>
            </motion.div>
          </div>
        </div>
      </div>
    </section>
  )
}
