import { useEffect, useState } from 'react'

const LINKS = [
  { label: 'Customer', href: '#customer' },
  { label: 'Vendor', href: '#vendor' },
  { label: 'How it works', href: '#how' },
  { label: 'Tech', href: '#tech' },
]

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 40)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${
        scrolled ? 'py-3' : 'py-6'
      }`}
    >
      <nav
        className={`mx-auto flex max-w-6xl items-center justify-between rounded-2xl px-5 py-3 transition-all duration-500 ${
          scrolled ? 'glass mx-4 md:mx-auto shadow-lg shadow-black/20' : 'bg-transparent'
        }`}
      >
        <a href="#top" className="flex items-center gap-2.5 group">
          <img
            src="/logo.png"
            alt="Ibajay Eats logo"
            className="h-9 w-9 rounded-xl object-cover ring-1 ring-white/15 transition-transform duration-500 group-hover:rotate-[10deg]"
          />
          <span className="font-display text-lg font-bold tracking-tight">
            Ibajay<span className="text-gradient">Eats</span>
          </span>
        </a>

        <ul className="hidden md:flex items-center gap-8">
          {LINKS.map((l) => (
            <li key={l.href}>
              <a
                href={l.href}
                className="relative text-sm font-medium text-white/70 transition-colors hover:text-white after:absolute after:-bottom-1 after:left-0 after:h-px after:w-0 after:bg-gradient-to-r after:from-ember after:to-gold after:transition-all after:duration-300 hover:after:w-full"
              >
                {l.label}
              </a>
            </li>
          ))}
        </ul>

        <a
          href="#cta"
          className="rounded-full bg-gradient-to-r from-ember to-ember-dark px-5 py-2 text-sm font-semibold text-white transition-all duration-300 hover:shadow-glow hover:-translate-y-0.5"
        >
          Get the App
        </a>
      </nav>
    </header>
  )
}
