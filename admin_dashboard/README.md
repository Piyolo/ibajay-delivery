# Ibajay Eats — Admin Dashboard (React)

Internal console for the Local Food Delivery Platform — Stage 1 Beta,
frontend-only per `06_Admin_Dashboard_Frontend_Prompt.docx`. Runs entirely
on deterministic mock data (`src/data/mockDb.ts`); no backend connected.

## Roles

Sign in on the login screen as any of the three personas (auth is simulated):

| Role | Access |
| --- | --- |
| **Developer** | Everything, including Staff management, Platform Settings and Audit Logs |
| **Manager** | Vendors (approve/reject/suspend/verify), Orders, Customers, Analytics, Categories, Reviews, Subscriptions |
| **Staff** | Monitoring only — view orders/vendors/customers/analytics; can hide *flagged* reviews |

## Modules

- **Dashboard**: today's KPIs vs yesterday, 14-day revenue/orders charts,
  recent orders, top vendors, best sellers.
- **Vendors**: searchable/filterable table with approve · reject · suspend ·
  reinstate · verify actions (role-gated), plus a full vendor detail page
  (profile, subscription, recent orders, reviews).
- **Orders**: filters by status / vendor / method / date range, pagination,
  slide-over detail with a status timeline matching the apps'
  7-status flow.
- **Analytics**: overview (funnel, leaderboard), sales (daily/weekly/monthly/
  annual + AOV), vendor analytics (growth, plan distribution).
- **Staff / Categories / Reviews / Subscriptions / Settings / Audit Logs**
  per the spec's recommended navigation.

## Design system

Reuses the mobile apps' tokens (`customer_app/lib/theme/app_theme.dart`):
ember `#E85D2A`, teal `#1F6F5C`, warm cream surfaces, same order-status
color mapping. Enterprise-dense tables, tabular numerals, ₱ (PHP) currency.

## Live simulation

Per spec: no WebSockets. Every ~30 seconds the mock dataset advances
(pending orders move through the status flow, new ones occasionally arrive)
and all pages refresh — watch the "Updated Xs ago" chip in the topbar.

## Running

```bash
npm install
npm run dev      # http://localhost:5173
npm run build    # typecheck + production build
```

## Wiring to the real backend (next step)

Same seam pattern as the mobile apps' repositories: every page reads via
selectors in `src/data/mockDb.ts`. Replace that module's internals with
`fetch` calls against FastAPI's `/api/v1/*` endpoints (add an `admin` role +
JWT) and swap the simulated tick in `src/state/live.tsx` for real
WebSockets or polling — no page components need to change.
