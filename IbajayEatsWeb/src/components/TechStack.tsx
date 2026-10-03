import { motion } from 'framer-motion'

const GROUPS = [
  {
    label: 'Mobile',
    items: ['Flutter', 'Dart', 'Provider', 'Google Maps SDK'],
    color: '#F07A4E',
  },
  {
    label: 'Backend',
    items: ['FastAPI', 'PostgreSQL', 'SQLAlchemy', 'WebSockets', 'JWT + bcrypt'],
    color: '#2AA184',
  },
  {
    label: 'Services',
    items: ['Firebase', 'Cloudinary', 'Resend', 'Alembic'],
    color: '#FFB845',
  },
]

export default function TechStack() {
  return (
    <section id="tech" className="relative z-10 py-16 sm:py-28">
      <div className="mx-auto max-w-6xl px-6">
        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, margin: '-80px' }}
          transition={{ duration: 0.8 }}
          className="flex flex-col items-start justify-between gap-6 md:flex-row md:items-end"
        >
          <div>
            <span className="section-chip section-chip--moss">Built with</span>
            <h2 className="mt-5 font-display text-4xl font-bold tracking-tight sm:text-5xl">
              The stack behind the sarap.
            </h2>
          </div>
          <p className="max-w-sm text-sm leading-relaxed text-white/50">
            Mock-first architecture with clean repository seams — the apps run standalone,
            then wire straight into the FastAPI backend when it's live.
          </p>
        </motion.div>

        <div className="mt-14 grid gap-4 md:grid-cols-3">
          {GROUPS.map((group, gi) => (
            <motion.div
              key={group.label}
              initial={{ opacity: 0, y: 30 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true, margin: '-60px' }}
              transition={{ duration: 0.7, delay: gi * 0.1 }}
              className="rounded-3xl border border-white/[0.08] bg-white/[0.03] p-7 backdrop-blur-sm"
            >
              <p
                className="text-xs font-semibold uppercase tracking-[0.25em]"
                style={{ color: group.color }}
              >
                {group.label}
              </p>
              <ul className="mt-5 flex flex-wrap gap-2">
                {group.items.map((item) => (
                  <li
                    key={item}
                    className="rounded-full border border-white/10 bg-white/[0.05] px-3.5 py-1.5 text-sm font-medium text-white/75 transition-all duration-300 hover:-translate-y-0.5 hover:text-white"
                    onMouseEnter={(e) => {
                      e.currentTarget.style.borderColor = `${group.color}66`
                      e.currentTarget.style.boxShadow = `0 6px 24px -8px ${group.color}55`
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.borderColor = ''
                      e.currentTarget.style.boxShadow = ''
                    }}
                  >
                    {item}
                  </li>
                ))}
              </ul>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  )
}
