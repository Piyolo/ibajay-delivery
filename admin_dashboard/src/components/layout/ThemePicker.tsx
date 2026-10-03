import { useEffect, useRef, useState } from 'react'
import { Check, Palette } from 'lucide-react'
import { THEMES, useTheme } from '../../state/theme'
import type { ThemeId } from '../../state/theme'

export function ThemePicker() {
  const { theme, setTheme } = useTheme()
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const onDown = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') setOpen(false)
    }
    document.addEventListener('mousedown', onDown)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onDown)
      document.removeEventListener('keydown', onKey)
    }
  }, [open])

  const current = THEMES.find((t) => t.id === theme) ?? THEMES[0]

  return (
    <div className="theme-picker" ref={ref}>
      <button
        type="button"
        className="theme-picker-btn"
        onClick={() => setOpen((v) => !v)}
        title="Change dashboard theme"
      >
        <Palette />
        <span className="tp-current-dot" style={{ background: current.swatch.accent }} />
        {current.label}
      </button>
      {open && (
        <div className="theme-pop" role="listbox" aria-label="Dashboard theme">
          <div className="tp-title">Dashboard theme</div>
          {THEMES.map((t) => (
            <button
              key={t.id}
              type="button"
              className="theme-option"
              role="option"
              aria-selected={t.id === theme}
              onClick={() => {
                setTheme(t.id as ThemeId)
                setOpen(false)
              }}
            >
              <span
                className="tp-preview"
                style={
                  {
                    '--tp-bg': t.swatch.bg,
                    '--tp-surface': t.swatch.surface,
                  } as React.CSSProperties
                }
              />
              <span className="tp-meta">
                <span className="tp-name">{t.label}</span>
                <span className="tp-desc">{t.description}</span>
              </span>
              {t.id === theme && <Check className="tp-check" />}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
