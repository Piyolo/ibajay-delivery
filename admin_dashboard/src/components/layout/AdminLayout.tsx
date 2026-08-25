import { useEffect, useState } from 'react'
import type { ReactNode } from 'react'
import { Sidebar } from './Sidebar'
import { Topbar } from './Topbar'
import { onFlash } from '../../lib/flash'

export function AdminLayout({ children }: { children: ReactNode }) {
  const [flashMsg, setFlashMsg] = useState<string | null>(null)

  useEffect(() => {
    let timer: number | null = null
    const off = onFlash((msg) => {
      setFlashMsg(msg)
      if (timer !== null) window.clearTimeout(timer)
      timer = window.setTimeout(() => setFlashMsg(null), 2600)
    })
    return () => {
      off()
      if (timer !== null) window.clearTimeout(timer)
    }
  }, [])

  return (
    <div className="app-shell">
      <Sidebar />
      <div className="main-col">
        <Topbar />
        <main className="content">
          <div className="content-inner">{children}</div>
        </main>
      </div>
      {flashMsg && <div className="flash-bar">{flashMsg}</div>}
    </div>
  )
}
