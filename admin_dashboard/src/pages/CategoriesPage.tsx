import { api } from '../lib/api'
import { useAsyncData } from '../state/live'
import {
  Card,
  EmptyState,
  PageHeader,
} from '../components/ui/primitives'

interface AdminCategoryRow {
  name: string
  vendor_count: number
  product_count: number
}

export function CategoriesPage() {
  const items = useAsyncData(() => api<AdminCategoryRow[]>('/admin/categories')).data ?? []

  return (
    <>
      <PageHeader
        title="Product Categories"
        description="Categories observed across vendor tags and the food catalog. Read-only — category management endpoints are not available yet."
      />

      <Card>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Category</th>
                <th className="num">Products</th>
                <th className="num">Vendors Using</th>
              </tr>
            </thead>
            <tbody>
              {items.map((c) => (
                <tr key={c.name}>
                  <td><span className="cell-main">{c.name}</span></td>
                  <td className="num">{c.product_count}</td>
                  <td className="num">{c.vendor_count}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {!items.length && <EmptyState message="No categories found." />}
        </div>
      </Card>
    </>
  )
}
