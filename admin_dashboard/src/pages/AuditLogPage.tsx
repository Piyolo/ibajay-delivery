import { useMemo, useState } from 'react'
import { auditLog } from '../data/mockDb'
import { fmtDateTime, timeAgo } from '../lib/format'
import {
  Badge,
  Card,
  EmptyState,
  PAGE_SIZE,
  PageHeader,
  Pagination,
} from '../components/ui/primitives'
import { useLive } from '../state/live'

export function AuditLogPage() {
  const [actionF, setActionF] = useState('all')
  const [page, setPage] = useState(1)
  const { tick } = useLive()

  const actionGroups = useMemo(() => {
    void tick
    return [...new Set(auditLog.map((a) => a.action.split('.')[0]))]
  }, [tick])

  const filtered = auditLog.filter(
    (a) => actionF === 'all' || a.action.startsWith(actionF),
  )
  const pageCount = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE))
  const safePage = Math.min(page, pageCount)
  const rows = filtered.slice((safePage - 1) * PAGE_SIZE, safePage * PAGE_SIZE)

  return (
    <>
      <PageHeader
        title="Audit Logs"
        description="Append-only record of administrative actions across the platform."
      />

      <div className="filters-bar">
        <select className="select" value={actionF} onChange={(e) => setActionF(e.target.value)}>
          <option value="all">All actions</option>
          {actionGroups.map((g) => (
            <option key={g} value={g}>{g}</option>
          ))}
        </select>
        <div className="spacer" />
        <span className="small muted">{filtered.length} entries</span>
      </div>

      <Card>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>When</th>
                <th>Actor</th>
                <th>Action</th>
                <th>Target</th>
                <th>Detail</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((a) => (
                <tr key={a.id}>
                  <td>
                    <div className="cell-main small mono">{fmtDateTime(a.at)}</div>
                    <div className="cell-sub">{timeAgo(a.at)}</div>
                  </td>
                  <td>
                    <div className="cell-main small">{a.actorName}</div>
                    <div className="cell-sub" style={{ textTransform: 'capitalize' }}>{a.actorRole}</div>
                  </td>
                  <td>
                    <Badge tone={a.action.includes('reject') || a.action.includes('suspend') ? 'red' : a.action.includes('approv') ? 'green' : 'gray'} dot={false}>
                      {a.action}
                    </Badge>
                  </td>
                  <td><span className="cell-main small">{a.target}</span></td>
                  <td style={{ whiteSpace: 'normal', minWidth: 240 }} className="small muted">
                    {a.detail}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!rows.length && <EmptyState message="No log entries." />}
        </div>
        <Pagination page={safePage} pageCount={pageCount} total={filtered.length} onPage={setPage} />
      </Card>
    </>
  )
}
