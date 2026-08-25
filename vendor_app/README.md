# Ibajay Eats — Vendor App (Flutter, UI-first scaffold)

This is a complete, runnable **UI layer** for the vendor side of the local food
delivery platform described in the spec. It uses realistic mock data via
`MockDataService` so every screen is fully browsable *today*, before the
FastAPI backend exists. The provider layer (`lib/providers/`) is the seam
where real API/WebSocket calls will replace mock data — screens never talk
to `MockDataService` directly.

## What's included

- **Auth flow**: Login → Register (owner + store info) → Email OTP (6-digit,
  5 min expiry, resend) → Create Password (live requirement checklist)
- **Store setup wizard**: categories → operating hours → delivery/pickup/
  scheduled toggles + delivery radius
- **Orders dashboard**: New / Preparing / Out for Delivery / History tabs,
  Accept/Reject, status stepper, order detail with items/payment breakdown
- **Delivery tracking mode**: Start/Stop Delivery, map placeholder ready for
  Google Maps SDK, "Mark as Delivered"
- **Menu management**: grouped-by-category list, availability toggle,
  add/edit form with extras/add-ons, delete
- **Analytics**: daily/weekly/monthly sales bar chart, total sales/orders,
  best sellers
- **Chat**: order-based conversation list + message thread UI
- **Store settings**: open/closed toggle, store info, hours, delivery
  settings, account, logout

## Running it

```bash
flutter pub get
flutter run
```

(Requires the Flutter SDK — not available in this sandbox, so the app
hasn't been compiled here. The code is hand-written to be syntactically
correct and idiomatic Flutter/Dart, but do a `flutter analyze` first thing
after pulling it down.)

## Wiring up the real backend

Every place a real API call belongs is marked `// TODO`. In short:

| Feature | Replace with |
|---|---|
| `MockDataService` | `http` calls to the FastAPI REST endpoints |
| OTP screen | `POST /auth/send-otp`, `POST /auth/verify-otp` (Resend-backed) |
| Register/password | `POST /auth/register` |
| Order status changes | `PATCH /orders/{id}/status` + WebSocket push to customer app |
| Delivery tracking | Open a WebSocket (`/ws/orders/{id}/track`) and stream `Geolocator` position updates while `_tracking == true` |
| Chat | WebSocket per order (`/ws/chats/{orderId}`) + `GET /chats/{orderId}/messages` for history |
| Image upload (logo/banner/food photos) | `image_picker` → upload to Cloudinary → save returned URL |
| Push notifications | Firebase Cloud Messaging — register device token after login |
| Analytics | `GET /vendor/analytics?range=daily|weekly|monthly` |

## Project structure

```
lib/
  main.dart                 # entry point, providers, theme
  theme/app_theme.dart       # colors, spacing, radii, ThemeData
  models/                    # VendorProfile, FoodItem, VendorOrder, etc.
  services/mock_data_service.dart
  providers/                 # ChangeNotifier state — the API integration seam
  screens/
    auth/                     # login, register, otp, create password
    onboarding/store_setup_screen.dart
    orders/                   # dashboard, detail, delivery tracking
    menu/                     # menu list, food form
    analytics/analytics_screen.dart
    chat/                     # chat list, chat thread
    settings/store_settings_screen.dart
    main_shell.dart           # bottom nav shell
  widgets/                    # shared UI: status badge, section header, etc.
```

## Next steps in this project

1. **Backend** — FastAPI + PostgreSQL implementing the endpoints referenced
   above, matching the `core database tables` in the original spec.
2. **Customer app** — mirrors this structure (discovery, cart, checkout,
   live tracking, chat) and consumes the same backend.
3. **Admin dashboard** — React app for vendor verification, platform
   analytics, and user/category management.

Say the word and I'll build the next piece.
