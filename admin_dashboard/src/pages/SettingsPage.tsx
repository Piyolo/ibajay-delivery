import { useState } from 'react'
import { can, useAuth } from '../state/auth'
import { flash } from '../lib/flash'
import { Card, CardHead, PageHeader } from '../components/ui/primitives'

interface PlatformSettings {
  supportEmail: string
  maintenanceMode: boolean
  autoApproveVendors: boolean
  feeTiers: Array<{ range: string; fee: number }>
  gracePeriodDays: number
  maxDeliveryRadiusKm: number
}

const DEFAULTS: PlatformSettings = {
  supportEmail: 'support@ibaeats.ph',
  maintenanceMode: false,
  autoApproveVendors: false,
  feeTiers: [
    { range: '0–1 KM', fee: 20 },
    { range: '1–3 KM', fee: 30 },
    { range: '3–5 KM', fee: 50 },
    { range: '5–10 KM', fee: 80 },
  ],
  gracePeriodDays: 7,
  maxDeliveryRadiusKm: 10,
}

export function SettingsPage() {
  const { user } = useAuth()
  const editable = can(user?.role ?? 'staff', 'settings.edit')
  const [s, setS] = useState<PlatformSettings>(DEFAULTS)
  const [dirty, setDirty] = useState(false)

  const update = (patch: Partial<PlatformSettings>) => {
    if (!editable) return
    setS((prev) => ({ ...prev, ...patch }))
    setDirty(true)
  }

  return (
    <>
      <PageHeader
        title="Platform Settings"
        description={
          editable
            ? 'System-level configuration. Changes apply to the whole platform.'
            : 'Developer access required to modify platform settings.'
        }
      />

      <div className="grid-2">
        <Card>
          <CardHead title="General" />
          <div className="card-pad">
            <div style={{ marginBottom: 14 }}>
              <label className="field-label">Support email</label>
              <input
                className="input"
                style={{ width: '100%' }}
                value={s.supportEmail}
                disabled={!editable}
                onChange={(e) => update({ supportEmail: e.target.value })}
              />
            </div>
            <div style={{ marginBottom: 14 }}>
              <label className="field-label">Subscription grace period (days)</label>
              <input
                className="input"
                type="number"
                style={{ width: 140 }}
                value={s.gracePeriodDays}
                disabled={!editable}
                onChange={(e) => update({ gracePeriodDays: Number(e.target.value) || 0 })}
              />
            </div>
            <div>
              <label className="field-label">Max delivery radius (KM)</label>
              <select
                className="select"
                value={s.maxDeliveryRadiusKm}
                disabled={!editable}
                onChange={(e) => update({ maxDeliveryRadiusKm: Number(e.target.value) })}
              >
                {[2, 5, 10].map((km) => (
                  <option key={km} value={km}>{km} KM</option>
                ))}
              </select>
            </div>
          </div>
        </Card>

        <Card>
          <CardHead title="Feature flags" />
          <div className="card-pad">
            <ToggleRow
              label="Maintenance mode"
              hint="Shows a downtime notice in both mobile apps."
              checked={s.maintenanceMode}
              disabled={!editable}
              onChange={(v) => update({ maintenanceMode: v })}
            />
            <ToggleRow
              label="Auto-approve vendor applications"
              hint="Not recommended — keep manual review per Stage 1 policy."
              checked={s.autoApproveVendors}
              disabled={!editable}
              onChange={(v) => update({ autoApproveVendors: v })}
            />
          </div>
        </Card>
      </div>

      <Card style={{ marginTop: 14 }}>
        <CardHead title="Default delivery fee tiers" />
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Distance</th>
                <th>Fee (₱)</th>
              </tr>
            </thead>
            <tbody>
              {s.feeTiers.map((t) => (
                <tr key={t.range}>
                  <td><span className="cell-main">{t.range}</span></td>
                  <td>
                    <input
                      className="input"
                      type="number"
                      style={{ width: 100 }}
                      value={t.fee}
                      disabled={!editable}
                      onChange={(e) =>
                        update({
                          feeTiers: s.feeTiers.map((x) =>
                            x.range === t.range ? { ...x, fee: Number(e.target.value) || 0 } : x,
                          ),
                        })
                      }
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <div style={{ marginTop: 16 }} className="row-flex">
        <button
          className="btn primary"
          disabled={!editable || !dirty}
          onClick={() => {
            flash('Settings saved')
            setDirty(false)
          }}
        >
          Save changes
        </button>
        {!editable && (
          <span className="small muted">Read-only — developer role required.</span>
        )}
        {editable && dirty && (
          <span className="small muted">Unsaved changes</span>
        )}
      </div>
    </>
  )
}

function ToggleRow({
  label,
  hint,
  checked,
  disabled,
  onChange,
}: {
  label: string
  hint: string
  checked: boolean
  disabled?: boolean
  onChange: (v: boolean) => void
}) {
  return (
    <div
      className="row-flex"
      style={{
        justifyContent: 'space-between',
        padding: '12px 0',
        borderBottom: '1px solid var(--c-border)',
        opacity: disabled ? 0.6 : 1,
      }}
    >
      <div>
        <div className="cell-main" style={{ fontSize: 13 }}>{label}</div>
        <div className="cell-sub">{hint}</div>
      </div>
      <label style={{ cursor: disabled ? 'not-allowed' : 'pointer' }}>
        <input type="checkbox" checked={checked} disabled={disabled} onChange={(e) => onChange(e.target.checked)} />
      </label>
    </div>
  )
}
