# Rayuela Mobile — Migration Plan

Flutter app for the Rayuela adaptive-gamification citizen-science platform.
Target audience: **end-user participants (volunteers) only**. The admin console stays on the existing Vue 3 web app.

- Frontend reference: `../rayuela-frontend` (Vue 3 + Vuetify + Vuex + OpenLayers)
- Backend: `../rayuela-NodeBackend` (NestJS 10 + MongoDB + JWT + S3)
- Mobile: this repo, Flutter + Riverpod + clean architecture

---

## 1. System analysis

### 1.1 What the system does

Rayuela lets NGOs/researchers create **citizen-science projects**. Each project defines:

- **Areas** (GeoJSON polygons) — where participants should act.
- **Time intervals** — when actions are valid (weekday + hour windows, plus a start/end date).
- **Task types** — a controlled vocabulary of activity categories (e.g., "cleaning", "bird spotting").
- **Tasks** — concrete assignments that combine (area, time interval, task type). A task is "solved" the first time a qualifying check-in happens inside it.
- **Gamification rules** — badge templates and point rules keyed to (task type, area, time interval, must-contribute).
- **Strategies** — three orthogonal choices made by admins per project:
  - `gamificationStrategy`: `BASIC` (`SIN ADAPTACION`) or `ELASTIC` (`ELASTICA`, turbo-mode points for players behind the leaderboard).
  - `recommendationStrategy`: `SIMPLE` or `ADAPTIVE` (collaborative-filtering task ordering based on Dice similarity across area/time/type and user ratings).
  - `leaderboardStrategy`: `POINTS_FIRST` or `BADGES_FIRST`.

Volunteers subscribe to projects, go out into the world, and submit **check-ins**: `{lat, lng, datetime, taskType, up to 3 photos}`. The backend runs a pluggable `Game` (points engine + badge engine + leaderboard engine) to compute `{newPoints, newBadges, newLeaderboard}` and persists a `Move` record. Ratings feed the adaptive recommender.

### 1.2 Core domain (mobile-relevant subset)

| Entity | Key fields mobile uses |
|---|---|
| `User` | `_id`, `username`, `complete_name`, `email`, `profile_image`, `role`, `gameProfiles[]` (per-project points + badges), `ratings[]` |
| `Project` | `_id`, `name`, `description`, `image`, `web`, `available`, `areas` (GeoJSON), `taskTypes[]`, `timeIntervals[]`, three strategy enums, and the embedded `user: {isSubscribed, points, badges}` when called with auth |
| `Task` | `_id`, `name`, `description`, `projectId`, `type`, `areaId`, `timeIntervalId`, `solved`, plus enriched `areaGeoJSON`, `timeInterval`, `solvedBy`, `estimatedRating` |
| `Checkin` | `_id`, `latitude`, `longitude`, `datetime`, `projectId`, `userId`, `taskType`, `contributesTo`, `imageRefs[]` |
| `Gamification` | per-project `{badges[], pointRules[]}` with full rule schema |
| `LeaderboardEntry` | `username`, `completeName`, `points`, `badges[]`, avatar |

### 1.3 End-user vs admin split (verified against frontend routes and backend guards)

**End-user (migrate to mobile):**
- Landing / project discovery (`/`, `/public/project/:id/view`)
- Auth (`/login`, `/register`, `/forgot-password`, `/reset-password`, `/verify-email`)
- Dashboard of subscribed projects (`/dashboard`)
- Project detail with tasks + badges + map + submit check-in (`/project/:projectId/view`)
- Check-in history
- Leaderboard (`/leaderboard`, plus per-project)
- Profile (new — currently not a real screen on web)

**Admin (stays on web, do NOT migrate):**
- `/admin/*` — project CRUD, task manager, gamification config, badge/rule editors, bulk task generation, polygon drawing, availability toggles.

The router guard is `localStorage.getItem('role') === 'Admin'`. The mobile app will refuse to log admins in (or will degrade gracefully — see §3.2).

### 1.4 Main end-user flows

1. **Onboarding**: land → register (email or Google) → verify email → log in.
2. **Discover**: browse public projects → open detail → subscribe.
3. **Participate**: open subscribed project → see map + task list → tap "Check in" → capture location + photo + task type → submit → see earned points/badges.
4. **Progress**: open profile → see aggregate points, badges, history. Open project → see personal badge progress and leaderboard position.
5. **Engagement loop**: receive push ("new recommended task near you", "badge unlocked") → open app → quick check-in.

---

## 2. Mobile scope

### 2.1 In-scope (MVP and near-term)

| Module | Notes |
|---|---|
| Authentication | Email/password, Google sign-in, forgot/reset password, email verification deep link |
| Project discovery | Public project list, project detail, subscribe/unsubscribe |
| Dashboard | Subscribed projects, quick entry to participation |
| Project detail | Map with areas + tasks, task list (adaptive-sorted if enabled), personal badges progress |
| Check-in | GPS capture, native camera, up to 3 photos, task-type picker, optimistic UI, offline queue (phase 2) |
| Check-in history | List of past submissions with photos and awarded points/badges |
| Leaderboard | Per-project, infinite scroll, current user highlighted |
| Gamification view | Earned + locked badges, requirements panel, linear progress (not the full DAG graph) |
| Rating | 1–5 stars on recent check-ins, feeds the adaptive engine |
| Profile | View + edit complete_name, profile_image, language; logout; account deletion request (phase 2) |
| Notifications | FCM + APNs: badge unlocked, leaderboard movement, new recommended task, verification reminder |
| i18n | ES / EN / PT, reusing the existing locale JSONs |

### 2.2 Out of scope (explicitly)

- All `/admin/*` screens.
- Polygon drawing / area editing.
- Badge/rule/score-rule CRUD.
- Bulk task upload and "generate auto tasks".
- Task delete-useless and similar admin maintenance.
- The full SVG badge **dependency DAG** — replaced by a simpler linearized "what's next" list on mobile.

### 2.3 Features to redesign for mobile (not replicate)

- **Project detail hub**: the web page crams map + task table + badge gallery + leaderboard teaser on one screen. On mobile this becomes a **scroll-tabbed screen**: `Overview | Tasks | Badges | Leaderboard`, with a persistent floating "Check in" FAB.
- **Location picker**: replace the click-on-OpenLayers-dialog UX with a full-screen `flutter_map` view centered on GPS, a draggable pin, and "use current location" / "drop manually" toggle.
- **Photo capture**: prefer in-app camera over gallery picker, compress to ~1600px long edge before upload.
- **Badge graph**: linear "next 3 badges" list with a bottom sheet for full requirements instead of DAG hover tooltips.
- **Leaderboard**: sticky header with *your* position and delta since last session; the full list paginates below.
- **Check-in form**: progressive disclosure — one card per step (where → what → photos → review) rather than a long vertical form.

---

## 3. Architecture

### 3.1 Stack

- **Flutter** 3.22+ / Dart 3.4+, null-safe, Material 3.
- **State**: `flutter_riverpod` 2.5+ with `@riverpod` code generation.
- **Navigation**: `go_router` 14+ with auth-aware redirect.
- **HTTP**: `dio` 5+ with interceptors for auth, refresh, logging, retry.
- **Storage**: `flutter_secure_storage` for tokens, `shared_preferences` for user prefs, `sqflite` (phase 2) for offline check-in queue.
- **Models**: `freezed` + `json_serializable` for immutable DTOs and unions.
- **Maps**: `flutter_map` + OpenStreetMap tiles + `latlong2`. Markers from our own SVGs/PNGs.
- **Location**: `geolocator` (+ `permission_handler`).
- **Camera/photos**: `image_picker` + `flutter_image_compress`.
- **Notifications**: `firebase_core` + `firebase_messaging` (Android & iOS via APNs bridge).
- **Google auth**: `google_sign_in`, forwarding the ID token to `POST /auth/google`.
- **i18n**: `flutter_localizations` + `intl` with ARB files generated from the existing `es.json` / `en.json` / `pt.json`.
- **Errors/result**: a small `Result<T>` wrapper (sealed class via `freezed`) + `AppException` hierarchy.
- **Observability**: `logger` for dev, room to add Sentry/Crashlytics later.

### 3.2 Layering (clean architecture, per feature)

```
feature/
  data/
    sources/      # remote (Dio) and local (secure storage / sqflite)
    models/       # *.dto.dart — freezed DTOs mapping 1:1 to JSON
    repositories/ # concrete repos: map DTO <-> entity, orchestrate sources
  domain/
    entities/     # pure Dart value objects used by UI
    repositories/ # abstract interfaces
    usecases/     # (optional) one-call-one-purpose classes when logic is non-trivial
  presentation/
    providers/    # Riverpod providers (state notifiers, future/stream providers)
    screens/      # top-level pages bound to routes
    widgets/      # feature-specific widgets
```

Rules of thumb: widgets only read `domain` types and feature providers; repositories never leak `DioException`; `core/network` owns the HTTP client and exposes a typed `ApiClient` that returns `Result<T>`.

### 3.3 Folder structure (repo root)

```
rayuela-mobile/
  android/ ios/                     # generated by `flutter create` on first machine setup
  assets/
    images/                         # logo, illustrations copied from rayuela-frontend
    icons/                          # badge placeholders, map pins
  docs/
    MIGRATION_PLAN.md               # this file
  lib/
    main.dart                       # entrypoint (loads env, runs RayuelaApp)
    app/
      rayuela_app.dart              # MaterialApp.router wiring
      bootstrap.dart                # async init: secure storage, firebase, etc.
    core/
      config/
        env.dart                    # --dart-define-backed config
      network/
        api_client.dart             # Dio + interceptors + Result
        auth_interceptor.dart
        refresh_interceptor.dart
        api_paths.dart              # single source of truth for backend routes
      storage/
        secure_token_store.dart
      error/
        app_exception.dart
        result.dart
      router/
        app_router.dart             # go_router + redirects
        routes.dart                 # route name constants
      theme/
        app_theme.dart              # Material 3 theme from Rayuela palette
      extensions/                   # BuildContext, DateTime helpers
      utils/                        # small pure helpers
    features/
      auth/
      dashboard/
      projects/
      checkin/
      gamification/
      leaderboard/
      profile/
    shared/
      widgets/                      # RayuelaButton, EmptyState, ErrorView...
      providers/                    # cross-feature providers
    l10n/
      app_en.arb app_es.arb app_pt.arb
  test/
    core/ features/                 # mirrors lib/
  pubspec.yaml
  analysis_options.yaml
  README.md
```

### 3.4 Networking

A single `ApiClient` wraps Dio. Responsibilities:

1. **Base config** — `baseUrl` from `Env.apiBaseUrl` (e.g. `https://api.rayuela.app/v1`), 15s connect + 30s receive.
2. **AuthInterceptor** — attaches `Authorization: Bearer <accessToken>` from `SecureTokenStore`.
3. **RefreshInterceptor** — on `401`, attempts `POST /auth/refresh` (backend patch; see §4.1) using the refresh token; retries the original request once; logs out globally on failure.
4. **Error mapping** — any Dio error becomes an `AppException` (`NetworkException`, `UnauthorizedException`, `ServerException`, `ValidationException(fields)`, `UnknownException`).
5. **Logging** — redacts `Authorization` and `password`; verbose only in debug.
6. **Retry** — idempotent GETs retry with exponential backoff (3 attempts) on transient network errors; POSTs never auto-retry (to avoid duplicate check-ins) — the check-in feature owns its own outbox.

Typed calls use extension methods on `ApiClient`:

```dart
Future<Result<LoginResponseDto>> login(LoginRequestDto req) =>
  request((d) => d.post(ApiPaths.login, data: req.toJson()),
          parse: LoginResponseDto.fromJson);
```

### 3.5 Navigation & auth gating

`go_router` with a `refreshListenable` that rebuilds when auth state changes. The redirect logic:

- If token missing → any protected route redirects to `/login`.
- If token present and role == `Admin` → show a polite "This app is for volunteers; please use the web admin" screen and block further navigation. (This protects us until the backend can return richer error codes.)
- Deep links supported: `rayuela://verify-email?token=...`, `https://rayuela.app/reset-password?token=...` (via universal links + app links).

### 3.6 Error handling conventions

- Repositories return `Future<Result<T>>` (`Success(T)` | `Failure(AppException)`).
- Providers expose `AsyncValue<T>`; the UI shows `ErrorView` with typed messaging (offline banner vs server error vs validation).
- Form screens surface per-field validation errors from `ValidationException`.

### 3.7 Offline & sync (phase 2)

- `sqflite` table `pending_checkins` stores queued submissions with image paths.
- A `CheckinOutboxService` drains the queue in order when connectivity returns, with idempotency keys so the backend can dedupe.
- Requires a backend addition: accept `Idempotency-Key` header on `POST /checkin` and return the existing resource on replay.

---

## 4. Backend changes bundled with this migration

We agreed to patch the backend alongside the app. These go into `rayuela-NodeBackend` on a feature branch.

### 4.1 Must-have (blocks MVP)

1. **Refresh tokens**
   - `POST /auth/login` now returns `{accessToken, refreshToken, expiresIn}` (short-lived 15 min access, 30-day refresh).
   - `POST /auth/refresh` `{refreshToken}` → new pair; rotate and invalidate the old refresh token.
   - `POST /auth/logout` invalidates the refresh token server-side.
   - Store refresh tokens hashed in a new `refresh_tokens` Mongo collection with `userId`, `hash`, `expiresAt`, `deviceLabel`.

2. **Secure gamification mutations**
   - Apply `@UseGuards(JwtAuthGuard)` + `@Roles(UserRole.Admin)` to POST/PATCH/DELETE on `/gamification/*`. Mobile doesn't need these; they must not remain publicly writable.

3. **User profile update**
   - `PATCH /user` with `{complete_name?, profile_image?, locale?}`.
   - `POST /user/profile-image` multipart for avatar uploads (reuse S3 storage, path `avatars/{userId}/{uuid}.ext`).

### 4.2 Should-have (phase 2 but near-term)

4. **Device token registration for push**
   - `POST /user/devices` `{platform: 'android'|'ios', token, locale}` → stores one row per device per user.
   - `DELETE /user/devices/:id` on logout.
   - New `DeviceTokensService` used by a `NotificationService` that fans out FCM/APNs on game events (check-in-awarded-badge, leaderboard-position-changed).

5. **Offline-friendly check-in**
   - `POST /checkin` accepts `Idempotency-Key` header; a new `checkin_idempotency` collection maps key → existing checkin for 7 days.
   - Max image size enforced at 5 MB, type allowlist (`image/jpeg`, `image/png`, `image/webp`).

6. **Pagination and search**
   - `GET /volunteer/public/projects?search=&page=&size=` returns `{items, total, page, size}`. Same on leaderboard.

### 4.3 Nice-to-have

7. Real-time leaderboard via Server-Sent Events at `GET /leaderboard/:projectId/stream` (optional — polling every 30 s works for MVP).
8. Rate limiting (`@nestjs/throttler`) on `POST /checkin` and `POST /auth/*`.

The mobile repo ships with client code that *already* assumes the §4.1 endpoints exist; a compile-time `USE_REFRESH_TOKEN` flag in `Env` gates the refresh interceptor so we can work against the current backend during local dev.

---

## 5. Adaptive-gamification adaptation for mobile

The existing engine lives server-side and is already strategy-driven — good. Mobile's job is to *surface* that adaptation in ways that keep players coming back.

1. **Push notifications as the engagement loop** — on the backend, wire the `Game` output into a notification fan-out:
   - `badge_unlocked`: high-priority, opens the badge detail sheet.
   - `leaderboard_moved`: only when the user crosses a rank they care about (top 3, top 10, personal best); throttled to once per 6 h per project.
   - `recommendation_ready`: once per day, when the adaptive engine has a task it thinks the user will enjoy (`estimatedRating >= 0.7`) within, say, 2 km of their last known location.
   - `project_activity`: digest-style, opt-in.
2. **Session pulses instead of constant polling** — the project detail screen fetches once on open, then a lightweight `/gamification/{projectId}/status?since=<ts>` delta call every 60 s while visible. (New endpoint: `4.3` territory; can be skipped for MVP, fall back to pull-to-refresh.)
3. **Turbo-mode visibility** — when `gamificationStrategy === ELASTIC` and the user is far behind, show a subtle flame badge on the FAB plus a one-time onboarding tooltip: "You're on turbo — next check-ins earn extra points." This mirrors the web's banner but is less intrusive.
4. **Adaptive task ordering** — use the `estimatedRating` the backend already returns on `GET /task/project/:id`; sort tasks by it and annotate the top one with a "Recommended for you" chip.
5. **Rating prompt** — after submitting a check-in and seeing the reward screen, prompt for a 1–5 star rating with a skip option. Keep it short; feed it back via `POST /checkin/rate`.
6. **Offline progress (phase 2)** — allow a check-in to be composed, GPS'd, and photographed offline. Queue it, show a "Pending sync" badge, and process the reward animation when it flushes online. The user-perceived reward is delayed but the act of participating isn't.
7. **Session design** — target a 60–90 second participation loop: open app → see recommended task → tap → camera → submit → reward. Every extra tap between "open" and "camera" is friction and we should instrument it.

---

## 6. Execution plan

### Phase 0 — Foundations (this PR)
- Repo scaffold, `pubspec.yaml`, lint config, theme, Env, core/network, core/storage, router.
- Auth module (login, register, Google sign-in placeholder) wired to real backend.
- Splash that decides `/login` vs `/dashboard` based on stored token.
- Dashboard that lists subscribed projects (`GET /volunteer/projects`).
- Smoke test for `ApiClient`.

### Phase 1 — MVP (≈4 weeks)
- Project detail with tabs (Overview / Tasks / Badges / Leaderboard).
- Check-in flow (location → photos → task type → review) against live backend.
- Check-in history list.
- Gamification view (earned + locked badges, linear progression).
- Leaderboard with pagination.
- Profile view + logout.
- i18n ES/EN/PT.
- Backend §4.1: refresh tokens, guards on gamification, profile update.
- QA on Android + iOS devices; basic analytics counters.

### Phase 2 — Engagement (≈4 weeks)
- FCM + APNs, device token registration, notification deep links.
- Rating prompts in reward screen.
- Offline check-in queue with idempotency (backend §4.2).
- Profile edit + avatar upload.
- Pagination + search on public projects list.
- Accessibility pass (font scaling, screen reader labels, color contrast).

### Phase 3 — Polish & growth
- Badge "next up" coach-mark, turbo-mode flourish.
- SSE-based live leaderboard (backend §4.3 #7).
- App Store / Play Store listings, crash reporting, feature flags.
- A/B tests on recommendation copy and reward animations.

### Risks and open questions

- **1-day JWT**: fatal for mobile retention — addressed by §4.1 refresh tokens.
- **Gamification endpoints lack auth guards** — security issue to fix now (§4.1 #2).
- **No image size/format validation server-side** — clients could accidentally upload huge files; enforce client-side and validate server-side in §4.2.
- **Email links point to `FRONTEND_URL`** — we need either a mobile-aware landing page that detects the app and deep links, or a separate `MOBILE_DEEP_LINK_URL` config. Decision needed.
- **Strategy labels are Spanish literals** (`SIN ADAPTACION`, `ELASTICA`, `SIMPLE`, `ADAPTATIVO`, `PUNTOS PRIMERO`, `MEDALLAS PRIMERO`). Fine for now; when we stabilise, promote to typed enums in a shared contract.
- **Google sign-in requires GOOGLE_CLIENT_ID parity** between web and mobile. Mobile needs its own client IDs per platform registered in the same project.
- **Geolocation accuracy varies** — require `LocationAccuracy.high`, fall back to manual placement if jitter > 50 m.
- **No offline endpoints today** — phase 2 work; client scaffolds for it from day one.
- **Role detection blocks admins** — admins who open the mobile app today are logged in but with no screens to use; we'll show a branded "Use the web console" wall until (and unless) a mobile admin need is established.

---

## Appendix A — Web route → mobile screen map

| Web | Mobile screen | Changes |
|---|---|---|
| `/` (HomeView) | `ProjectDiscoveryScreen` | Search + filter added; card layout adapted to phone width |
| `/login` | `LoginScreen` | Same fields, native keyboard types, password reveal toggle |
| `/register` | `RegisterScreen` | Multi-step (credentials → profile → T&Cs) |
| `/forgot-password`, `/reset-password` | `ForgotPasswordScreen`, `ResetPasswordScreen` | Deep-linked from email |
| `/verify-email` | `VerifyEmailScreen` | Deep-linked; shows success/failure and continues to dashboard |
| `/dashboard` | `DashboardScreen` | List of subscribed projects + quick-stats chip (total points, badges) |
| `/project/:id/view` | `ProjectDetailScreen` (tabs) | Map on Overview; Tasks sorted by `estimatedRating`; Badges linear; Leaderboard infinite-scroll |
| `/project/:id/view` (check-in section) | `CheckinFlowScreen` | Separate multi-step flow, not embedded in detail |
| `/leaderboard` | `GlobalLeaderboardScreen` | Per-project picker; bottom sheet for details |
| (none on web) | `ProfileScreen` | New; edit profile, language, logout |
| `/admin/*` | **not ported** | Stays on web |

## Appendix B — Endpoint usage matrix

Mobile hits only end-user endpoints; everything else stays admin-only on web.

| Endpoint | Used by mobile screen |
|---|---|
| `POST /auth/register` | RegisterScreen |
| `POST /auth/login` | LoginScreen |
| `POST /auth/google` | LoginScreen (Google) |
| `POST /auth/forgot-password` | ForgotPasswordScreen |
| `POST /auth/recover-password` | ResetPasswordScreen |
| `POST /auth/verify-email` | VerifyEmailScreen |
| `POST /auth/refresh` (new) | RefreshInterceptor |
| `POST /auth/logout` (new) | ProfileScreen |
| `GET /user` | Splash, ProfileScreen |
| `PATCH /user` (new) | ProfileScreen |
| `POST /user/devices` (new) | bootstrap after login |
| `GET /volunteer/public/projects` | ProjectDiscoveryScreen |
| `GET /volunteer/projects` | DashboardScreen |
| `GET /projects/:id`, `GET /projects/public/:id` | ProjectDetailScreen |
| `POST /volunteer/subscription/:id` | ProjectDetailScreen |
| `GET /task/project/:id` | ProjectDetailScreen (Tasks tab) |
| `GET /gamification/:projectId` | ProjectDetailScreen (Badges tab) |
| `POST /checkin` | CheckinFlowScreen |
| `POST /checkin/rate` | RewardSheet |
| `GET /checkin/user/:projectId` | CheckinHistoryScreen |
| `GET /leaderboard/:projectId` | LeaderboardScreen |
| `GET /storage/file?key=...` | any image (checkin photo, badge image, avatar) |
