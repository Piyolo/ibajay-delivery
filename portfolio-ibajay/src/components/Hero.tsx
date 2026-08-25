import { motion, useMotionValue, useSpring, useTransform } from 'framer-motion'
import type { MouseEvent } from 'react'
import PhoneFrame from './PhoneFrame'
import { CustomerHome } from '../screens'

const container = {
  hidden: {},
  show: { transition: { staggerChildren: 0.12, delayChildren: 0.2 } },
}

const rise = {
  hidden: { opacity: 0, y: 40 },
  show: { opacity: 1, y: 0, transition: { duration: 0.9, ease: [0.22, 1, 0.36, 1] as const } },
}

export default function Hero() {
  const mx = useMotionValue(0)
  const my = useMotionValue(0)
  const sx = useSpring(mx, { stiffness: 60, damping: 18 })
  const sy = useSpring(my, { stiffness: 60, damping: 18 })

  const phoneRotateY = useTransform(sx, [-1, 1], [10, -10])
  const phoneRotateX = useTransform(sy, [-1, 1], [-8, 8])
  const cardShiftX = useTransform(sx, [-1, 1], [-14, 14])

  const onMove = (e: MouseEvent<HTMLElement>) => {
    const r = e.currentTarget.getBoundingClientRect()
    mx.set(((e.clientX - r.left) / r.width) * 2 - 1)
    my.set(((e.clientY - r.top) / r.height) * 2 - 1)
  }

  return (
    <section
      id="top"
      onMouseMove={onMove}
      className="relative z-10 flex min-h-screen items-center overflow-hidden pt-28 pb-16"
    >
      <div className="mx-auto grid w-full max-w-6xl items-center gap-14 px-6 lg:grid-cols-[1.15fr_0.85fr]">
        <motion.div variants={container} initial="hidden" animate="show" className="text-center lg:text-left">
          <motion.div variants={rise} className="mb-6 inline-flex items-center gap-2.5 rounded-full glass px-4 py-2">
            <span className="relative flex h-2 w-2">
              <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-ember opacity-75" />
              <span className="relative inline-flex h-2 w-2 rounded-full bg-ember" />
            </span>
            <span className="text-xs font-medium tracking-wide text-white/80">
              Launching soon in Ibajay, Aklan — join the waitlist
            </span>
          </motion.div>

          <motion.h1
            variants={rise}
            className="font-display text-[13vw] leading-[0.95] font-bold tracking-tight sm:text-7xl lg:text-[5.4rem]"
          >
            Sarap,
            <br />
            <span className="text-gradient">delivered.</span>
          </motion.h1>

          <motion.p
            variants={rise}
            className="mx-auto mt-6 max-w-xl text-base leading-relaxed text-white/60 sm:text-lg lg:mx-0"
          >
            One marketplace for the food you already love — carinderias, burger joints,
            dessert stands. Order from local stores, track your order live, and chat with
            vendors while they run their business from one app.
          </motion.p>

          <motion.div variants={rise} className="mt-9 flex flex-wrap items-center justify-center gap-4 lg:justify-start">
            <a
              href="#customer"
              className="group relative overflow-hidden rounded-full bg-gradient-to-r from-ember to-ember-dark px-8 py-4 text-sm font-semibold text-white transition-all duration-300 hover:-translate-y-0.5 hover:shadow-glow"
            >
              <span className="relative z-10">Explore the apps</span>
              <span className="absolute inset-0 -translate-x-full bg-gradient-to-r from-transparent via-white/25 to-transparent transition-transform duration-700 group-hover:translate-x-full" />
            </a>
            <a
              href="#vendor"
              className="rounded-full border border-white/15 bg-white/[0.03] px-8 py-4 text-sm font-semibold text-white/85 backdrop-blur transition-all duration-300 hover:border-moss-bright/50 hover:bg-moss/15 hover:text-white"
            >
              Sell on Ibajay Eats
            </a>
          </motion.div>

          <motion.div
            variants={rise}
            className="mt-12 flex items-center justify-center gap-x-8 gap-y-3 text-sm text-white/45 lg:justify-start"
          >
            <span className="flex items-center gap-2">
              <span className="h-1.5 w-1.5 rounded-full bg-ember" /> Live order tracking
            </span>
            <span className="flex items-center gap-2">
              <span className="h-1.5 w-1.5 rounded-full bg-gold" /> Real-time vendor chat
            </span>
            <span className="flex items-center gap-2">
              <span className="h-1.5 w-1.5 rounded-full bg-moss-bright" /> Built for barangays
            </span>
          </motion.div>
        </motion.div>

        {/* hero phone */}
        <motion.div
          initial={{ opacity: 0, y: 80, rotateY: -25 }}
          animate={{ opacity: 1, y: 0, rotateY: 0 }}
          transition={{ duration: 1.2, delay: 0.4, ease: [0.22, 1, 0.36, 1] }}
          className="relative mx-auto hidden justify-center lg:flex"
          style={{ perspective: 1200 }}
        >
          <div className="animate-float-slow" style={{ transformStyle: 'preserve-3d' }}>
            <motion.div style={{ rotateY: phoneRotateY, rotateX: phoneRotateX, transformStyle: 'preserve-3d' }}>
              <PhoneFrame glow="ember">
                <CustomerHome />
              </PhoneFrame>
            </motion.div>

            {/* floating chips */}
            <motion.div
              style={{ x: cardShiftX }}
              className="absolute -left-24 top-16 animate-float"
            >
              <div className="glass rounded-2xl px-4 py-3 shadow-xl">
                <p className="text-[10px] uppercase tracking-wider text-white/50">Order status</p>
                <p className="mt-0.5 flex items-center gap-1.5 text-sm font-bold">
                  <span className="h-2 w-2 rounded-full bg-moss-bright animate-pulse-glow" />
                  Out for delivery
                </p>
              </div>
            </motion.div>

            <motion.div
              style={{ x: useTransform(cardShiftX, (v) => -v) }}
              className="absolute -right-20 bottom-20 animate-float"
            >
              <div className="glass rounded-2xl px-4 py-3 shadow-xl">
                <p className="text-[10px] uppercase tracking-wider text-white/50">Aling Nena's</p>
                <p className="mt-0.5 text-sm font-bold text-gold">★ 4.7 · Open</p>
              </div>
            </motion.div>
          </div>
        </motion.div>
      </div>

      {/* scroll hint */}
      <motion.a
        href="#customer"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.6 }}
        className="absolute bottom-7 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 text-white/40 transition-colors hover:text-white/80"
      >
        <span className="text-[10px] font-semibold uppercase tracking-[0.3em]">Scroll</span>
        <span className="flex h-9 w-5 items-start justify-center rounded-full border border-current p-1">
          <motion.span
            animate={{ y: [0, 10, 0] }}
            transition={{ duration: 1.6, repeat: Infinity, ease: 'easeInOut' }}
            className="h-1.5 w-1 rounded-full bg-ember"
          />
        </span>
      </motion.a>
    </section>
  )
}
