export default function Footer() {
  return (
    <footer className="relative z-10 border-t border-white/[0.07] py-14">
      <div className="mx-auto grid max-w-6xl gap-10 px-6 md:grid-cols-3">
        <div>
          <div className="flex items-center gap-2.5">
            <img src="/logo.png" alt="Ibajay Eats logo" className="h-9 w-9 rounded-xl object-cover ring-1 ring-white/15" />
            <span className="font-display text-lg font-bold">
              Ibajay<span className="text-gradient">Eats</span>
            </span>
          </div>
          <p className="mt-4 max-w-xs text-sm leading-relaxed text-white/45">
            The local food delivery platform for Ibajay, Aklan — connecting every kusina
            to every kapamilya.
          </p>
        </div>

        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.25em] text-white/40">Explore</p>
          <ul className="mt-4 space-y-2.5 text-sm">
            {[
              ['Customer app', '#customer'],
              ['Vendor app', '#vendor'],
              ['How it works', '#how'],
              ['Tech stack', '#tech'],
            ].map(([label, href]) => (
              <li key={href}>
                <a href={href} className="text-white/55 transition-colors hover:text-ember-bright">
                  {label}
                </a>
              </li>
            ))}
          </ul>
        </div>

        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.25em] text-white/40">Platform</p>
          <ul className="mt-4 space-y-2.5 text-sm text-white/55">
            <li>Customer App · Flutter</li>
            <li>Vendor App · Flutter</li>
            <li>Admin Dashboard · React</li>
            <li>API · FastAPI + PostgreSQL</li>
          </ul>
        </div>
      </div>

      <div className="mx-auto mt-12 flex max-w-6xl flex-col items-center justify-between gap-3 px-6 text-xs text-white/35 sm:flex-row">
        <p>© {new Date().getFullYear()} Ibajay Eats. All rights reserved.</p>
        <p className="flex items-center gap-1.5">
          Made with
          <svg width="11" height="11" viewBox="0 0 24 24" fill="#E85D2A" aria-hidden>
            <path d="M12 21s-8-5.5-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 10c0 5.5-8 11-8 11z" />
          </svg>
          in Ibajay, Aklan
        </p>
      </div>
    </footer>
  )
}
