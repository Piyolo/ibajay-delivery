import { motion } from 'framer-motion'

export default function CTA() {
  return (
    <section id="cta" className="relative z-10 overflow-hidden py-20 sm:py-32">
      {/* glow rings */}
      <div className="pointer-events-none absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2">
        <div className="h-[540px] w-[540px] rounded-full border border-ember/15" />
        <div className="absolute inset-0 m-auto h-[380px] w-[380px] rounded-full border border-gold/20 animate-spin-slower [clip-path:polygon(0_0,100%_0,100%_75%,75%_75%,75%_100%,0_100%)]" />
        <div className="absolute inset-0 m-auto h-[220px] w-[220px] rounded-full bg-gradient-to-br from-ember/25 to-moss/25 blur-2xl animate-pulse-glow" />
      </div>

      <div className="relative mx-auto max-w-4xl px-6 text-center">
        <motion.p
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8 }}
          className="text-xs font-semibold uppercase tracking-[0.35em] text-white/45"
        >
          Ibajay, Aklan · Philippines
        </motion.p>

        <motion.h2
          initial={{ opacity: 0, y: 40, scale: 0.97 }}
          whileInView={{ opacity: 1, y: 0, scale: 1 }}
          viewport={{ once: true, margin: '-80px' }}
          transition={{ duration: 0.9, ease: [0.22, 1, 0.36, 1] }}
          className="mt-6 font-display text-5xl font-bold leading-[0.95] tracking-tight sm:text-8xl"
        >
          Gutom ka na ba?
          <br />
          <span className="shimmer-text">Hintay lang.</span>
        </motion.h2>

        <motion.div
          initial={{ opacity: 0, y: 24 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.8, delay: 0.15 }}
          className="mt-10 flex flex-wrap items-center justify-center gap-4"
        >
          <a
            href="#waitlist"
            className="rounded-full bg-gradient-to-r from-ember to-ember-dark px-9 py-4 font-semibold text-white transition-all duration-300 hover:-translate-y-0.5 hover:shadow-glow"
          >
            Join the waitlist
          </a>
          <a
            href="#waitlist"
            onClick={(e) => {
              // deep-link into the vendor tab of the waitlist form
              e.preventDefault()
              document.querySelector<HTMLButtonElement>('[data-waitlist-vendor]')?.click()
              document.querySelector('#waitlist')?.scrollIntoView({ behavior: 'smooth' })
            }}
            className="rounded-full border border-moss-bright/40 bg-moss/15 px-9 py-4 font-semibold text-emerald-100 backdrop-blur transition-all duration-300 hover:-translate-y-0.5 hover:bg-moss/30"
          >
            Become a vendor
          </a>
        </motion.div>

        <motion.p
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ duration: 1, delay: 0.3 }}
          className="mt-12 inline-block rounded-full glass px-5 py-2 font-mono text-sm text-white/60"
        >
          Launching soon in Ibajay, Aklan
        </motion.p>
      </div>
    </section>
  )
}
