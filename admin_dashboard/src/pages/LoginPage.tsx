import { useState } from 'react'
import { Flame, LoaderCircle } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../state/auth'

export function LoginPage() {
  const [mobile, setMobile] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const { signInWithPassword } = useAuth()
  const navigate = useNavigate()

  const submit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!mobile.trim() || !password || busy) return
    setBusy(true)
    setError(null)
    try {
      await signInWithPassword(mobile.trim(), password)
      navigate('/', { replace: true })
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not sign in')
      setBusy(false)
    }
  }

  return (
    <div className="login-wrap">
      <div className="login-card">
        <div className="login-brand">
          <div className="mark">
            <Flame size={22} />
          </div>
          <div>
            <h1>Ibajay Eats — Admin</h1>
            <p>Internal console · Local Food Delivery Platform</p>
          </div>
        </div>

        <form className="card card-pad" onSubmit={submit}>
          <label className="field-label" htmlFor="admin-mobile">Mobile Number</label>
          <input
            id="admin-mobile"
            className="input"
            style={{ width: '100%', marginBottom: 12 }}
            placeholder="09123456789"
            inputMode="tel"
            autoComplete="username"
            value={mobile}
            onChange={(e) => setMobile(e.target.value)}
            autoFocus
          />

          <label className="field-label" htmlFor="admin-password">Password</label>
          <div style={{ display: 'flex', gap: 8, marginBottom: 14 }}>
            <input
              id="admin-password"
              className="input"
              style={{ width: '100%' }}
              type={showPassword ? 'text' : 'password'}
              placeholder="••••••••"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            <button
              type="button"
              className="btn ghost"
              onClick={() => setShowPassword((v) => !v)}
              title={showPassword ? 'Hide password' : 'Show password'}
            >
              {showPassword ? 'Hide' : 'Show'}
            </button>
          </div>

          {error && (
            <p style={{ color: '#c0392b', fontSize: 13, marginTop: -6, marginBottom: 10 }}>
              {error}
            </p>
          )}

          <button className="btn primary" style={{ width: '100%' }} disabled={busy}>
            {busy ? (
              <>
                <LoaderCircle size={15} style={{ animation: 'spin 1s linear infinite' }} /> Signing in…
              </>
            ) : (
              'Sign in'
            )}
          </button>
          <p className="login-foot" style={{ marginTop: 12 }}>
            Administrator accounts only — access is validated against the platform backend.
          </p>
        </form>
      </div>
    </div>
  )
}
