import { createContext, useContext, useEffect, useRef, useState } from 'react'
import type { ReactNode } from 'react'

/**
 * Auto-refresh heartbeat. Pages re-run their API fetches on every tick
 * (~30s), keeping KPIs, orders and vendor lists current without a manual
 * reload.
 */

interface LiveContextValue {
  /** Increments on every simulated refresh. */
  tick: number
  lastUpdatedAt: number
}

const LiveContext = createContext<LiveContextValue>({ tick: 0, lastUpdatedAt: Date.now() })

const REFRESH_MS = 30_000

export function LiveProvider({ children }: { children: ReactNode }) {
  const [tick, setTick] = useState(0)
  const [lastUpdatedAt, setLastUpdatedAt] = useState(Date.now())
  const timer = useRef<number | null>(null)

  useEffect(() => {
    timer.current = window.setInterval(() => {
      setLastUpdatedAt(Date.now())
      setTick((t) => t + 1)
    }, REFRESH_MS)
    return () => {
      if (timer.current !== null) window.clearInterval(timer.current)
    }
  }, [])

  return (
    <LiveContext.Provider value={{ tick, lastUpdatedAt }}>
      {children}
    </LiveContext.Provider>
  )
}

export function useLive(): LiveContextValue {
  return useContext(LiveContext)
}

/** Runs an async fetcher whenever the live tick or deps change. */
export function useAsyncData<T>(
  fn: () => T | Promise<T>,
): { data: T | null; loading: boolean } {
  const { tick } = useLive()
  const [data, setData] = useState<T | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let alive = true
    Promise.resolve(fn()).then((result) => {
      if (!alive) return
      setData(result)
      setLoading(false)
    })
    return () => {
      alive = false
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tick])

  return { data, loading }
}
