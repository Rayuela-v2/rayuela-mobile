# Rayuela Mobile

App Flutter para Rayuela, la plataforma de ciencia ciudadana con gamificación adaptativa. **Solo para voluntarios** — la consola de administración sigue viviendo en la web Vue 3.

- Frontend web: `../rayuela-frontend`
- Backend NestJS: `../rayuela-NodeBackend`
- Documentos:
  - [`docs/MIGRACION_RESUMEN.md`](docs/MIGRACION_RESUMEN.md) — qué se construyó, por qué, y diagramas de arquitectura y flujo (en español).
  - [`docs/MIGRATION_PLAN.md`](docs/MIGRATION_PLAN.md) — plan original detallado y hoja de ruta por fases (en inglés).

## Qué hace la app

Un voluntario abre la app, ve sus proyectos suscritos en el dashboard y entra al detalle de uno. Allí encuentra un mapa con las áreas del proyecto coloreadas según haya o no tareas pendientes, sus check-ins anteriores, su posición en el leaderboard y sus medallas conseguidas. Tocando un área puede saltar a la lista de tareas filtrada por esa zona; tocando una tarea o el FAB lanza el flujo de check-in (GPS, cámara, tipo de tarea, revisión y envío). Al confirmar, el backend devuelve los puntos y medallas obtenidos en una pantalla de recompensa.

Funcionalmente cubre: autenticación (login/registro/splash), dashboard de proyectos suscritos, detalle de proyecto con tres pestañas (Overview, Check-ins, Progreso), mapa de áreas con marcadores de check-in y posición de usuario, lista de tareas con filtro por área, flujo de check-in con cámara y geolocalización, historial de check-ins, y leaderboard por proyecto.

## Requisitos

| Herramienta | Versión |
|---|---|
| Flutter SDK | **3.27+** |
| Dart | **3.6+** |
| Xcode (iOS) | 15+ |
| Android Studio + Android SDK | 34 |
| CocoaPods | 1.15+ |
| Backend `rayuela-NodeBackend` | Corriendo en local (puerto 3000) o accesible por URL |

Para que el GPS y la cámara funcionen en dispositivo real, las plataformas necesitan los permisos correspondientes (`NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription` en iOS, `ACCESS_FINE_LOCATION` y `CAMERA` en Android). El scaffold de plataforma generado por `flutter create` los incluye, pero conviene revisar `ios/Runner/Info.plist` y `android/app/src/main/AndroidManifest.xml` después de generarlo.

## Setup inicial en una máquina nueva

El repo incluye los proyectos nativos generados (`android/`, `ios/`) con los permisos de cámara y ubicación ya declarados, así que no hace falta correr `flutter create`. Solo instalá dependencias:

```bash
flutter pub get
cd ios && pod install && cd ..
```

## Configuración del backend

La configuración va por `--dart-define`. Copiá el ejemplo y editalo con la URL de tu backend y la `GOOGLE_CLIENT_ID` (todavia no agregue Google sign-in):

```bash
cp .env.example .env.development
# editá API_BASE_URL, GOOGLE_CLIENT_ID, etc.
```

Si el backend corre en `localhost`, recordá que el emulador Android no resuelve `localhost`: usá `10.0.2.2`. iOS Simulator sí resuelve `localhost` directamente.

## Cómo correr la app

```bash
flutter run --dart-define-from-file=.env.development
```

Para elegir dispositivo:

```bash
flutter devices                              # lista los disponibles
flutter run -d <id> --dart-define-from-file=.env.development
```

## Tests

```bash
flutter test                                 # corre toda la suite
flutter test test/features/dashboard/        # solo una feature
flutter analyze                              # análisis estático con lints estrictos
```

La suite incluye tests de DTO para auth, dashboard, tasks, check-in, leaderboard y áreas, además de un smoke test del `ApiClient` con `mocktail` que verifica el mapeo `DioException → AppException`.

## Estructura del proyecto

```
lib/
  main.dart                          Entrypoint
  app/                               Bootstrap + MaterialApp.router
  core/
    network/                         Dio client + interceptores
    storage/                         Token store seguro
    router/                          go_router con redirección por sesión
    theme/                           Material 3 con paleta Rayuela
  features/
    auth/                            Login, registro, splash
    dashboard/                       Lista de proyectos + detalle + mapa de áreas
    tasks/                           Lista de tareas con filtro por área
    checkin/                         Captura, mapa, fotos, resultado, historial
    leaderboard/                     Tabla por proyecto
  shared/widgets/                    ErrorView, EmptyState, AdminNotSupportedScreen
  l10n/                              ARB files (ES / EN / PT)
test/                                Refleja la estructura de lib/
```

Cada feature respeta la misma división interna: `data/` (DTOs, sources, repository impls), `domain/` (entities, abstract repositories), `presentation/` (screens, widgets, providers de Riverpod). El detalle de las decisiones detrás está en [`docs/MIGRACION_RESUMEN.md`](docs/MIGRACION_RESUMEN.md).

## Stack

Flutter 3.27 + Dart 3.6, Material 3, Riverpod 2.5, go_router 14, Dio 5, flutter_secure_storage, flutter_map + OpenStreetMap + latlong2, geolocator, image_picker + flutter_image_compress, cached_network_image. Sin generación de código (sin freezed/json_serializable por ahora) — los DTOs son hechos a mano para mantener parseo defensivo legible junto al wire shape del backend.

## Cambios planeados en el backend

La app asume algunos endpoints que todavía no existen o que hay que endurecer en `rayuela-NodeBackend`. Los detalles están en `docs/MIGRATION_PLAN.md` §4. En orden de prioridad: refresh tokens (`POST /auth/refresh`, `POST /auth/logout`) para que la sesión móvil dure más de un día, guards de admin en `POST/PATCH/DELETE /gamification/*`, `PATCH /user` para edición de perfil, `POST /user/devices` para FCM/APNs, e `Idempotency-Key` en `POST /checkin` para soportar la cola offline.

## Próximos pasos

Fase 1 (MVP, ya implementada): autenticación, dashboard, detalle de proyecto con tabs, mapa de áreas, tareas con filtro, check-in completo, historial, leaderboard. Fase 2: notificaciones push, calificación post-check-in, cola offline, edición de perfil, paginación + búsqueda. Fase 3: leaderboard en vivo (SSE), coach-marks de modo turbo, publicación en stores, reporte de crashes, feature flags y A/B tests.
