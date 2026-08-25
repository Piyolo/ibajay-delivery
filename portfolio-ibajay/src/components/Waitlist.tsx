import { useState, type FormEvent } from 'react'
import { motion } from 'framer-motion'

const API_BASE = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '') ?? ''

type Interest = 'customer' | 'vendor'
type FormState = 'idle' | 'submitting' | 'success' | 'error'

export default function Waitlist() {
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
    <section id="waitlist" className="relative z-10 py-28">
      <div className="mx-auto max-w-2xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-80px' }}
          transition={{ duration: 0.8 }}
          className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-8 backdrop-blur-sm sm:p-12"
        >
          <div className="text-center">
            <span className="section-chip">Be first in line</span>
            <h2 className="mt-5 font-display text-3xl font-bold tracking-tight sm:text-4xl">
              Join the waitlist.
            </h2>
            <p className="mx-auto mt-4 max-w-md text-sm leading-relaxed text-white/55">
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
            <form onSubmit={onSubmit} className="mt-8 space-y-4">
              {/* customer / vendor toggle */}
              <div className="grid grid-cols-2 gap-2 rounded-2xl border border-white/10 bg-black/20 p-1.5">
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
                    className={`rounded-xl px-4 py-2.5 text-sm font-semibold transition-all ${
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
                className="w-full rounded-xl border border-white/10 bg-black/25 px-4 py-3 text-sm text-cream placeholder:text-white/35 outline-none transition-colors focus:border-ember/60"
              />
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@email.com"
                className="w-full rounded-xl border border-white/10 bg-black/25 px-4 py-3 text-sm text-cream placeholder:text-white/35 outline-none transition-colors focus:border-ember/60"
              />

              <button
                type="submit"
                disabled={state === 'submitting'}
                className={`w-full rounded-full py-3.5 font-semibold text-white transition-all duration-300 hover:-translate-y-0.5 disabled:cursor-not-allowed disabled:opacity-60 ${
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
