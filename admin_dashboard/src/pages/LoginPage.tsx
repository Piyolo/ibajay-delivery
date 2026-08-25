import { useState } from 'react'
import { Flame, ShieldCheck, Store, UserCog } from 'lucide-react'
import type { LucideIcon } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import type { Role } from '../types'
import { DEMO_USERS, useAuth } from '../state/auth'

const ROLES: Array<{ role: Role; icon: LucideIcon; title: string; desc: string }> = [
  {
    role: 'developer',
    icon: UserCog,
    title: 'Developer',
    desc: 'Full system access — staff management, platform settings, audit logs.',
  },
  {
    role: 'manager',
    icon: ShieldCheck,
    title: 'Manager',
    desc: 'Approve and manage vendors and orders, monitor operations and analytics.',
  },
  {
    role: 'staff',
    icon: Store,
    title: 'Staff',
    desc: 'Monitoring only — view orders, vendors and customers without modification rights.',
  },
]

export function LoginPage() {
  const [selected, setSelected] = useState<Role | null>(null)
  const { signIn } = useAuth()
  const navigate = useNavigate()

  const proceed = () => {
    if (!selected) return
    signIn(selected)
    navigate('/', { replace: true })
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

        <div className="card card-pad">
          <div style={{ marginBottom: 14 }}>
            <span className="field-label">Sign in as</span>
            {ROLES.map((r) => (
              <div
                key={r.role}
                className={`role-card ${selected === r.role ? 'selected' : ''}`}
                onClick={() => setSelected(r.role)}
              >
                <div className="rc-icon">
                  <r.icon size={17} />
                </div>
                <div>
                  <h4>{r.title}</h4>
                  <p>{r.desc}</p>
                </div>
              </div>
            ))}
          </div>
          <button
            className="btn primary"
            style={{ width: '100%' }}
            disabled={!selected}
            onClick={proceed}
          >
            Sign in{selected ? ` as ${DEMO_USERS[selected].name}` : ''}
          </button>
          <p className="login-foot" style={{ marginTop: 12 }}>
            Stage 1 prototype — authentication is simulated, no backend connected.
          </p>
        </div>
      </div>
    </div>
  )
}
