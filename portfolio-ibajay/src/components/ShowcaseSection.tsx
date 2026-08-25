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

  /* shared animated screen content (used by desktop phone + mobile ghost phone) */
  const screens = (
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
  )

  return (
    <section ref={ref} id={id} className="relative z-10" style={{ height: `${steps.length * 88}vh` }}>
      <div className="sticky top-0 flex h-svh items-center overflow-hidden">
        {/* mobile ghost phone — decorative, keeps text fully readable */}
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -right-20 top-1/2 z-0 -translate-y-1/2 rotate-[-14deg] opacity-20 lg:hidden"
        >
          <PhoneFrame glow={accent} className="w-[240px]">
            {screens}
          </PhoneFrame>
        </div>

        <div className="relative z-10 mx-auto w-full max-w-6xl px-6 sm:px-8 lg:grid lg:grid-cols-2 lg:items-center lg:gap-10">
          {/* text column */}
          <div>
            <span className={`section-chip ${chipClass}`}>{chip}</span>
            <h2 className="mt-3 font-display text-3xl font-bold leading-tight tracking-tight sm:mt-5 sm:text-5xl">
              {heading}
            </h2>

            <div className="relative mt-5 min-h-[168px] sm:mt-9 sm:min-h-[300px]">
              {/* progress rail (desktop) */}
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
                  <p className="font-display text-xs font-semibold uppercase tracking-widest text-white/35 sm:text-sm">
                    {String(active + 1).padStart(2, '0')} / {String(steps.length).padStart(2, '0')}
                  </p>
                  <h3
                    className={`mt-1.5 font-display text-xl font-bold sm:mt-2 sm:text-3xl ${
                      accent === 'ember' ? 'text-gradient' : 'text-gradient-moss'
                    }`}
                  >
                    {steps[active].title}
                  </h3>
                  <p className="mt-2.5 max-w-md text-sm leading-relaxed text-white/60 sm:mt-4 sm:text-base">
                    {steps[active].body}
                  </p>
                </motion.div>
              </AnimatePresence>
            </div>

            {/* step dots */}
            <div className="mt-5 flex gap-2 pl-4 sm:mt-8 sm:pl-8">
              {steps.map((_, i) => (
                <button
                  key={i}
                  onClick={() => {
                    const el = document.getElementById(id)
                    if (!el) return
                    const y = el.offsetTop + (el.offsetHeight * i) / steps.length + 8
                    window.scrollTo({ top: y, behavior: 'smooth' })
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

          {/* desktop phone column */}
          <div
            className="hidden justify-center lg:flex"
            style={{ perspective: 1400 }}
          >
            <motion.div style={{ rotateY, y: yDrift, transformStyle: 'preserve-3d' }} className="animate-float-slow">
              <PhoneFrame glow={accent} className="lg:w-[290px] xl:w-[300px]">
                {screens}
              </PhoneFrame>
            </motion.div>
          </div>
        </div>
      </div>
    </section>
  )
}
