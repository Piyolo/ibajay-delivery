const ITEMS = [
  'Order',
  'Track live',
  'Chat with vendors',
  'Pickup',
  'Scheduled delivery',
  'Menu manager',
  'Sales analytics',
  'OTP-secured',
]

export default function Marquee() {
  const row = [...ITEMS, ...ITEMS]
  return (
    <div className="relative z-10 border-y border-white/[0.07] bg-gradient-to-r from-ember/[0.06] via-transparent to-moss/[0.08] py-5 backdrop-blur-sm overflow-hidden">
      <div className="flex w-max animate-marquee items-center gap-10 whitespace-nowrap hover:[animation-play-state:paused]">
        {[0, 1].map((half) => (
          <div key={half} className="flex items-center gap-10" aria-hidden={half === 1}>
            {row.map((item, i) => (
              <span key={`${half}-${i}`} className="flex items-center gap-10">
                <span className="font-display text-sm font-semibold uppercase tracking-[0.25em] text-white/55">
                  {item}
                </span>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="#E85D2A" aria-hidden className="shrink-0">
                  <path d="M12 0l2.6 9.4L24 12l-9.4 2.6L12 24l-2.6-9.4L0 12l9.4-2.6z" />
                </svg>
              </span>
            ))}
          </div>
        ))}
      </div>
    </div>
  )
}
