import { useEffect, useState, type FormEvent } from 'react'
import { animate, motion, useInView } from 'framer-motion'
import { useRef } from 'react'

const API_BASE = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '') ?? ''

type Interest = 'customer' | 'vendor'
type FormState = 'idle' | 'submitting' | 'success' | 'error'

export default function Waitlist() {
  const countRef = useRef<HTMLSpanElement>(null)
  const countWrapRef = useRef<HTMLDivElement>(null)
  const countInView = useInView(countWrapRef, { once: true, margin: '-60px' })
  const [count, setCount] = useState<number | null>(null)

  // live signup counter — public endpoint, no personal data
  useEffect(() => {
    let cancelled = false
    fetch(`${API_BASE}/api/v1/waitlist/count`)
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => { if (!cancelled && d && typeof d.count === 'number') setCount(d.count) })
      .catch(() => {})
    return () => { cancelled = true }
  }, [])

  // count-up animation when scrolled into view
  useEffect(() => {
    if (!countInView || count === null || !countRef.current) return
    const controls = animate(0, count, {
      duration: 1.4,
      ease: [0.22, 1, 0.36, 1],
      onUpdate: (v) => {
        if (countRef.current) countRef.current.textContent = String(Math.round(v))
      },
    })
    return () => controls.stop()
  }, [countInView, count])

  const [interest, setInterest] = useState<Interest>('customer')
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [state, setState] = useState<FormState>('idle')
  const [message, setMessage] = useState('')

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (state === 'submitting') return
    setState('submitting')
    setMessage('')

    try {
      const res = await fetch(`${API_BASE}/api/v1/waitlist`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, email, interest }),
      })
      const data = (await res.json().catch(() => null)) as { message?: string } | null

      if (!res.ok) {
        setState('error')
        setMessage(data?.message ?? "Something went wrong — please try again in a bit.")
        return
      }
      setState('success')
      setMessage(data?.message ?? "You're on the list!")
    } catch {
      setState('error')
      setMessage("Couldn't reach the server — check your connection and try again.")
    }
  }

  return (
    <section id="waitlist" className="relative z-10 py-16 sm:py-28">
      {/* signup counter */}
      <div ref={countWrapRef} className="mx-auto mb-10 max-w-2xl px-6 text-center">
        {count !== null ? (
          <div>
            <p className="font-display text-5xl font-bold sm:text-6xl">
              <span ref={countRef} className="text-gradient">0</span>
            </p>
            <p className="mt-2 flex items-center justify-center gap-2 text-sm text-white/55">
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-moss-bright opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-moss-bright" />
              </span>
              {count === 1 ? 'person has joined so far' : 'neighbors have already joined the waitlist'}
            </p>
          </div>
        ) : (
          <div className="animate-pulse">
            <div className="mx-auto h-12 w-24 rounded-xl bg-white/5" />
            <div className="mx-auto mt-3 h-4 w-56 rounded bg-white/5" />
          </div>
        )}
      </div>

      <div className="mx-auto max-w-2xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-80px' }}
          transition={{ duration: 0.8 }}
          className="rounded-3xl border border-white/[0.08] bg-white/[0.03] px-5 py-7 backdrop-blur-sm sm:p-12"
        >
          <div className="text-center">
            <span className="section-chip">Be first in line</span>
            <h2 className="mt-5 font-display text-2xl font-bold tracking-tight sm:text-4xl">
              Join the waitlist.
            </h2>
            <p className="mx-auto mt-3 max-w-md text-[13px] leading-relaxed text-white/55 sm:mt-4 sm:text-sm">
              Ibajay Eats hasn't launched yet. Leave your email and we'll tell you the
              moment your first order is ready to place — or your store is ready to open.
            </p>
          </div>

          {state === 'success' ? (
            <motion.div
              initial={{ opacity: 0, y: 12 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-8 rounded-2xl border border-moss-bright/30 bg-moss/15 px-6 py-5 text-center"
            >
              <p className="font-display text-lg font-semibold text-emerald-100">{message}</p>
            </motion.div>
          ) : (
            <form onSubmit={onSubmit} className="mt-6 space-y-3 sm:mt-8 sm:space-y-4">
              {/* customer / vendor toggle */}
              <div className="grid grid-cols-2 gap-1.5 rounded-2xl border border-white/10 bg-black/20 p-1.5 sm:gap-2">
                {(
                  [
                    ['customer', "I'm a customer"],
                    ['vendor', "I'm a business owner"],
                  ] as [Interest, string][]
                ).map(([value, label]) => (
                  <button
                    key={value}
                    type="button"
                    data-waitlist-vendor={value === 'vendor' ? '' : undefined}
                    onClick={() => setInterest(value)}
                    className={`rounded-xl px-2 py-2.5 text-[13px] font-semibold transition-all sm:px-4 sm:text-sm ${
                      interest === value
                        ? value === 'customer'
                          ? 'bg-ember text-white shadow-glow'
                          : 'bg-moss text-emerald-50 shadow-glow-moss'
                        : 'text-white/55 hover:text-white'
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>

              <input
                type="text"
                required
                maxLength={120}
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="Your name"
                inputMode="text"
                autoCapitalize="words"
                className="w-full rounded-xl border border-white/10 bg-black/25 px-4 py-3.5 text-base text-cream placeholder:text-white/35 outline-none transition-colors focus:border-ember/60 sm:py-3 sm:text-sm"
              />
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@email.com"
                inputMode="email"
                autoCapitalize="none"
                autoCorrect="off"
                className="w-full rounded-xl border border-white/10 bg-black/25 px-4 py-3.5 text-base text-cream placeholder:text-white/35 outline-none transition-colors focus:border-ember/60 sm:py-3 sm:text-sm"
              />

              <button
                type="submit"
                disabled={state === 'submitting'}
                className={`w-full rounded-full py-3.5 font-semibold text-white transition-all duration-300 hover:-translate-y-0.5 active:translate-y-0 disabled:cursor-not-allowed disabled:opacity-60 ${
                  interest === 'vendor'
                    ? 'bg-gradient-to-r from-moss to-moss-bright'
                    : 'bg-gradient-to-r from-ember to-ember-dark hover:shadow-glow'
                }`}
              >
                {state === 'submitting' ? 'Signing you up…' : 'Join the waitlist'}
              </button>

              {state === 'error' && (
                <p className="text-center text-sm text-ember-bright" role="alert">
                  {message}
                </p>
              )}
            </form>
          )}
        </motion.div>
      </div>
    </section>
  )
}
