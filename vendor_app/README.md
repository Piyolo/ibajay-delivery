# Ibajay Eats — Vendor App

Flutter app for vendors on Ibajay Eats, a local food marketplace for
Ibajay, Aklan. Vendors manage their storefront, menu, and orders; all data
is live against the FastAPI backend (`ApiClient` + `VendorApiService`).

## What's included

- **Auth flow**: Login → Register (owner + store info) → Email OTP →
  Create Password (live requirement checklist), plus forgot-password
- **Store setup wizard**: categories → operating hours → delivery/pickup/
  scheduled toggles + barangay coverage
- **Orders dashboard**: New / Preparing / Out for Delivery / History tabs,
  Accept/Reject, status stepper, order detail with items/payment breakdown
- **Vendor delivery tracking**: Start Delivery flips the order to
  out_for_delivery (POST `/tracking/{id}/start`) and streams the vendor
  device's GPS to the customer's live-tracking view until Mark as Delivered.
  Ibajay Eats has no riders of its own — the vendor (or their designated
  delivery person) fulfills every delivery.
- **Menu management**: grouped-by-category list, availability toggle,
  add/edit form with extras/add-ons, delete
- **Analytics**: today's sales/orders/completed/cancelled, last-7-days
  revenue chart (from GET /vendor/me/analytics)
- **Chat**: order-based conversation list + message thread over WebSocket
- **Store settings**: open/closed toggle, store profile (logo/banner via
  OpenStreetMap-based address picker), hours, delivery settings, account

## Running it

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://ibajay-delivery.onrender.com
```

Check for issues first:

```bash
flutter analyze
```

## API surface used

| Feature | Endpoint |
|---|---|
| Auth / OTP / password | `/auth/*` |
| Store profile & status | `GET/PUT/PATCH /vendor/me`, `/vendor/me/status` |
| Delivery settings | `PUT /vendor/me/delivery-settings` |
| Operating hours | `PUT /vendor/me/hours` |
| Categories | `PUT /vendor/me/categories` |
| Image upload | `POST /uploads` (multipart) |
| Menu CRUD | `/vendor/me/menu` |
| Order inbox | `GET /orders/vendor/inbox` |
| Status transitions | `PATCH /orders/{id}/status`, `POST /orders/{id}/cancel` |
| Delivery tracking | `POST /tracking/{id}/start`, `POST /tracking/{id}/gps-ping` |
| Analytics | `GET /vendor/me/analytics` |
| Chat | WebSocket per thread + REST history |

## Project structure

```
lib/
  main.dart                 # entry point, one shared ApiClient, providers, theme
  theme/app_theme.dart       # colors, spacing, radii, ThemeData
  models/                    # VendorProfile, FoodItem, VendorOrder, etc.
  services/                  # ApiClient, auth/vendor API services, prefs
  providers/                 # ChangeNotifier state (vendor, orders, menu, chat)
  screens/
    auth/                     # login, register, OTP, create password
    onboarding/store_setup_screen.dart
    dashboard/                # quick-glance home tab
    orders/                   # dashboard, detail, delivery tracking
    menu/                     # menu list, food form
    analytics/analytics_screen.dart
    chat/                     # chat list, chat thread
    settings/                 # store profile/status/hours/delivery/categories/account
    main_shell.dart           # bottom nav shell
  widgets/                    # shared UI: status badge, OSM picker, common
```

## Notes

- The single `ApiClient` created in `main.dart` carries the auth token;
  always pass it into providers so requests stay authenticated.
- Live GPS sharing only runs while an order is out_for_delivery.
