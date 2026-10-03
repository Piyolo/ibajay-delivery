import { createContext, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'

export type ThemeId = 'light' | 'dark' | 'glass' | 'neumorphism' | 'flat'

export interface ThemeOption {
  id: ThemeId
  label: string
  description: string
  /** Colors used to render the mini preview swatch in the picker */
  swatch: { bg: string; surface: string; accent: string }
}

export const THEMES: ThemeOption[] = [
  {
    id: 'light',
    label: 'Light',
    description: 'Clean, bright workspace',
    swatch: { bg: '#f6f3f0', surface: '#ffffff', accent: '#e85d2a' },
  },
  {
    id: 'dark',
    label: 'Dark',
    description: 'Easy on the eyes at night',
    swatch: { bg: '#171412', surface: '#2b2623', accent: '#f0733d' },
  },
  {
    id: 'glass',
    label: 'Glass Morphism',
    description: 'Frosted translucent panels',
    swatch: { bg: 'linear-gradient(135deg,#6d5df6,#38c6b8)', surface: 'rgba(255,255,255,0.55)', accent: '#e85d2a' },
  },
  {
    id: 'neumorphism',
    label: 'Neumorphism',
    description: 'Soft extruded surfaces',
    swatch: { bg: '#e8e4de', surface: '#e8e4de', accent: '#e85d2a' },
  },
  {
    id: 'flat',
    label: 'Flat Design',
    description: 'Bold solids, no shadows',
    swatch: { bg: '#f1efeb', surface: '#ffffff', accent: '#e85d2a' },
  },
]

const STORAGE_KEY = 'ibajay-admin-theme'

function initialTheme(): ThemeId {
  try {
    const stored = window.localStorage.getItem(STORAGE_KEY)
    if (stored && THEMES.some((t) => t.id === stored)) {
      return stored as ThemeId
    }
  } catch {
    /* storage unavailable */
  }
  return 'light'
}

interface ThemeCtx {
  theme: ThemeId
  setTheme: (t: ThemeId) => void
}

const ThemeContext = createContext<ThemeCtx | null>(null)

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<ThemeId>(initialTheme)

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    document.documentElement.style.colorScheme = theme === 'dark' ? 'dark' : 'light'
    try {
      window.localStorage.setItem(STORAGE_KEY, theme)
    } catch {
      /* storage unavailable */
    }
  }, [theme])

  const value = useMemo(
    () => ({ theme, setTheme: (t: ThemeId) => setThemeState(t) }),
    [theme],
  )

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

export function useTheme(): ThemeCtx {
  const ctx = useContext(ThemeContext)
  if (!ctx) throw new Error('useTheme must be used inside ThemeProvider')
  return ctx
}
