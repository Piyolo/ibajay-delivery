# Pre-Deployment Review — Ibajay Eats Beta

Date: 2026-10-03 (updated 2026-10-13)
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
| Backend smoke tests | ✅ `backend/tests/test_smoke.py` — 10 passing |
| `render.yaml` JWT secret | ✅ pinned (`sync: false`) — set/back up manually, never rotate |
| Fresh beta APKs `0.2.0+3` | ✅ `dist/*-0.2.0+3-beta.apk` (customer + vendor) |

## ⚠️ Deploy ordering (backend)

**The `003_add_token_version` migration is already applied to Neon** (verified: `alembic_version = 003_add_token_version (head)`). The next Render deploy of the backend MUST include this code — it is forward-only compatible: the new code requires the `tv` claim, and every token issued before the deploy lacks it, so **all users are logged out once on the next backend deploy** (they log back in normally). Do not roll the backend back after this deploy without also rolling back the migration.

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

7. **Tests committed** — `vendor_app/test/` was untracked until this session; ensure `customer_app/test/` runs green in CI. Backend smoke tests now exist (`backend/tests/test_smoke.py`, 10 passing; run with `venv\Scripts\python.exe -m pytest tests`).

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
- [ ] Vendor app: install from `dist/IbajayEats-Vendor-0.2.0+3-beta.apk`, login, add add-on, check store profile photo
- [ ] Customer app: install from `dist/IbajayEats-Customer-0.2.0+3-beta.apk`, login, confirm no location-setup wall
- [ ] Admin console: sign in, confirm sidebar counts match live data
- [ ] Rotate admin password; revoke the `09000000001` demo account after tester onboarding if desired
