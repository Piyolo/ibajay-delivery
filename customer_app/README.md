# Ibajay Eats — Customer App (Flutter)

The customer-facing frontend, matching the vendor app's design system so
both apps read as one product. This is **frontend only** right now, same
as the vendor app you shared — it runs entirely on mock data
(`lib/services/mock_data_service.dart`) so every flow is explorable
without the backend connected.

## What's implemented

- **Full auth flow**: landing → 4-step registration (name/mobile/email →
  email OTP with expiry/attempts/resend cooldown → password creation) →
  required permissions screen → location setup (pin drop, blocks
  progress until saved) → home. Also: login, forgot password (same OTP
  pattern).
- **Home**: search, Open Now / Delivery / Pickup / Scheduled filters,
  category chips, nearby-vendor list sorted by distance (Haversine, same
  formula as the backend) and filtered by each vendor's delivery radius.
- **Vendor store profile**: banner, rating, open/closed state, delivery
  info tags, tabbed Menu / Reviews (with vendor responses).
- **Food detail sheet**: option groups (e.g. "Add Cheese +20"), quantity,
  special instructions, add-to-cart — with a confirmation dialog if you
  try to order from a second vendor while your cart isn't empty.
- **Cart → Checkout**: delivery / pickup / scheduled (date + time picker),
  address selection, payment method (COD / cash-on-pickup per v1 spec),
  live order summary.
- **Live order tracking**: status stepper, map placeholder (ready to swap
  for `google_maps_flutter` + the backend's `/ws/orders/{id}/track`
  socket), cancel order. A demo timer auto-advances order status so the
  screen is fully explorable without a live vendor app.
- **Chat**: thread list with unread badges, real-time-feeling message UI
  (demo auto-reply), image-message placeholder ready for `image_picker`.
- **Order history**: Active / History tabs, Reorder (re-adds items to
  cart from a past order).
- **Favorites**: save/unsave stores, dedicated tab.
- **Settings**: profile fields, address book (multiple saved addresses,
  default selection), notification & privacy toggles, sign out.

## Architecture

- **State management**: `provider`, one `ChangeNotifier` per concern
  (`AuthProvider`, `LocationProvider`, `VendorProvider`, `CartProvider`,
  `OrderProvider`, `ChatProvider`, `FavoritesProvider`) — same pattern as
  the vendor app.
- **Models** (`lib/models/`) mirror the backend's SQLAlchemy schema field
  names/shapes so wiring up `http` calls later is close to a 1:1 mapping.
  Every model that's loaded from JSON has a `fromJson` factory.
- **Repository pattern** (`lib/repositories/`): `VendorRepository` is an
  abstract interface (`fetchVendors()`, `fetchReviews()`);
  `MockVendorRepository` is the only implementation right now, and reads
  from `assets/data/vendors.json` / `reviews.json`. `VendorProvider` talks
  only to the interface. **This is the deliberate seam for backend
  integration**: add an `ApiVendorRepository` that calls
  `/api/v1/vendors/nearby` and `/api/v1/vendors/{id}` instead, swap one
  line in `VendorProvider`'s constructor
  (`VendorRepository? repository`), and nothing else in the app —
  no screen, no widget — needs to change.
- **Mock data source**: `assets/data/vendors.json` and `reviews.json`
  (Ibajay, Aklan as the reference location, four demo vendors). Editing
  these JSON files is now the way to change demo data — there's no
  Dart-object mock service anymore.

## Screens implemented (Stage 1 scope)

Splash → Welcome (with hero illustration) → 4-step registration (OTP
code is `123456` in this mock) → permissions → location setup → Home
(Featured Foods carousel, Popular Stores carousel, Nearby Stores list +
"See all" → full Store Listing screen with search/filters) → Store
Profile (Menu/Reviews tabs) → Food Detail sheet (options, quantity,
special instructions) → Cart → Checkout (delivery/pickup/scheduled,
address, COD/cash-on-pickup) → Order Tracking (7-status timeline, no
live GPS per Stage 1 scope) → Chat (mock, order-context header) →
Order History (Active/Past tabs, Reorder) → Favorites → Settings
(profile fields, address book).

## Running locally

```bash
flutter pub get
flutter run
```

## Wiring to the real backend (next step)

Every provider is written so the mock logic sits in one clearly-marked
place per method — replace those bodies with `http`/`web_socket_channel`
calls against the FastAPI backend:

1. `AuthProvider` → `/api/v1/auth/register/*`, `/api/v1/auth/login`,
   `/api/v1/auth/forgot-password/*`. Store the returned JWT via
   `shared_preferences`.
2. `LocationProvider` → `/api/v1/addresses`. Swap the location-setup
   screen's placeholder map for a real `GoogleMap` + draggable marker and
   the Places Autocomplete API for search.
3. `VendorProvider` → `/api/v1/vendors/nearby` and `/api/v1/vendors/{id}`.
4. `CartProvider` stays local (cart is client-side until checkout).
5. `OrderProvider` → `/api/v1/orders/checkout`, `/api/v1/orders/my-orders`,
   `/api/v1/orders/{id}`; open a `WebSocketChannel` to
   `/ws/orders/{id}/track` for live GPS + status updates instead of the
   demo timer.
6. `ChatProvider` → `/api/v1/chats` for history, `WebSocketChannel` to
   `/ws/chats/{id}` for real-time messages.

## Not yet built

- Real Google Maps integration (currently a styled placeholder).
- Push notifications (FCM) — the settings toggles are UI-only for now.
- Payment methods beyond v1 (GCash/Maya/card are in the backend's enum
  but not surfaced here yet, matching the spec's phased rollout).
- Image upload for chat/reviews (placeholder icons stand in for now).
