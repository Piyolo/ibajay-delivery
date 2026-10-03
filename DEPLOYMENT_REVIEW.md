# Pre-Deployment Review — Ibajay Eats Beta

Date: 2026-10-03
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

## Remaining work before go-live

### High priority

1. **Deploy verification**
   - Trigger a Render redeploy of `ibajayeats-api` from `website-redesign` and confirm `/api/v1/admin/reviews` returns 401 (not 404).
   - Confirm Neon has `alembic_version = 002_add_barangay_addresses` (it does — verified locally).
   - Confirm Vercel website redeploy picks up the new `IbajayEatsWeb`.

2. **Secrets inventory on Render** — set/verify:
   - `DATABASE_URL`, `JWT_SECRET_KEY` (generated ✅), `RESEND_API_KEY`, `EMAIL_FROM`, `WAITLIST_NOTIFY_EMAIL`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET`, `FCM_SERVICE_ACCOUNT_JSON`
   - `CORS_ORIGINS` must list the **production** admin dashboard origin (currently only the website + Render URL). Add `https://<admin-domain>` when the dashboard is hosted.

3. **Firebase for push notifications** — `google-services.json` is missing in both `customer_app/android/app/` and `vendor_app/android/app/`. Without it FCM calls silently no-op. Add the files (download from Firebase console) or disable the notification paths.

4. **Rotate the bootstrap admin password** (`09000000001` / `pass123`) before sharing the build.

### Medium priority

5. **Crash / error reporting** — add Sentry or Firebase Crashlytics to both Flutter apps; without it you have no visibility into real-user failures.

6. **CI** — wire `flutter analyze && flutter test` (both apps) + `npx tsc --noEmit` (both web apps) into a GitHub Action on push. Currently nothing blocks a broken build from being merged.

7. **Tests committed** — `vendor_app/test/` was untracked until this session; ensure `customer_app/test/` runs green in CI. No backend tests exist yet — at minimum a smoke test for `/health` and `/api/v1/admin/*` auth guards.

### Low priority (post-beta)

8. Replace derived admin views (`/admin/subscriptions`, `/admin/activity`) with real tables once subscriptions/billing and audit logging are product requirements.

9. Admin settings/edit/moderation are read-only in the console (Staff invite, Categories manage, Review hide/flag). Decide which become real endpoints before GA.

10. Version the backend in lockstep; currently no `/version` endpoint.

11. Bump native Android `versionCode`/`minSdk` review before Play Store submission; test release APKs on a physical device (Play Protect, Android 13+ notification permission).

12. Clean up local `portfolio-ibajay/` leftovers (repo now tracks `IbajayEatsWeb/`).

## Startup checklist for beta day

- [ ] Render deploy green, `/health` ok, `/api/v1/admin/*` 401-gated
- [ ] Vendor app: install from `dist/IbajayEats-Vendor-0.2.0+2-beta.apk`, login, add add-on, check store profile photo
- [ ] Customer app: install from `dist/IbajayEats-Customer-0.2.0+2-beta.apk`, login, confirm no location-setup wall
- [ ] Admin console: sign in, confirm sidebar counts match live data
- [ ] Rotate admin password; revoke the `09000000001` demo account after tester onboarding if desired
