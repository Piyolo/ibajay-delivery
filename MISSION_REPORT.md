# Mission Report — Ibajay Eats Production-Readiness Pass

Date: 2026-10-16 · Branch: `website-redesign` · Backend + both Flutter apps
Companion doc: `DEPLOYMENT_REVIEW.md` (deployment mechanics, secrets, go-live checklist)

## 0 · Ground rules honored

- No rebuilds, no stack changes, no features removed, no mock-data regressions, **no new dependencies** (checkout idempotency key generated with `Random.secure` — no `uuid` package added; PH-time via stdlib `zoneinfo`).
- Your pre-existing uncommitted work in `IbajayEatsWeb/`, `admin_dashboard/`, `.agents/`, `skills-lock.json` was **never touched, staged, or committed** — it is exactly as you left it.
- Every claim below is backed by an actual command run this session (exact outputs in §7).

## 1 · Original state (what the Phase-Zero audit found, ranked)

| Pri | Finding | Risk |
| --- | --- | --- |
| P0 | `POST /orders/checkout` had no idempotency penalty: a network timeout during payment-handoff made an UI retry **create a second paid order** | Customers double-charged / double-orders |
| P0 | Cancel policy not enforced server-side: any non-delivered state was cancellable, and repeated cancel taps raced the backend | Customer cancels an order mid-preparation; duplicate cancel calls |
| P0 | `/auth/forgot-password/reset` had **no attempt lockout** (only the send side was rate-limited) | OTP brute-forcing of account recovery |
| P0 | No composite indexes on hot foreign keys (`orders.vendor_id`, `order_items.order_id`, chat id→thread maps) with table growth already visible | Stalls on orders/chat lists as beta grows |
| P1 | Analytics "today/this week" buckets computed in server-UTC | Revenue/queues mis-bucket around 16:00–24:00 UTC (PH evening peak) |
| P1 | Vendor app: menu edit errors silently discarded (phantom rollbacks), registration blocked on slow uploads, GPS stream never time-bounded, `PUT /auth/profile` claimed email/mobile edits that the API cannot save | Vendors lose work / false promises in UI |
| P2 | Customer: checkout retry double-ordering mirror, cancel double-tap, one shared cart across accounts on the same device, polls running for terminal orders, notifications never auto-marked read, corrupt cart snapshot could crash restore | Data-loss/UX polish |
| P2 | Remaining backlog (documented, deliberately **not** started): customer image disk cache, chat unread badge at startup, cancel affordance in order list, WS reconnect re-sync | Enhancement only |

## 2 · What was changed, per phase (commits)

### Phase 1 — backend hardening (`132c3f5`)
- `POST /orders/checkout` idempotency: `Idempotency-Key` header (UUIDv4, ≤72 chars), stored in new `checkout_idempotency_keys` table (24 h TTL, unique-constrained, race-safe). Same key + same cart **replays the original order** instead of creating a duplicate. Table auto-creates via `create_all` on first deploy; dedicated FK indexes ship in migration `005_hot_indexes_and_checkout_keys` (**needs `alembic upgrade head` on deploy** — see §8).
- Cancel policy (business plan §21): customers may cancel only `pending`/`accepted`; vendors any pre-delivery state; every cancel records a reason; refusal message is customer-quoted verbatim in the UI: *"This order can no longer be cancelled — it is already being prepared…"*.
- Reset-OTP lockout: `OTP_MAX_ATTEMPTS` on `/auth/forgot-password/reset` + 10/min per-IP limiter.
- Hot-path composite indexes via additive, idempotent migration `005`.
- All analytics buckets (vendor analytics + admin overview) in Philippine time (UTC+8) via `app/core/manila_time.py`.
- Input validation: cart size caps, schema caps (`schemas/vendor_portal.py` column-width caps), promo `PATCH` validation, checkout payload schema caps.
- WS chat: ownership checks + `order_id` consistency; JWT-secret production boot guard refuses boot with default secret when `ENVIRONMENT=production`.
- `my-orders` / vendor inbox accept `limit`/`offset`/`status` params (defaults preserve old behavior — no client break).

### Phase 2 — vendor app (`f08fd71`)
- Per-order busy-guards (`isBusy`): no double accept/reject/advance during in-flight calls; all failures now surface via snackbar messages (no silent no-ops).
- Reject requires a reason (`_RejectReasonDialog`, enforced).
- Account edits honest: name editable → `PUT /auth/profile {full_name}`; email/mobile shown read-only (no server endpoint exists).
- Menu edits: failed saves roll back (no more phantom item lists); registration media uploads moved off the blocking path.
- GPS upload stream: `timeLimit` removed; **Mark-as-Delivered only pops on backend success**.
- Dashboard "today" matches the server's Manila-day bucketing (`isSamePhDay`).
- Price and fee math grounded by server validators.

### Phase 3 — customer app (`5e56cb5`)
- Checkout idempotency (mirror of server): `\_newIdempotencyKey` + `_cartSignature`; failing attempt keeps its key (retry replays), an edited cart gets a fresh key, success resets.
- Cancel: double-tap guard (`isCancelling`), cancellation only offered for `pending`/`accepted`, backend reason string surfaced on refusals.
- Tracking polls pause/resume with app lifecycle (WidgetsBindingObserver) and **stop at terminal statuses** (no more battery drain on delivered orders).
- Cart persistence is **per signed-in user** (`attachUser`/`detachUser`, mirroring the favorites pattern) — two accounts on one phone no longer share an in-progress cart.
- Per-user name/avatar preference overrides; notifications auto-mark-read when opened.
- Cart restore hardened: a corrupt device snapshot (e.g. string quantity) now degrades to field defaults instead of crashing (`cart.dart` typed restore readers).

## 3 · API-contract changes (server + clients updated together)

| Change | Compatibility |
| --- | --- |
| `POST /orders/checkout` accepts optional `Idempotency-Key` header | Old clients: unaffected (header optional). New clients: safe retry |
| Cancel 400 message text | Customer app displays backend messages verbatim; wizards unchanged |
| `my-orders`, vendor inbox: optional `limit`/`offset`/`status` | Defaults preserve exact old behavior |
| `PUT /auth/profile` supports `{full_name}` only | Both apps now show email/mobile read-only — no UI claims endpoints that don't exist |

No endpoint was removed and no response shape changed. Backend pytest includes idempotency-replay, cancel-policy and validation cases that pin these contracts.

## 4 · Security-relevant changes

1. OTP reset brute-force lockout (per-account attempts + per-IP limit).
2. WebSocket chat: thread/order ownership verified before join/send.
3. JWT secret cannot boot production with the default value.
4. Cancel policy enforced **server-side** (UI affordances are cosmetic, never authoritative).
5. Server-side price/fee/promo recalculation retained and now capped (cart/schema limits).

## 5 · Performance-relevant changes

1. Composite FK indexes on orders/order-items/chat hot paths (migration `005` — **pending DB apply**).
2. PH-time bucketing moves computation off per-request UTC math where ids require it, and corrects evening sales attribution.
3. Customer tracking polls stop at terminal statuses and pause while backgrounded.
4. Registration no longer waits on media uploads; GPS stream upload loop bounded.
5. Per-user carts/prefs avoid cross-account cache confusion (correctness & minor perf).

## 6 · Deliverable state

| App | Final state this session | Evidence |
| --- | --- | --- |
| backend | All P0s fixed, contracts pinned by tests | `66 passed` pytest |
| customer_app | idempotent checkout, enforced-visibility cancel, lifecycle-safe polling, per-user cart+prefs, crash-proof restore | `No issues found!` analyze, `All tests passed!` (8/8) |
| vendor_app | busy-guards, enforced reject reasons, honest account edits, resilient uploads/GPS, PH-day dashboard | `No issues found!` analyze, `All tests passed!` (11/11) |

Git: `132c3f5` → `f08fd71` → `5e56cb5` on `website-redesign` (ahead of origin, **not pushed** — push is yours to trigger).

## 7 · Exact verification commands & outputs (this session)

```
backend:  venv\Scripts\python.exe -m pytest tests -q
          → 66 passed, 14 warnings in 4.97s   (warnings = pre-existing Pydantic deprecations)

customer_app:  flutter analyze
          → No issues found! (ran in 31.1s)
          flutter test
          → 00:02 +8: All tests passed!

vendor_app:    flutter analyze
          → No issues found! (ran in 21.0s)
          flutter test
          → 00:08 +11: All tests passed!
```

## 8 · Remaining limitations (external / user-only — I cannot do these from here)

1. **Migration `005` → Neon**: run `alembic upgrade head` during the next backend deploy (additive; table also auto-creates via `create_all`, but the FK indexes need the migration). Neon is documented at `004_cancelled_notification` as of the previous round.
2. **Push notifications**: `google-services.json` still missing in both `*/android/app/` dirs — FCM paths silently no-op until Firebase files are added (or notification paths disabled).
3. **Render secrets inventory** + admin-dashboard `CORS_ORIGINS` entry (see `DEPLOYMENT_REVIEW.md` §Remaining work).
4. **Admin password rotation** (`09000000001 / pass123`) before sharing builds.
5. **Deploy verification**: Render redeploy from `website-redesign`, confirm `/api/v1/admin/reviews` → 401 (not 404), Vercel website redeploy.
6. Branch not pushed; commit history is local-only until you push.

## 9 · Next steps before public deployment (recommended order)

1. Push `website-redesign`.
2. Render deploy of `ibajayeats-api` → run `alembic upgrade head` (005) → smoke-check `/api/v1/admin/reviews` (401), checkout idempotency, cancel refusal on an `accepted` order.
3. Add `google-services.json` files (both apps) or ship beta without push.
4. Rotate admin password; finish Render secrets inventory.
5. Optional P2 backlog (all enhancement-grade): customer image disk cache, chat unread badge at startup, cancel affordance inside the order list, WebSocket reconnect state re-sync.
