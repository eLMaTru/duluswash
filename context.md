# Dulus Wash — MVP Context & Architecture

> Version: 0.1.0 — Last updated: 2026-03-31
> Status: Planning phase

---

## 1. Product Summary

**Dulus Wash** is an Uber-like on-demand mobile car wash and detailing platform.
Customers book vehicle wash services at their location; operators drive to them and complete the job.
A single Flutter app serves three roles: **customer**, **operator**, and **admin**.

---

## 2. Tech Stack

| Layer        | Technology                                      |
|--------------|-------------------------------------------------|
| Mobile       | Flutter (single codebase, role-based UI)        |
| Backend      | TypeScript · AWS Lambda · API Gateway           |
| IaC          | AWS CDK v2 (TypeScript)                         |
| Database     | PostgreSQL via Neon (→ AWS RDS later)           |
| Storage      | AWS S3 (before/after photos)                    |
| Auth         | Firebase Auth (simplest for Flutter MVP)        |
| Maps         | Google Maps API                                 |
| Push Notifs  | Firebase Cloud Messaging (FCM)                  |

### Auth Decision: Firebase Auth
- Native Flutter SDK (`firebase_auth`)
- No custom token server needed for MVP
- Google Sign-In out of the box
- JWT passed to Lambda via `Authorization: Bearer <idToken>`
- Lambda verifies Firebase token (firebase-admin SDK)
- Migrate to Cognito later if needed (same JWT pattern)

---

## 3. MVP Scope (Launch-Ready)

### IN scope
- Customer: book, track, rate, history, repeat booking
- Operator: see assigned jobs, navigate, update status, upload photos
- Admin: web dashboard — list bookings, assign operators, manage prices/zones
- 3 service types: Express Exterior, Exterior+Interior, Detailing (by appointment)
- 4 time windows per day
- Booking status machine (7 states)
- Before/after photo upload (S3)
- Push notifications (FCM) on status changes
- Operator real-time location (Firestore or polling)
- Rating/review after completion
- Zone-based availability check

### OUT of scope (post-MVP)
- In-app payments (Stripe integration)
- Add-ons catalog
- Partner/franchise accounts
- Membership subscriptions
- Referral wallet credits
- Multi-city admin panel
- Live chat

---

## 4. System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter App                          │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │ Customer │  │   Operator   │  │  Admin (web too)   │   │
│  └──────────┘  └──────────────┘  └────────────────────┘   │
└───────────────────────┬─────────────────────────────────────┘
                        │ HTTPS + Firebase JWT
                        ▼
              ┌─────────────────┐
              │  API Gateway    │  (REST, edge-optimized)
              └────────┬────────┘
                       │
         ┌─────────────┼──────────────┐
         ▼             ▼              ▼
    ┌─────────┐  ┌──────────┐  ┌──────────┐
    │ Lambda  │  │  Lambda  │  │  Lambda  │  ...per domain
    │ /auth   │  │/bookings │  │/operators│
    └────┬────┘  └────┬─────┘  └────┬─────┘
         │             │              │
         └─────────────┼──────────────┘
                        ▼
              ┌──────────────────┐
              │ Neon PostgreSQL  │  (→ RDS later)
              └──────────────────┘

         S3 ◄── photo uploads (presigned URLs)
    Firebase ◄── Auth + FCM push + operator location (Firestore)
 Google Maps ◄── location picker, ETA, operator tracking
```

---

## 5. PostgreSQL Schema

```sql
-- ─── USERS ───────────────────────────────────────────────────────
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid  TEXT UNIQUE NOT NULL,
  role          TEXT NOT NULL CHECK (role IN ('customer','operator','admin')),
  full_name     TEXT NOT NULL,
  email         TEXT UNIQUE NOT NULL,
  phone         TEXT,
  avatar_url    TEXT,
  fcm_token     TEXT,                    -- push notification token
  referral_code TEXT UNIQUE,
  referred_by   UUID REFERENCES users(id),
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_users_role ON users(role);

-- ─── OPERATORS (extends users) ────────────────────────────────────
CREATE TABLE operators (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  zone_id       UUID REFERENCES zones(id),
  rating        NUMERIC(3,2) DEFAULT 5.00,
  total_jobs    INT DEFAULT 0,
  is_available  BOOLEAN DEFAULT false,
  vehicle_info  TEXT,                    -- e.g. "White Ford Transit"
  license_plate TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_operators_zone ON operators(zone_id);
CREATE INDEX idx_operators_available ON operators(is_available);

-- ─── ZONES ────────────────────────────────────────────────────────
CREATE TABLE zones (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,             -- "Downtown", "Bronx North"
  city        TEXT NOT NULL DEFAULT 'New York',
  polygon     JSONB,                     -- GeoJSON polygon for boundary check
  is_active   BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─── SERVICE CATEGORIES ───────────────────────────────────────────
CREATE TABLE service_categories (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,         -- "Express Exterior"
  slug            TEXT UNIQUE NOT NULL,  -- "express-exterior"
  description     TEXT,
  duration_min    INT NOT NULL,          -- estimated minutes
  base_price_usd  NUMERIC(8,2) NOT NULL,
  sort_order      INT DEFAULT 0,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Initial seed:
-- Express Exterior       → 30 min → $25
-- Exterior + Interior    → 60 min → $45
-- Full Detailing         → 120 min → $120 (by appointment)

-- ─── VEHICLE TYPES ────────────────────────────────────────────────
CREATE TABLE vehicle_types (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL,            -- "Sedan", "SUV", "Truck", "Van"
  price_delta  NUMERIC(8,2) DEFAULT 0,  -- extra charge vs base
  is_active    BOOLEAN DEFAULT true
);

-- ─── CUSTOMER VEHICLES ────────────────────────────────────────────
CREATE TABLE customer_vehicles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vehicle_type_id UUID NOT NULL REFERENCES vehicle_types(id),
  make            TEXT,                  -- "Toyota"
  model           TEXT,                  -- "Camry"
  color           TEXT,
  license_plate   TEXT,
  is_default      BOOLEAN DEFAULT false,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_vehicles_user ON customer_vehicles(user_id);

-- ─── ADDRESSES ────────────────────────────────────────────────────
CREATE TABLE addresses (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label       TEXT,                      -- "Home", "Office"
  full_address TEXT NOT NULL,
  lat         NUMERIC(10,7) NOT NULL,
  lng         NUMERIC(10,7) NOT NULL,
  zone_id     UUID REFERENCES zones(id),
  is_default  BOOLEAN DEFAULT false,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_addresses_user ON addresses(user_id);

-- ─── TIME WINDOWS ─────────────────────────────────────────────────
CREATE TABLE time_windows (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label      TEXT NOT NULL,             -- "8:00 AM – 11:00 AM"
  start_hour INT NOT NULL,              -- 8
  end_hour   INT NOT NULL,              -- 11
  sort_order INT DEFAULT 0,
  is_active  BOOLEAN DEFAULT true
);

-- ─── BOOKINGS ─────────────────────────────────────────────────────
CREATE TABLE bookings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_number      TEXT UNIQUE NOT NULL,   -- "DW-0001"
  customer_id         UUID NOT NULL REFERENCES users(id),
  operator_id         UUID REFERENCES operators(id),
  service_category_id UUID NOT NULL REFERENCES service_categories(id),
  vehicle_id          UUID NOT NULL REFERENCES customer_vehicles(id),
  address_id          UUID NOT NULL REFERENCES addresses(id),
  time_window_id      UUID NOT NULL REFERENCES time_windows(id),
  scheduled_date      DATE NOT NULL,
  status              TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN (
                          'pending',
                          'confirmed',
                          'operator_assigned',
                          'on_the_way',
                          'arrived',
                          'in_progress',
                          'completed',
                          'cancelled',
                          'no_show'
                        )),
  total_price_usd     NUMERIC(8,2) NOT NULL,
  customer_notes      TEXT,
  cancellation_reason TEXT,
  cancelled_by        TEXT CHECK (cancelled_by IN ('customer','operator','admin')),
  completed_at        TIMESTAMPTZ,
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_bookings_customer ON bookings(customer_id);
CREATE INDEX idx_bookings_operator ON bookings(operator_id);
CREATE INDEX idx_bookings_date ON bookings(scheduled_date);
CREATE INDEX idx_bookings_status ON bookings(status);

-- ─── BOOKING STATUS HISTORY ───────────────────────────────────────
CREATE TABLE booking_status_history (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  status      TEXT NOT NULL,
  changed_by  UUID REFERENCES users(id),
  note        TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_status_history_booking ON booking_status_history(booking_id);

-- ─── SERVICE PHOTOS ───────────────────────────────────────────────
CREATE TABLE service_photos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id  UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  phase       TEXT NOT NULL CHECK (phase IN ('before','after')),
  s3_key      TEXT NOT NULL,
  url         TEXT NOT NULL,
  uploaded_by UUID NOT NULL REFERENCES users(id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_photos_booking ON service_photos(booking_id);

-- ─── RATINGS ──────────────────────────────────────────────────────
CREATE TABLE ratings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id    UUID UNIQUE NOT NULL REFERENCES bookings(id),
  customer_id   UUID NOT NULL REFERENCES users(id),
  operator_id   UUID NOT NULL REFERENCES operators(id),
  stars         INT NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment       TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_ratings_operator ON ratings(operator_id);

-- ─── OPERATOR AVAILABILITY ────────────────────────────────────────
CREATE TABLE operator_availability (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  operator_id     UUID NOT NULL REFERENCES operators(id) ON DELETE CASCADE,
  available_date  DATE NOT NULL,
  time_window_id  UUID NOT NULL REFERENCES time_windows(id),
  zone_id         UUID NOT NULL REFERENCES zones(id),
  is_booked       BOOLEAN DEFAULT false,
  UNIQUE (operator_id, available_date, time_window_id)
);
CREATE INDEX idx_availability_date ON operator_availability(available_date);
CREATE INDEX idx_availability_zone ON operator_availability(zone_id);
```

---

## 6. API Structure

Base URL: `https://<api-id>.execute-api.us-east-1.amazonaws.com/dev`

All protected routes require: `Authorization: Bearer <firebase-id-token>`

### Auth
```
POST   /api/v1/auth/register          # create user record after Firebase signup
POST   /api/v1/auth/sync              # sync FCM token / profile on login
GET    /api/v1/auth/me                # get current user profile
```

### Users
```
GET    /api/v1/users/me/vehicles      # list my vehicles
POST   /api/v1/users/me/vehicles      # add vehicle
PUT    /api/v1/users/me/vehicles/:id  # update vehicle
DELETE /api/v1/users/me/vehicles/:id  # remove vehicle

GET    /api/v1/users/me/addresses     # list saved addresses
POST   /api/v1/users/me/addresses     # add address
PUT    /api/v1/users/me/addresses/:id # update
DELETE /api/v1/users/me/addresses/:id # remove
```

### Services
```
GET    /api/v1/services               # list active service categories + prices
GET    /api/v1/services/availability  # check available time windows for date+zone
        ?date=2026-04-01&zone_id=xxx
```

### Bookings
```
POST   /api/v1/bookings               # create booking (customer)
GET    /api/v1/bookings               # list bookings (customer=mine, admin=all)
GET    /api/v1/bookings/:id           # get booking detail
PATCH  /api/v1/bookings/:id/status    # update status (operator/admin)
PATCH  /api/v1/bookings/:id/assign    # assign operator (admin)
PATCH  /api/v1/bookings/:id/cancel    # cancel booking
GET    /api/v1/bookings/:id/photos    # get before/after photos
```

### Photos
```
POST   /api/v1/bookings/:id/photos/upload-url  # get S3 presigned URL
POST   /api/v1/bookings/:id/photos             # confirm photo uploaded (save record)
```

### Ratings
```
POST   /api/v1/bookings/:id/rating    # submit rating (customer, once per booking)
GET    /api/v1/operators/:id/ratings  # list operator ratings
```

### Operators (admin)
```
GET    /api/v1/operators              # list operators
GET    /api/v1/operators/:id          # operator detail + stats
PATCH  /api/v1/operators/:id/activate # activate/deactivate
GET    /api/v1/operators/:id/schedule # see operator's day schedule
```

### Zones (admin)
```
GET    /api/v1/zones                  # list zones
POST   /api/v1/zones                  # create zone
PUT    /api/v1/zones/:id              # update zone
```

### Admin
```
GET    /api/v1/admin/metrics          # services_per_day, avg_ticket, etc.
GET    /api/v1/admin/bookings         # full list with filters
```

---

## 7. AWS CDK Infrastructure

```
infra/
├── bin/
│   └── duluswash.ts                  # CDK app entry
├── lib/
│   └── duluswash-backend-stack.ts    # main stack
├── functions/
│   ├── auth/handler.ts
│   ├── bookings/handler.ts
│   ├── services/handler.ts
│   ├── operators/handler.ts
│   ├── photos/handler.ts
│   ├── ratings/handler.ts
│   ├── zones/handler.ts
│   └── admin/handler.ts
├── shared/
│   ├── db.ts                         # Neon connection pool (pg)
│   ├── firebase-admin.ts             # Firebase token verifier
│   ├── middleware.ts                 # auth check, error handler
│   └── types.ts
└── package.json
```

### Stack resources

```typescript
// Lambda config: Node 22.x, 30s timeout, 256MB
// Shared env: DATABASE_URL, FIREBASE_PROJECT_ID, S3_BUCKET, AWS_REGION

Resources:
- API Gateway (HTTP API, cheaper + faster than REST for mobile)
- Lambda per domain (auth, bookings, services, operators, photos, ratings, zones, admin)
- S3 bucket (photos) — private, presigned URL access
- IAM roles with least-privilege
- SSM Parameter Store for DATABASE_URL (Neon connection string)
- No VPC for MVP (Neon is external; add VPC when migrating to RDS)
```

### Database connection strategy
```typescript
// lib/shared/db.ts
import { Pool } from 'pg';
// Neon requires SSL
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
  max: 1,           // Lambda: keep pool size at 1
  idleTimeoutMillis: 10000,
});
```

---

## 8. Flutter App Structure

```
lib/
├── main.dart                         # entry point
├── firebase_options.dart             # generated by FlutterFire CLI
├── core/
│   ├── config/
│   │   ├── app_config.dart           # API base URL, env vars
│   │   └── firebase_config.dart
│   ├── network/
│   │   ├── api_client.dart           # Dio HTTP client, interceptors
│   │   └── api_endpoints.dart        # all endpoint strings
│   ├── auth/
│   │   ├── auth_service.dart         # Firebase Auth wrapper
│   │   └── auth_provider.dart        # Riverpod provider
│   ├── router/
│   │   └── app_router.dart           # GoRouter + role-based guards
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── app_colors.dart
│   └── utils/
│       ├── formatters.dart
│       └── validators.dart
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── presentation/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   └── widgets/
│   │   └── providers/
│   │       └── auth_state_provider.dart
│   │
│   ├── booking/                      # CUSTOMER
│   │   ├── data/
│   │   │   ├── booking_repository.dart
│   │   │   └── models/
│   │   │       ├── booking.dart
│   │   │       └── service_category.dart
│   │   ├── presentation/
│   │   │   ├── service_picker_screen.dart
│   │   │   ├── vehicle_picker_screen.dart
│   │   │   ├── location_picker_screen.dart
│   │   │   ├── time_picker_screen.dart
│   │   │   ├── booking_summary_screen.dart
│   │   │   └── booking_confirmed_screen.dart
│   │   └── providers/
│   │       └── booking_flow_provider.dart   # Riverpod StateNotifier
│   │
│   ├── tracking/                     # CUSTOMER
│   │   ├── data/
│   │   │   └── tracking_repository.dart
│   │   ├── presentation/
│   │   │   ├── tracking_screen.dart         # map + status timeline
│   │   │   └── service_detail_screen.dart   # photos, rating
│   │   └── providers/
│   │       └── tracking_provider.dart
│   │
│   ├── history/                      # CUSTOMER
│   │   ├── presentation/
│   │   │   ├── history_screen.dart
│   │   │   └── history_detail_screen.dart
│   │   └── providers/
│   │
│   ├── profile/                      # CUSTOMER
│   │   ├── presentation/
│   │   │   ├── profile_screen.dart
│   │   │   ├── vehicles_screen.dart
│   │   │   └── addresses_screen.dart
│   │   └── providers/
│   │
│   ├── operator/                     # OPERATOR
│   │   ├── data/
│   │   │   └── operator_repository.dart
│   │   ├── presentation/
│   │   │   ├── operator_home_screen.dart    # today's jobs list
│   │   │   ├── job_detail_screen.dart       # map + status buttons
│   │   │   ├── photo_upload_screen.dart     # camera + upload
│   │   │   └── operator_history_screen.dart
│   │   └── providers/
│   │       └── operator_job_provider.dart
│   │
│   └── admin/                        # ADMIN (web too)
│       ├── data/
│       │   └── admin_repository.dart
│       ├── presentation/
│       │   ├── admin_dashboard_screen.dart
│       │   ├── admin_bookings_screen.dart
│       │   ├── admin_assign_screen.dart
│       │   └── admin_operators_screen.dart
│       └── providers/
│
└── shared/
    ├── widgets/
    │   ├── status_badge.dart
    │   ├── booking_card.dart
    │   ├── operator_card.dart
    │   ├── photo_grid.dart
    │   └── rating_stars.dart
    └── models/
        ├── user.dart
        └── address.dart
```

### State Management: Riverpod (riverpod + hooks_riverpod)
- Simple, testable, no boilerplate
- Each feature has its own providers file
- `booking_flow_provider.dart` holds the multi-step booking wizard state

### Packages
```yaml
dependencies:
  flutter:
  firebase_core:
  firebase_auth:
  cloud_firestore:          # operator location tracking
  firebase_messaging:       # FCM push notifications
  google_maps_flutter:
  riverpod:
  hooks_riverpod:
  flutter_hooks:
  go_router:
  dio:
  image_picker:
  cached_network_image:
  intl:
  geolocator:
  permission_handler:
  url_launcher:             # open Google Maps navigation
  shimmer:                  # loading skeletons
  flutter_svg:
```

---

## 9. Role-Based Navigation (GoRouter)

```dart
// core/router/app_router.dart

final router = GoRouter(
  redirect: (context, state) {
    final user = ref.read(authProvider);
    if (user == null) return '/login';
    if (user.role == 'operator') return '/operator/home';
    if (user.role == 'admin')    return '/admin/dashboard';
    return '/home';                     // customer
  },
  routes: [
    // ── Public ──────────────────────────────
    GoRoute(path: '/login',    builder: LoginScreen),
    GoRoute(path: '/register', builder: RegisterScreen),

    // ── Customer ─────────────────────────────
    ShellRoute(routes: [
      GoRoute(path: '/home',                builder: CustomerHomeScreen),
      GoRoute(path: '/book/service',        builder: ServicePickerScreen),
      GoRoute(path: '/book/vehicle',        builder: VehiclePickerScreen),
      GoRoute(path: '/book/location',       builder: LocationPickerScreen),
      GoRoute(path: '/book/time',           builder: TimePickerScreen),
      GoRoute(path: '/book/summary',        builder: BookingSummaryScreen),
      GoRoute(path: '/booking/:id/track',   builder: TrackingScreen),
      GoRoute(path: '/booking/:id/detail',  builder: ServiceDetailScreen),
      GoRoute(path: '/history',             builder: HistoryScreen),
      GoRoute(path: '/profile',             builder: ProfileScreen),
    ]),

    // ── Operator ──────────────────────────────
    ShellRoute(routes: [
      GoRoute(path: '/operator/home',       builder: OperatorHomeScreen),
      GoRoute(path: '/operator/job/:id',    builder: JobDetailScreen),
      GoRoute(path: '/operator/history',    builder: OperatorHistoryScreen),
    ]),

    // ── Admin ─────────────────────────────────
    ShellRoute(routes: [
      GoRoute(path: '/admin/dashboard',     builder: AdminDashboardScreen),
      GoRoute(path: '/admin/bookings',      builder: AdminBookingsScreen),
      GoRoute(path: '/admin/operators',     builder: AdminOperatorsScreen),
    ]),
  ],
);
```

---

## 10. Booking Status Machine

```
pending
  └─► confirmed          (admin confirms / auto-confirm)
        └─► operator_assigned   (admin assigns operator)
              └─► on_the_way    (operator taps "On My Way")
                    └─► arrived  (operator taps "Arrived")
                          └─► in_progress  (operator taps "Start Service")
                                └─► completed  (operator taps "Complete")

Any state ──► cancelled  (customer before operator_assigned / admin anytime)
```

---

## 11. Operator Real-Time Location

Strategy for MVP (simple):
- Operator app sends GPS coordinates to **Firestore** every 5 seconds while job is `on_the_way`
- Customer app listens to Firestore document `operator_locations/{bookingId}` for live updates
- Google Maps shows operator marker + updates position
- No cost for Lambda/API on location updates (Firestore handles it)

```
Firestore document: operator_locations/{bookingId}
{
  lat: 40.7128,
  lng: -74.0060,
  updated_at: Timestamp,
  eta_minutes: 8
}
```

---

## 12. Photo Upload Flow

```
1. Operator selects photos from camera (image_picker)
2. Flutter calls POST /api/v1/bookings/:id/photos/upload-url
3. Lambda returns S3 presigned PUT URL (15-min expiry)
4. Flutter uploads image directly to S3 (no Lambda in the middle)
5. Flutter calls POST /api/v1/bookings/:id/photos to save record in DB
6. Customer sees photos in booking detail screen
```

---

## 13. Push Notifications (FCM)

| Trigger                  | Recipient  | Message                              |
|--------------------------|------------|--------------------------------------|
| Booking confirmed        | Customer   | "Tu reserva fue confirmada ✅"        |
| Operator assigned        | Customer   | "Tu operador está asignado 🚗"        |
| Operator on the way      | Customer   | "Tu operador está en camino 📍"       |
| Operator arrived         | Customer   | "Tu operador ha llegado 🛁"           |
| Service completed        | Customer   | "Servicio completado. ¡Califica! ⭐"  |
| New job assigned         | Operator   | "Nuevo servicio asignado"             |

Lambda sends FCM via Firebase Admin SDK using the user's `fcm_token` from DB.

---

## 14. Pricing Logic

```
final_price = base_price + vehicle_type_delta

Example:
Express Exterior base:   $25
+ SUV delta:             +$10
= final:                 $35
```

Prices stored in `service_categories` and `vehicle_types` tables.
Admin can update via dashboard (PATCH /api/v1/services/:id).

---

## 15. MVP Build Checklist

### Backend (Lambda + PostgreSQL)
- [ ] Setup Neon PostgreSQL, run schema migrations
- [ ] CDK stack: API Gateway + Lambda per domain + S3 bucket
- [ ] Firebase Admin SDK integration for JWT verification
- [ ] `auth/register` — create user on first login
- [ ] `services/` — list services + availability check
- [ ] `bookings/` — CRUD + status machine
- [ ] `photos/` — presigned URL + record save
- [ ] `ratings/` — submit + query
- [ ] `operators/` — schedule, assign, activate
- [ ] `admin/metrics` — basic analytics query
- [ ] FCM push on status change
- [ ] Booking number generator (DW-0001 sequential)

### Flutter App — Customer
- [ ] Firebase Auth (email/password + Google)
- [ ] Role detection + redirect on login
- [ ] Service picker screen
- [ ] Vehicle picker + add vehicle
- [ ] Location picker (Google Maps)
- [ ] Time window picker + availability check
- [ ] Booking summary + confirm
- [ ] Tracking screen (Firestore listener + Google Maps)
- [ ] Service detail screen (photos + rate)
- [ ] History screen + repeat booking
- [ ] Profile screen + manage addresses/vehicles

### Flutter App — Operator
- [ ] Operator home (today's jobs list)
- [ ] Job detail (address, service type, notes)
- [ ] "On My Way" button → update status + start Firestore location updates
- [ ] "Arrived" + "Start Service" + "Complete" buttons
- [ ] Photo upload (before + after, camera)
- [ ] Open Google Maps navigation (url_launcher)
- [ ] Operator history screen

### Flutter App — Admin
- [ ] Bookings list with filters (date, status, zone)
- [ ] Assign operator modal
- [ ] Cancel / reschedule booking
- [ ] Operators list (activate/deactivate)
- [ ] Basic metrics screen

### Infrastructure
- [ ] CDK deploy dev environment
- [ ] S3 bucket + CORS config for presigned uploads
- [ ] SSM Parameter for DATABASE_URL
- [ ] GitHub Actions CI/CD for backend
- [ ] Firebase project setup (Auth + Firestore + FCM)

---

## 16. Project Structure (Monorepo)

```
duluswash/
├── mobile/                           # Flutter app
│   ├── lib/
│   ├── android/
│   ├── ios/
│   ├── pubspec.yaml
│   └── ...
├── backend/
│   ├── functions/
│   │   ├── auth/
│   │   ├── bookings/
│   │   ├── services/
│   │   ├── operators/
│   │   ├── photos/
│   │   ├── ratings/
│   │   ├── zones/
│   │   └── admin/
│   ├── shared/
│   │   ├── db.ts
│   │   ├── firebase-admin.ts
│   │   ├── middleware.ts
│   │   └── types.ts
│   └── package.json
├── infra/
│   ├── bin/duluswash.ts
│   ├── lib/duluswash-backend-stack.ts
│   └── package.json
├── migrations/
│   └── 001_initial_schema.sql
└── context.md                        # this file
```

---

## 17. Key Decisions Log

| Decision | Choice | Reason |
|---|---|---|
| Auth | Firebase Auth | Best native Flutter integration, no custom token server |
| DB | Neon PostgreSQL | Free tier, serverless, migrable to RDS |
| Real-time location | Firestore | Free, no Lambda cost, instant SDK in Flutter |
| State management | Riverpod | Simple, testable, no boilerplate vs BLoC |
| Navigation | GoRouter | Official package, supports deep links and role guards |
| API type | HTTP API Gateway | 70% cheaper than REST API, faster cold start |
| Photo upload | S3 presigned URL | No Lambda in upload path, secure, scalable |
| Push | FCM via Firebase Admin | Already using Firebase, free tier generous |

---

## 18. Environment Variables (Backend)

```bash
DATABASE_URL=postgresql://user:pass@neon-host/duluswash?sslmode=require
FIREBASE_PROJECT_ID=duluswash
S3_BUCKET=duluswash-photos-dev
AWS_REGION=us-east-1
STAGE=dev
```

---

## 19. Version History

| Version | Date       | Notes                  |
|---------|------------|------------------------|
| 0.1.0   | 2026-03-31 | Initial architecture   |
