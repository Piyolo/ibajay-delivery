# Pre-Deployment Review — Ibajay Eats Beta

Date: 2026-10-03 (updated 2026-10-14)
Prepared during the beta-readiness pass (branch: `website-redesign`).

## What was done

| Item | Status |
| --- | --- |
| Full working-tree backup | ✅ `OneDrive\Documents\Work\IbaEats\backup_2026-10-03` |
| All work committed & pushed | ✅ `origin/website-redesign` head `776d398` |
| `apps/customer-vendor-latest` merged → `website-redesign` | ✅ |
| Vendor add-on crash | ✅ fixed, emulator-verified |
| Account-settings cancel crash | ✅ fixed, emulator-verified |
| Store profile avatar clipping | ✅ fixed, emulator-verified |
| Customer "Set Your Location" every login | ✅ fixed, emulator-verified |
| Admin dashboard on live API (mockDb deleted) | ✅ `tsc --noEmit` + `npm run build` pass |
| Admin API endpoints (reviews/categories/staff/subscriptions/activity) | ✅ live-tested, all 200 |
| Admin account | ✅ `09000000001` / `pass123` (rotate after beta) |
| Alembic consolidation (`002_add_barangay_addresses`) | ✅ applied, `alembic_version` at head |
| One-shot SQL patch files removed | ✅ |
| Fresh beta APKs `0.2.0+2` | ✅ `dist/*-0.2.0+2-beta.apk` |
| Vendor "no internet" false error | ✅ root cause: missing INTERNET permission in main manifest — fixed, A/B verified |
| Session persistence (no spurious logout on reopen) | ✅ only a genuine 401 ends a session; timeouts/5xx keep the cached one |
| Version-stamped sessions (update → clean re-login) | ✅ both apps stamp `session_app_version`; mismatch forces fresh login |
| Mid-session 401 handling | ✅ one silent refresh, then clean sign-out + navigation to login |
| Customer address sync to server | ✅ `LocationProvider` now shares the auth client (was silently unauthenticated) |
| Vendor setup wall on 404 | ✅ account without store now routes to Store Setup instead of force sign-out |
| Token revocation (password change) | ✅ `token_version` column + `tv` claim; migration `003` **applied to Neon** |
| Rate limiting on `/auth/login` + OTP send | ✅ in-memory limiter (5/min failed logins per IP+mobile; 3/min OTP sends per IP) |
| Tracking endpoint authorization | ✅ `gps-ping` + order/chat WebSockets now verify ownership |
| Backend smoke tests | ✅ `backend/tests/` — 26 passing |
| `render.yaml` JWT secret | ✅ pinned (`sync: false`) — set/back up manually, never rotate |
| Fresh beta APKs `0.2.0+3` | ✅ `dist/*-0.2.0+3-beta.apk` (customer + vendor) |
| Beta round-2 bug batch (19 items, both apps + backend) | ✅ fixed/implemented 2026-10-14; verified: pytest 26/26, both apps analyze-clean + tests green |
| Add-on totals (backend + both apps) | ✅ checkout now prices selected choices server-side; apps read `line_total` |
| Chat stability (vendor) | ✅ thread polling no longer wipes an open chat; previews merge instead of blanking; order→thread matching fixed |
| Order status stepper + store-status pill on Orders | ✅ stepper alignment fixed; Orders now uses Dashboard's status dialog |
| Pull-to-refresh (vendor Orders, customer orders/tracking) | ✅ + customer tracking auto-polls every 12s |
| Address overwrite + barangay pickers | ✅ home top-bar save appends; Manage Addresses + setup flows share searchable picker |
| Category filter (customer home) | ✅ applies to Featured/Popular and item lists |
| Profile name persistence | ✅ new `PUT /auth/profile`; name saves server-side |
| In-app notification center (customer) | ✅ bell + unread badge; backend now persists `notify_order_event` rows; `GET /notifications`, `POST /notifications/read-all` |
| Call customer (vendor) | ✅ chats, order detail, delivery tracking via `tel:` (`url_launcher`); thread payload now carries `customer_mobile` |
| Customer order reviews | ✅ review dialog on delivered orders (backend endpoints already existed) |
| Store setup delivery settings parity | ✅ setup wizard reuses the logged-in BarangaySelector (search + All/None) |
| OTP email failures | ✅ send-before-commit + loud logging; failed sends now return 502 instead of silent "sent" |
| Live tracking visibility (customer) | ✅ map always renders when out-for-delivery (waiting-for-ping state); status card earlier in the flow |
| Alembic `004_cancelled_notification` | ✅ applied to Neon (head) |

## ⚠️ Deploy ordering (backend)

**Migrations `003_add_token_version` and `004_cancelled_notification` are already applied to Neon** (verified: `alembic_version = 004_cancelled_notification (head)`). The next Render deploy of the backend MUST include this code — it is forward-only compatible: the new code requires the `tv` claim, and every token issued before the deploy lacks it, so **all users are logged out once on the next backend deploy** (they log back in normally). Do not roll the backend back after this deploy without also rolling back the migrations.

Also in this deploy: `POST /auth/register/start` and `/auth/forgot-password/start` now return **502 when the OTP email fails to send** (previously they silently reported success). If OTP email stops working, check the Render logs for Resend's rejection reason — most likely an unverified `EMAIL_FROM` domain (`ibajayeats.linkpc.net`) in the Resend dashboard.

## Remaining work before go-live

### High priority

1. **Deploy verification**
   - Trigger a Render redeploy of `ibajayeats-api` from `website-redesign` and confirm `/api/v1/admin/reviews` returns 401 (not 404).
   - Neon is at `alembic_version = 003_add_token_version` (head) — applied 2026-10-13.
   - Confirm Vercel website redeploy picks up the new `IbajayEatsWeb`.

2. **Secrets inventory on Render** — set/verify:
   - `DATABASE_URL`, `JWT_SECRET_KEY` (now `sync: false` in `render.yaml` — **back up the live value before the next deploy; rotating it signs out every user**), `RESEND_API_KEY`, `EMAIL_FROM`, `WAITLIST_NOTIFY_EMAIL`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `FCM_SERVICE_ACCOUNT_JSON`
   - `CORS_ORIGINS` must list the **production** admin dashboard origin (currently only the website + Render URL). Add `https://<admin-domain>` when the dashboard is hosted.

3. **Firebase for push notifications** — `google-services.json` is missing in both `customer_app/android/app/` and `vendor_app/android/app/`. Without it FCM calls silently no-op. Add the files (download from Firebase console) or disable the notification paths.

4. **Rotate the bootstrap admin password** (`09000000001` / `pass123`) before sharing the build.

### Medium priority

5. **Crash / error reporting** — add Sentry or Firebase Crashlytics to both Flutter apps; without it you have no visibility into real-user failures.

6. **CI** — wire `flutter analyze && flutter test` (both apps) + `npx tsc --noEmit` (both web apps) into a GitHub Action on push. Currently nothing blocks a broken build from being merged.

7. **Tests committed** — `vendor_app/test/` was untracked until this session; ensure `customer_app/test/` runs green in CI. Backend tests now live in `backend/tests/` (26 passing; run with `venv\Scripts\python.exe -m pytest`).

### Low priority (post-beta)

8. Replace derived admin views (`/admin/subscriptions`, `/admin/activity`) with real tables once subscriptions/billing and audit logging are product requirements.

9. Admin settings/edit/moderation are read-only in the console (Staff invite, Categories manage, Review hide/flag). Decide which become real endpoints before GA.

10. Version the backend in lockstep; currently no `/version` endpoint.

11. Bump native Android `versionCode`/`minSdk` review before Play Store submission; test release APKs on a physical device (Play Protect, Android 13+ notification permission).

12. Clean up local `portfolio-ibajay/` leftovers (repo now tracks `IbajayEatsWeb/`).

13. **Rate limiter is process-local** — fine for Render's single free instance; move to Redis before scaling horizontally.

14. **"Share Live Location During Delivery" toggle (customer Settings)** is currently a local preference only — nothing consumes it. Either wire it into the GPS-ping flow or remove it before beta to avoid promising a privacy control that does nothing.

## Startup checklist for beta day

- [ ] Render deploy green, `/health` ok, `/api/v1/admin/*` 401-gated (expect **one forced logout** for everyone — token `tv` claim is new)
- [ ] Vendor app: install from `dist/IbajayEats-Vendor-0.2.0+4-beta.apk`, login (first launch after the version bump forces one fresh login by design), verify pull-to-refresh on Orders + chat stability
- [ ] Customer app: install from `dist/IbajayEats-Customer-0.2.0+4-beta.apk`, login, confirm no location-setup wall, bell badge appears after an order status change
- [ ] End-to-end: place an order with add-ons → totals include them on checkout, vendor order detail, and customer tracking
- [ ] OTP registration email arrives (if 502: check Resend domain verification for `ibajayeats.linkpc.net`)
- [ ] Admin console: sign in, confirm sidebar counts match live data
- [ ] Rotate admin password; revoke the `09000000001` demo account after tester onboarding if desired

---

## Beta round-3 (2026-10-16) - production-readiness pass

Recorded in `MISSION_REPORT.md` (details, evidence and exact command output there). Commits: backend 132c3f5, vendor_app 08fd71, customer_app 5e56cb5. Verified: pytest **66 passed**, both apps analyze-clean + tests green (vendor 11/11, customer 8/8).

| Item | Status |
| --- | --- |
| Checkout idempotency (Idempotency-Key, 24 h replay table) | OK - same key replays the original order; edited cart gets a fresh key; both apps pin it |
| Cancel policy (plan �21): customer pending/ccepted only, vendor pre-delivery only, reason required | OK - enforced server-side; UIs aligned (customer hides/greys the button, vendor uses reason dialog) |
| Reset-OTP brute-force lockout (OTP_MAX_ATTEMPTS + 10/min per-IP) | OK |
| Hot-path FK composite indexes | migration  05_hot_indexes_and_checkout_keys COMMITTED, **NOT yet applied to Neon** - run lembic upgrade head on the next backend deploy (additive/idempotent) |
| Analytics + admin overview + vendor dashboard day-bucketing | OK - all now Philippine-time (UTC+8), pp/core/manila_time.py |
| Input caps: cart size, vendor portal schemas, promo PATCH, checkout payload | OK |
| WS chat ownership + order_id checks; JWT-secret production boot guard | OK |
| Vendor app round-3: per-order busy-guards, enforced reject reasons, name-only profile edits, menu-save rollback, non-blocking registration uploads, bounded GPS stream, Mark-as-Delivered only on success, PH-day dashboard | OK |
| Customer app round-3: idempotent checkout header, cancel double-tap guard, terminal-status poll stop, lifecycle pause/resume, per-user cart + prefs, notifications auto-read, crash-proof cart restore | OK |
| PUT /auth/profile honesty: both apps show email/mobile read-only (no server endpoint exists) | OK |

### Updated deploy ordering (round-3)

**Neon is documented at  04_cancelled_notification (head as of the prior round). The next backend deploy must also run lembic upgrade head to bring  05_hot_indexes_and_checkout_keys.** Migration 005 is additive (IF NOT EXISTS) - safe while new clients and old clients coexist. The checkout_idempotency_keys table also auto-creates via create_all, but the FK indexes only ship with the migration.

Everything in "Remaining work before go-live" above still stands (FCM config files, Render secrets inventory + admin CORS origin, admin password rotation, deploy verification). Nothing in round-3 changed those steps.
