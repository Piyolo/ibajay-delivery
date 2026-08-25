# Local Food Delivery — Backend (FastAPI)

This is the **customer-facing core** of the platform's backend, built first
because both the customer app, the vendor app, and the admin dashboard all
depend on it. It's a working, runnable service — not pseudocode — following
the spec's tech choices: FastAPI + async SQLAlchemy + PostgreSQL (Neon) +
WebSockets + Resend (email OTP).

## What's implemented

- **Auth** (`/api/v1/auth`): 4-step registration exactly as specified
  (collect info → email OTP via Resend → verify OTP → set password), login
  by mobile number + password, JWT access/refresh tokens, forgot-password
  flow.
- **Addresses** (`/api/v1/addresses`): multiple saved addresses with lat/lng,
  default address selection.
- **Vendor discovery** (`/api/v1/vendors`): nearby-vendor search with
  distance filtering (Haversine), open-now / delivery / pickup / scheduled
  filters, free-text search, full store profile with menu.
- **Orders** (`/api/v1/orders`): checkout (delivery/pickup/scheduled,
  server-side price recalculation, delivery-radius + fee validation),
  vendor order-management inbox, guarded status transitions
  (pending → accepted → preparing → ready → out_for_delivery → delivered →
  completed, plus cancellation), order history.
- **Live tracking** (`/api/v1/tracking` + `/ws/orders/{id}/track`): vendor
  "Start Delivery" endpoint, GPS-ping ingestion, real-time broadcast to the
  customer's WebSocket.
- **Chat** (`/api/v1/chats` + `/ws/chats/{id}`): order-based threads,
  real-time two-way messaging over WebSocket, persisted history.
- **Database schema**: all core tables from the spec as SQLAlchemy models
  (`app/models/`) — users, addresses, OTP/reset records, vendors + their
  delivery settings/operating hours/categories, food items + images +
  variant/add-on options, orders + items + status history, chats/messages,
  notifications, favorites, ratings/reviews.

## What's intentionally stubbed or left for the next pass

- **Vendor "back office" CRUD** (create/edit food items, toggle store
  open/closed, configure operating hours & delivery radius, analytics) —
  the data model fully supports it; the routers are the same pattern as
  `orders.py`/`vendors.py` and are the natural next slice.
- **Admin dashboard** (React) and **push notifications** (FCM) — the
  `services/notifications.py` hook is in place; wire in `firebase-admin`
  and a background task queue (Celery/RQ) once you're ready.
- **Image upload** to Cloudinary — models have `logo_url`/`image_url` fields
  ready to receive a Cloudinary URL from a signed-upload endpoint.
- **Payments** — v1 is COD/cash-on-pickup by design per the spec; the
  `PaymentMethod` enum already reserves GCash/Maya/card/bank-transfer.
- Order-option pricing (add-ons like "Add Cheese +20") is modeled fully in
  the schema but the checkout route currently prices only the base item —
  flagged with a `NOTE` comment at the exact line in `routers/orders.py`.

## Running locally

### macOS / Linux

```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # fill in DATABASE_URL (Neon), RESEND_API_KEY, JWT_SECRET_KEY
```

### Windows (PowerShell)

PowerShell doesn't support `&&` as a statement separator, and activation
uses a different script than macOS/Linux:

```powershell
cd backend
python -m venv venv
venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env   # then edit .env and fill in real values
```

If `Activate.ps1` is blocked by execution policy, run PowerShell as
Administrator once and allow local scripts:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Then, on either OS

**Edit `.env` with a real `DATABASE_URL` before doing anything else.**
The value shipped in `.env.example` (`ep-example.neon.tech`) is a
placeholder and does not exist. Steps:

1. Create a free project at [neon.tech](https://neon.tech).
2. Copy the connection string it gives you and paste it in as `DATABASE_URL`.

**You can paste Neon's connection string exactly as given** — including
the plain `postgresql://...?sslmode=require` shape Neon's dashboard shows
by default. The app auto-corrects it to the async driver format
(`postgresql+asyncpg://...?ssl=require`) at startup, so you don't need to
hand-edit the scheme or the SSL parameter name. This is what fixes the
`ModuleNotFoundError: No module named 'psycopg2'` error some people hit —
that happened because SQLAlchemy defaults to a sync driver (`psycopg2`,
not installed) when the URL doesn't say `+asyncpg` explicitly.

Then create the tables (a ready-made script is included so you don't have
to type a multi-line snippet, which is awkward in PowerShell):

```bash
python create_tables.py
```
```bash
uvicorn app.main:app --reload
```

Then open `http://localhost:8000/docs` for interactive Swagger docs of
every endpoint.

### Common first-run errors

- **`ModuleNotFoundError: No module named 'email_validator'`** — Pydantic's
  `EmailStr` type needs this as a separate package. It's now in
  `requirements.txt` (`email-validator==2.2.0`); re-run `pip install -r requirements.txt`
  if you installed before this was added.
- **`ModuleNotFoundError: No module named 'psycopg2'`** or
  **`TypeError: connect() got an unexpected keyword argument 'channel_binding'`**
  — your `DATABASE_URL` was in the plain libpq shape Neon's dashboard shows
  by default (`postgresql://...?sslmode=require&channel_binding=require`),
  which isn't compatible with the async `asyncpg` driver this project
  uses. As of this version the URL is auto-normalized on load (see
  `app/core/config.py`) — the scheme is corrected to `+asyncpg`,
  `sslmode` becomes `ssl`, and libpq-only params like `channel_binding`
  are stripped. Pulling the latest code and re-running fixes this without
  editing `.env` by hand. If you still see it, confirm `.env` was actually
  saved (a stray `Copy-Item .env.example .env` after editing will
  silently overwrite your real value with the placeholder again).
- **`ConnectionRefusedError` / asyncpg can't connect** — almost always a
  placeholder `DATABASE_URL` (still pointing at `ep-example.neon.tech`)
  or a copy/paste mistake. Confirm `.env` actually contains your real
  Neon host, not the example one.
- **`Tables created successfully.` followed by a scary-looking
  `Fatal error on SSL transport` / `Event loop is closed` traceback** —
  this is cosmetic. It's a known Windows quirk where the default
  `ProactorEventLoop` throws that error while an already-finished SSL
  connection (asyncpg's TLS session to Neon) finishes tearing down after
  `asyncio.run()` has already closed the loop. If you saw
  "Tables created successfully." print, the tables were created — the
  traceback after it caused no damage. This is now suppressed in
  `create_tables.py` by switching to the selector event loop on Windows.
- **`GET / → 404`** — expected. There's no API at the bare root, only
  under `/api/v1/...`, `/health`, and the WebSocket routes. Visit
  `http://127.0.0.1:8000/docs` for the interactive API explorer (as of
  this version, `/` redirects there automatically).


### Using Alembic instead (recommended for anything beyond local testing)

```bash
alembic revision --autogenerate -m "init schema"
alembic upgrade head
```

## Deploying (per spec)

- **Backend** → Render (Web Service, `uvicorn app.main:app --host 0.0.0.0 --port $PORT`)
- **Database** → Neon PostgreSQL (use the pooled connection string with `asyncpg`)
- **Images** → Cloudinary
- **Email** → Resend
- **Push** → Firebase Cloud Messaging

## Suggested next milestones

1. Vendor back-office routers (store config, menu CRUD, operating hours,
   analytics) — same patterns already established here.
2. Wire real FCM push + a background job runner instead of the `print()`
   stub in `notifications.py`.
3. Cloudinary signed-upload endpoint for logos/banners/food photos.
4. Admin dashboard (React) hitting the same API with an `admin` role.
5. Flutter customer app: point its API client at these endpoints; Google
   Maps SDK for the location-picker and live tracking screen (consume the
   `/ws/orders/{id}/track` socket).
6. Flutter vendor app: order inbox, "Start Delivery" + background GPS
   ping loop against `/api/v1/tracking/{order_id}/gps-ping`.
