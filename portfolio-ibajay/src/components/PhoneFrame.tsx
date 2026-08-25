import type { ReactNode } from 'react'

export default function PhoneFrame({
  children,
  glow = 'ember',
}: {
  children: ReactNode
  glow?: 'ember' | 'moss'
}) {
  return (
    <div className="relative">
      <div
        className={`absolute -inset-8 rounded-[4rem] blur-3xl opacity-40 ${
          glow === 'ember'
            ? 'bg-[radial-gradient(circle,rgba(232,93,42,0.5),transparent_65%)] animate-pulse-glow'
            : 'bg-[radial-gradient(circle,rgba(31,111,92,0.55),transparent_65%)] animate-pulse-glow'
        }`}
      />
      <div
        className={`relative w-[270px] sm:w-[290px] aspect-[9/19] rounded-[2.8rem] border border-white/15 bg-ink-soft shadow-phone overflow-hidden ring-1 ${
          glow === 'ember' ? 'ring-ember/25' : 'ring-moss-bright/25'
        }`}
      >
        {/* side buttons */}
        <div className="absolute -left-[2px] top-24 h-10 w-[3px] rounded-l bg-white/15" />
        <div className="absolute -left-[2px] top-36 h-14 w-[3px] rounded-l bg-white/15" />
        <div className="absolute -right-[2px] top-28 h-16 w-[3px] rounded-r bg-white/15" />

        {/* dynamic island */}
        <div className="absolute top-2.5 left-1/2 -translate-x-1/2 h-[18px] w-[84px] rounded-full bg-black z-30 border border-white/5" />

        <div className="absolute inset-0 pt-9 pb-3 px-3">{children}</div>

        {/* screen glare */}
        <div className="pointer-events-none absolute inset-0 z-20 bg-gradient-to-tr from-white/[0.07] via-transparent to-white/[0.05]" />
      </div>
    </div>
  )
}
