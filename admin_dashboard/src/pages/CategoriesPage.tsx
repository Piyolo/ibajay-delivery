import { useState } from 'react'
import { Plus } from 'lucide-react'
import { categories as seedCategories } from '../data/mockDb'
import type { Category } from '../types'
import { can, useAuth } from '../state/auth'
import { flash } from '../lib/flash'
import {
  Badge,
  Card,
  EmptyState,
  PageHeader,
} from '../components/ui/primitives'

export function CategoriesPage() {
  const { user } = useAuth()
  const canManage = can(user?.role ?? 'staff', 'categories.manage')
  // Local working copy so adds/toggles survive navigation within the session.
  const [items, setItems] = useState<Category[]>(seedCategories)
  const [draft, setDraft] = useState('')

  const add = () => {
    const name = draft.trim()
    if (!name) return
    setItems((prev) => [
      ...prev,
      { id: `cat${prev.length + 1}`, name, productCount: 0, vendorCount: 0, active: true },
    ])
    flash(`Category "${name}" created`)
    setDraft('')
  }

  return (
    <>
      <PageHeader
        title="Product Categories"
        description="Platform-wide menu categories available to vendors."
        actions={
          canManage && (
            <div className="row-flex">
              <input
                className="input"
                placeholder="New category name…"
                value={draft}
                onChange={(e) => setDraft(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && add()}
              />
              <button className="btn primary" onClick={add} disabled={!draft.trim()}>
                <Plus /> Add
              </button>
            </div>
          )
        }
      />

      <Card>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Category</th>
                <th className="num">Products</th>
                <th className="num">Vendors Using</th>
                <th>Status</th>
                {canManage && <th>Actions</th>}
              </tr>
            </thead>
            <tbody>
              {items.map((c) => (
                <tr key={c.id}>
                  <td><span className="cell-main">{c.name}</span></td>
                  <td className="num">{c.productCount}</td>
                  <td className="num">{c.vendorCount}</td>
                  <td>
                    <Badge tone={c.active ? 'green' : 'gray'}>{c.active ? 'Active' : 'Archived'}</Badge>
                  </td>
                  {canManage && (
                    <td>
                      <button
                        className={`btn xs ${c.active ? 'danger' : 'ghost'}`}
                        onClick={() => {
                          setItems((prev) =>
                            prev.map((p) => (p.id === c.id ? { ...p, active: !p.active } : p)),
                          )
                          flash(c.active ? `"${c.name}" archived` : `"${c.name}" reactivated`)
                        }}
                      >
                        {c.active ? 'Archive' : 'Restore'}
                      </button>
                    </td>
                  )}
                </tr>
              ))}
            </tbody>
          </table>
          {!items.length && <EmptyState message="No categories defined." />}
        </div>
      </Card>

      {!canManage && (
        <p className="small muted" style={{ marginTop: 10 }}>
          You have view-only access to categories.
        </p>
      )}
    </>
  )
}
