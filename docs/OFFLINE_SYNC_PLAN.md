# Rayuela Mobile — Offline & Sync (Phase 2)

> Plan de diseño e implementación para que un voluntario pueda usar la app
> sin conexión, con foco en **cargar check‑ins offline** y vaciado automático
> de la cola al recuperar conexión.
>
> Referencia previa: `docs/MIGRATION_PLAN.md` §3.7 (Offline & sync).
>
> Idioma técnico de este documento: ES (mismo que el equipo). Código y
> comentarios siguen las convenciones EN del repo.

---

## 1. Objetivos y no‑objetivos

### 1.1 Must‑have (objetivo primario)

1. El voluntario puede **componer y enviar** un check‑in (GPS + fotos +
   taskType + notas) sin conexión. La app lo encola y muestra estado
   `Pendiente`.
2. Apenas hay conexión —o al volver a abrir la app con red— la cola se
   **vacía automáticamente** en orden FIFO, con reintentos exponenciales y
   sin duplicados (idempotencia end‑to‑end).
3. El usuario percibe el éxito/fracaso por check‑in: confeti + recompensa al
   sincronizar bien; banner accionable si quedan ítems atascados.
4. La app **no pierde nunca** un check‑in compuesto offline aunque el usuario
   mate la app, reinicie el teléfono o se quede sin batería antes de
   sincronizar (durabilidad WAL en SQLite + ficheros en disco).
5. La cola sobrevive a un cambio de versión de la app (migraciones de
   esquema versionadas).

### 1.2 Should‑have

6. Visualizar **proyectos suscritos**, sus **tareas**, **áreas (mapa)** y el
   **leaderboard** según la última copia local mientras no hay red. Tiles
   del mapa cacheados (OpenStreetMap raster, hasta cierto zoom y bbox).
7. Indicadores claros de "datos posiblemente desactualizados" (timestamp de
   última sincronización por proyecto).

### 1.3 Nice‑to‑have

8. Caché de avatares y de imágenes de check‑ins históricos para el detalle
   de proyecto (el `cached_network_image` ya lo hace bien para HTTP, pero
   añadiremos pre‑carga al subscribirse).
9. Sincronización de fondo periódica (Android `WorkManager` / iOS
   `BGTaskScheduler`) para vaciar la cola incluso sin abrir la app.

### 1.4 Fuera de alcance (Phase 2)

- Edición offline de proyectos/tareas/insignias (todo eso es admin web).
- Resolución de conflictos por `lastWrite‑wins` complejos: las únicas
  mutaciones offline son **inserciones de check‑ins** (append‑only desde
  el cliente) y **valoraciones** (idempotentes). No hay updates ni deletes.
- Sincronización P2P / multi‑dispositivo con CRDT.

---

## 2. Mejores prácticas mobile que aplicaremos

Decisiones tomadas, con su porqué.

| Tema | Decisión | Motivo |
|---|---|---|
| Persistencia estructurada | `sqflite` + esquema con `PRAGMA journal_mode=WAL` y `synchronous=NORMAL` | Ya está reservado en `pubspec.yaml`; WAL evita pérdidas en cierres bruscos sin penalizar mucho la latencia. |
| Capa de acceso | Repositorio con `LocalSource` + `RemoteSource`; el `Repository` decide según conectividad y estado de la cola | Mantiene el patrón clean‑arch existente; UI sigue ignorando si los datos vienen del wire o del disco. |
| Imágenes a enviar | Copiar al **directorio interno de la app** (`getApplicationSupportDirectory`) **antes** de encolar, sub‑carpeta por `outboxId` | El `image_picker` deja archivos en cache (`/Caches`) que iOS/Android pueden purgar; necesitamos rutas estables hasta sincronizar. Si el usuario borra la foto del rollo, no perdemos la copia. |
| Compresión | `flutter_image_compress` a JPEG 1600px lado largo, q≈80, EXIF mínimo (excepto orientation) | Reduce tamaño 5‑10×, baja la probabilidad de timeouts, alinea con §4.2 del MIGRATION_PLAN (5 MB max). |
| Idempotencia | UUID v4 por outbox row → header `Idempotency-Key` en `POST /checkin` | Previene check‑ins duplicados por reintentos / Network races (cliente reintenta tras 504 que en realidad llegó). |
| Conectividad | `connectivity_plus` para señal **+** ping de salud (`HEAD /health` o `GET /me`) antes de drenar | `connectivity_plus` solo dice "hay interfaz", no si hay tráfico real (captive portals, datos sin cobertura, VPN cerrada). |
| Reintentos | Exponential backoff con jitter: 5 s, 15 s, 60 s, 5 min, 30 min, 2 h, 6 h (máx); `attemptCount` por ítem; reset al pasar a foreground | Evita tormenta de reintentos; respeta servidores; alineado con buenas prácticas Google/Apple. |
| Trabajo en background | App lifecycle (`AppLifecycleState.resumed`) + `connectivity_plus` stream para drenar de inmediato; `workmanager` (Android) y `BGTaskScheduler` (iOS) **opcional** para drenar sin abrir la app | iOS es muy restrictivo con background; no podemos prometer "sincroniza en 2 minutos" sin el usuario, así que el primer ciclo se dispara al volver al foreground. |
| Concurrencia | Una sola tarea de drenado a la vez (lock por `Mutex` o `Completer`); fotos se cargan en stream, no todas a memoria | Evita doble envío del mismo ítem cuando se solapan los disparadores. |
| Aislamiento por usuario | Todas las tablas llevan `userId`; al hacer logout se borra la cola si el usuario lo confirma | Nunca enviamos un check‑in compuesto por **otro** usuario tras un cambio de cuenta. |
| Estado expuesto a UI | `OutboxNotifier` (Riverpod `AsyncNotifier`) emite `List<OutboxEntry>` y un agregado `SyncStatus { idle, syncing, error, offline }` | Las pantallas consumen un `provider` claro y reactivo. |
| Telemetría | Contadores `outbox_enqueued`, `outbox_sent_ok`, `outbox_sent_fail`, `outbox_dropped` con razón | Imprescindible para detectar regresiones y outbox "huérfanas". |
| Privacidad | El `outbox` no se cifra entero, pero **no almacenamos PII más allá de coords/fotos**; el token sigue en `flutter_secure_storage`. Las fotos se borran tras éxito o por TTL (ver §6.3). | Cumple esperable de una app de campo; si en el futuro guardamos correos u otros datos, encriptamos con `sqlcipher`. |
| Migraciones DB | Versión + script por incremento; pruebas que abren v1 y suben a vN | No queremos que un usuario con 12 check‑ins sin sincronizar pierda nada al actualizar la app. |
| Tiempo del servidor | Enviamos `datetime` capturado en cliente (UTC) **+** `clientCapturedAt`. El backend confía en `datetime` salvo desviación >24 h | Permite trazabilidad si el reloj del teléfono está mal. |
| Errores tipados | Reusar `AppException`; agregar `SyncSkippedException`, `SyncPermanentException`, `SyncRetryableException` | Clasificación clara guía la decisión "reintento vs descarta vs avisa". |
| Tests | Unit (dao, repos, drainer, mapper), integración (sqflite_common_ffi en Linux/Mac CI), widget (estados de cola), end‑to‑end con backend stub | Cobertura escalonada; el drenado merece tests deterministas. |

---

## 3. Arquitectura general

### 3.1 Diagrama lógico

```
 ┌────────────────────────────────────────────────────────────────────┐
 │                          Presentation                              │
 │   CheckinScreen ──▶ OutboxController ──▶ checkinSubmitController   │
 │   ProjectDetail/Dashboard ──▶ syncStatusProvider, outboxBadge      │
 └─────────────┬──────────────────────────────────────────────────────┘
               │
 ┌─────────────▼──────────────────────────────────────────────────────┐
 │                            Domain                                  │
 │   CheckinsRepository  (submitCheckin → Online | Queued)            │
 │   ProjectsRepository  (cache‑first read)                           │
 │   OutboxService       (drain, retry policy, lifecycle hooks)       │
 │   ConnectivityService (real connectivity, not just interface)      │
 └─────────────┬──────────────────────────────────────────────────────┘
               │
 ┌─────────────▼──────────────────────────────────────────────────────┐
 │                             Data                                   │
 │   CheckinsRemoteSource (Dio multipart, Idempotency-Key)            │
 │   CheckinsLocalSource  (sqflite tables: outbox, history_cache)     │
 │   ProjectsLocalSource  (sqflite: projects, tasks, areas, leaders.) │
 │   ImageStore           (path_provider + dart:io move/compress)     │
 │   AppDatabase          (open, migrate, expose Database)            │
 └────────────────────────────────────────────────────────────────────┘
```

### 3.2 Nuevas dependencias

Añadir a `pubspec.yaml` (descomentar / sumar):

```yaml
sqflite: ^2.3.3+1
path_provider: ^2.1.4
path: ^1.9.0
connectivity_plus: ^6.0.5
mutex: ^3.1.0
uuid: ^4.5.1
# Opcionales en último sub‑sprint para sync background:
workmanager: ^0.5.2          # Android
# iOS: BGTaskScheduler vía paquete propio o channel manual.
flutter_cache_manager: ^3.4.1  # opcional para tiles OSM
```

### 3.3 Layout de carpetas (incrementos)

```
lib/
  core/
    sync/
      app_database.dart              # open + migraciones
      connectivity_service.dart      # interfaz + ping real
      outbox/
        outbox_entry.dart            # entidad
        outbox_dao.dart              # CRUD sqflite
        outbox_service.dart          # encolar + drenar
        outbox_drainer.dart          # loop con backoff/jitter
        outbox_lifecycle.dart        # listener AppLifecycleState
        sync_status.dart             # enum + freezed‑like state
    storage/
      image_store.dart               # path_provider + ops de fichero
  features/
    checkin/
      data/
        sources/
          checkins_local_source.dart # outbox + history cache
        repositories/
          checkins_repository_impl.dart   # decora online/offline
      presentation/
        widgets/
          outbox_badge.dart
          pending_checkin_tile.dart
        providers/
          outbox_providers.dart
    dashboard/
      data/
        sources/
          projects_local_source.dart # cache de proyectos+áreas
    tasks/
      data/
        sources/
          tasks_local_source.dart    # cache de tareas por proyecto
    leaderboard/
      data/
        sources/
          leaderboard_local_source.dart # snapshot por proyecto
```

### 3.4 Inicialización (bootstrap)

En `lib/app/bootstrap.dart`:

1. Abrir `AppDatabase.open()` antes de instanciar `ApiClient`.
2. Construir `ConnectivityService`, `ImageStore`, `OutboxService` y
   exponerlos vía Riverpod (`Provider.overrideWithValue`).
3. Registrar `OutboxLifecycle` que observa `WidgetsBinding.instance` para
   `resumed` y `connectivityService.onChange` para disparar `drain()`.
4. Disparar un `drain()` opportunista al final del bootstrap (no bloqueante)
   para que cualquier item pendiente arranque antes de la primera pantalla.

---

## 4. Esquema local (SQLite)

Versión inicial del esquema `1`. Cualquier cambio incrementa la versión y
añade un script en `_migrations`.

```sql
-- Outbox (insertions únicamente, append‑only por usuario)
CREATE TABLE outbox_checkins (
  id                   TEXT PRIMARY KEY,            -- UUID v4 (= idempotency key)
  user_id              TEXT NOT NULL,
  project_id           TEXT NOT NULL,
  task_id              TEXT,                        -- null si fue desde el FAB del proyecto
  task_type            TEXT NOT NULL,
  latitude             TEXT NOT NULL,
  longitude            TEXT NOT NULL,
  datetime_iso         TEXT NOT NULL,               -- UTC ISO‑8601
  client_captured_at   TEXT NOT NULL,
  notes                TEXT,
  status               TEXT NOT NULL,               -- pending | inflight | failed | dead
  attempt_count        INTEGER NOT NULL DEFAULT 0,
  next_attempt_at      TEXT,                        -- UTC ISO‑8601, null = ya
  last_error_code      TEXT,
  last_error_message   TEXT,
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);
CREATE INDEX idx_outbox_user_status     ON outbox_checkins(user_id, status, next_attempt_at);
CREATE INDEX idx_outbox_project         ON outbox_checkins(project_id, created_at);

-- Imágenes asociadas (relación 1:N) — guardamos ruta absoluta
-- en el sandbox de la app, **no** la del rollo, para no perderlas.
CREATE TABLE outbox_checkin_images (
  outbox_id   TEXT NOT NULL,
  position    INTEGER NOT NULL,
  file_path   TEXT NOT NULL,
  byte_size   INTEGER NOT NULL,
  mime_type   TEXT NOT NULL,
  PRIMARY KEY (outbox_id, position),
  FOREIGN KEY (outbox_id) REFERENCES outbox_checkins(id) ON DELETE CASCADE
);

-- Cache de proyectos suscritos (mostrar dashboard offline)
CREATE TABLE cached_projects (
  user_id          TEXT NOT NULL,
  project_id       TEXT NOT NULL,
  payload_json     TEXT NOT NULL,                   -- ProjectDetail serializado
  is_subscribed    INTEGER NOT NULL DEFAULT 1,
  fetched_at       TEXT NOT NULL,
  PRIMARY KEY (user_id, project_id)
);

CREATE TABLE cached_tasks (
  user_id          TEXT NOT NULL,
  project_id       TEXT NOT NULL,
  payload_json     TEXT NOT NULL,                   -- List<TaskItem> entera
  fetched_at       TEXT NOT NULL,
  PRIMARY KEY (user_id, project_id)
);

CREATE TABLE cached_leaderboards (
  user_id          TEXT NOT NULL,
  project_id       TEXT NOT NULL,
  payload_json     TEXT NOT NULL,
  fetched_at       TEXT NOT NULL,
  PRIMARY KEY (user_id, project_id)
);

-- Historial de check‑ins por proyecto (último visto online).
-- Permite al voluntario revisar lo que ya envió aunque esté offline.
CREATE TABLE cached_checkin_history (
  user_id          TEXT NOT NULL,
  project_id       TEXT NOT NULL,
  payload_json     TEXT NOT NULL,
  fetched_at       TEXT NOT NULL,
  PRIMARY KEY (user_id, project_id)
);
```

**Decisiones de modelado:**

- Guardamos los snapshots como `payload_json` para no acoplar el esquema a
  los DTO (que cambian cuando avanza el backend). El precio es no poder
  consultar por columna; aceptable porque las pantallas piden "todo el
  proyecto" o "todas las tareas".
- La cola es **única**: solo check‑ins. Las valoraciones (`POST /checkin/rate`)
  se intentan online; si fallan, se guardan como acción derivada en otra
  tabla `outbox_ratings` (mismo patrón) en una segunda iteración.
- `status='dead'` indica que el ítem agotó su política de reintentos por un
  error permanente (4xx no reintentable, e.g. 403 / 422 con campos inválidos
  irrecuperables); requiere acción del usuario (ver §7.4).

---

## 5. Flujos clave

### 5.1 Encolar un check‑in (siempre que el usuario pulsa "Enviar")

Se cambia el contrato de `submitCheckin` para devolver `CheckinSubmissionOutcome`:

```dart
sealed class CheckinSubmissionOutcome {
  const CheckinSubmissionOutcome();
}
class CheckinSubmissionAccepted extends CheckinSubmissionOutcome {
  final CheckinResult result;          // del wire
  const CheckinSubmissionAccepted(this.result);
}
class CheckinSubmissionQueued extends CheckinSubmissionOutcome {
  final String outboxId;               // para ver "pendiente" en historial
  const CheckinSubmissionQueued(this.outboxId);
}
class CheckinSubmissionRejected extends CheckinSubmissionOutcome {
  final AppException error;            // 422/4xx → no encolamos
  const CheckinSubmissionRejected(this.error);
}
```

Pipeline en `CheckinsRepositoryImpl.submitCheckin`:

1. `imageStore.persist(req.imagePaths) → List<String>` (copia + comprime al
   sandbox, devuelve rutas estables).
2. Si la conectividad es **online** y la cola está vacía:
   - Intentar `remote.submit(req, idempotencyKey: uuid)`.
   - **Éxito** → eliminar las copias del sandbox → `Accepted`.
   - **Error de red / timeout / 5xx** → `outbox.enqueue(req, uuid)` →
     `Queued`. (Reusamos el mismo `uuid` que se usó como Idempotency‑Key.)
   - **Error 4xx no `409`** → `Rejected` (devolvemos a UI).
   - **`409 Conflict` con header `X-Original-Resource: <id>`** → `Accepted`
     (el backend ya tenía esa idempotency key registrada).
3. Si la conectividad es **offline** o la cola **no** está vacía:
   - `outbox.enqueue(req, uuid)` → `Queued`. (No saltamos la cola para
     respetar el orden FIFO percibido por el usuario.)

UI: `CheckinScreen` actualmente dispara `pushReplacementNamed(checkinResult)`
con el `CheckinResult` real. Lo cambiamos a:

- `Accepted` → mantiene comportamiento (pantalla de recompensa).
- `Queued` → navega a `checkinResult` con un payload "Pendiente" (insignias
  y puntos en gris, nota: "Lo enviaremos en cuanto tengas conexión").
- `Rejected` → muestra el banner de error in‑situ (igual que hoy).

### 5.2 Drenado automático

Disparadores que llaman a `OutboxService.drain()`:

- `AppLifecycleState.resumed` (volvemos a primer plano).
- Conectividad pasa de `none` → `wifi|mobile`.
- Pull‑to‑refresh en pantallas que muestran cola.
- Tras un `enqueue` exitoso, si la conectividad es online (intento inmediato
  bajo el mutex, evitando recursión).
- Cron de `WorkManager` / `BGTaskScheduler` (Phase 2 final).

`drain()` toma el primer `pending|failed` con `next_attempt_at <= now()`,
intenta enviarlo y, según resultado:

- **Éxito** → marca `sent`, borra fila + imágenes, invalida providers
  afectados (`userCheckinsProvider(projectId)`,
  `subscribedProjectsProvider`).
- **Retryable** (red, timeout, 5xx, 429) → `attempt_count++`,
  `next_attempt_at = now + backoff(attempt_count)` con jitter ±15 %.
- **Permanent** (4xx ≠ 409 ni 429) → `status='dead'`, surge `OutboxFailed`
  evento para mostrar al usuario.
- **`409 Conflict`** → tratamos como éxito (idempotencia: ya estaba creado).

`drain()` repite mientras queden ítems elegibles **y** el server siga
respondiendo OK. Sale al primer error que no sea 409 para no machacar la
red. El loop tiene un cap por ciclo (p. ej. 50 ítems) para no bloquear UI.

### 5.3 Backoff con jitter

```dart
Duration backoff(int attempt) {
  const base = [5, 15, 60, 300, 1800, 7200, 21600];
  final s = base[attempt.clamp(0, base.length - 1)];
  final jitter = 0.85 + Random().nextDouble() * 0.30; // 0.85..1.15
  return Duration(seconds: (s * jitter).round());
}
```

Tras `attempt_count >= 7` y un error sin progreso, se marca `dead` y se
notifica al usuario. (Configurable.)

### 5.4 Hidratación offline (lecturas)

Los repos de proyectos/tareas/leaderboard adoptan **stale‑while‑revalidate**:

1. `getX` consulta primero `local.getX(userId, ...)`.
2. Si hay datos en cache, los emite **inmediatamente** (UI muestra contenido)
   y dispara en paralelo una llamada al `remoteSource`.
3. Si el `remote` responde, sobrescribe la cache + emite la versión nueva.
4. Si el `remote` falla con red/5xx, no es un error duro: la UI se queda
   con la copia y se muestra un chip "Última actualización: hace 2 h".
5. Si **no** había cache y el `remote` falla, propagamos `NetworkException`
   normal → la UI muestra `ErrorView` ya existente.

Ese patrón se implementa con un pequeño helper `staleWhileRevalidate<T>`
para no repetir lógica.

### 5.5 Mapa offline (áreas + tiles)

- Las **áreas** (GeoJSON) ya viven en `ProjectDetail.areas` → se cachean en
  `cached_projects.payload_json`. El `flutter_map` puede pintarlas sin red.
- Los **tiles** (OSM raster) se sirven mediante un `TileProvider` apoyado en
  `flutter_cache_manager`. Solo añadimos pre‑caché on demand: al abrir el
  detalle de un proyecto suscrito, si hay Wi‑Fi y permiso de "descargar
  mapas", encolamos un job que descarga los tiles de las áreas a zoom
  16‑18 (límite duro de ~30 MB por proyecto).
- Si el usuario abre el mapa offline sin tiles cacheados, mostramos el mapa
  vacío con polígonos sobre fondo neutro y un mensaje "Mapas no
  descargados".

### 5.6 Logout

Al cerrar sesión:

1. Confirmación si hay `outbox_checkins` con `status != sent`: **"Tienes
   N check‑ins pendientes de enviar; si cierras sesión se perderán al
   ingresar otra cuenta. ¿Enviarlos ahora?"**.
   - "Enviar" → fuerza `drain()` esperando hasta 30 s con feedback.
   - "Cerrar igualmente" → mantiene la cola **del userId** en disco; se
     reanuda si el mismo usuario vuelve a iniciar sesión.
2. Borramos imágenes huérfanas de la cola sólo cuando `outbox_drop_user`
   se ejecuta explícitamente (acción "Borrar datos pendientes de este
   usuario" en Ajustes).

---

## 6. Almacenamiento de archivos (imágenes)

### 6.1 Rutas

`ImageStore` define dos directorios:

- **`outbox/`** dentro de `getApplicationSupportDirectory()` (no se borra
  por purge del SO). Ruta: `outbox/<outboxId>/<position>.jpg`.
- **`tmp_compress/`** en `getTemporaryDirectory()` para compresiones
  intermedias. Se vacía al arranque.

### 6.2 Operaciones

```dart
class ImageStore {
  Future<List<StoredImage>> persist(
    List<String> sourcePaths, {
    required String outboxId,
  });
  Future<void> deleteForOutbox(String outboxId);
  Future<int> sweepOrphans({Duration minAge = const Duration(days: 14)});
}
```

`persist`:

1. Para cada `sourcePath`:
   - Comprimir a `tmp_compress/<uuid>.jpg` (1600px, q80).
   - Mover a `outbox/<outboxId>/<position>.jpg`.
   - Devolver `StoredImage(path, byteSize, mime)`.
2. Si alguna falla, limpiar lo ya copiado para ese `outboxId`.

### 6.3 Limpieza

- Tras éxito del POST: `deleteForOutbox(outboxId)`.
- `sweepOrphans` corre al bootstrap: borra carpetas de `outbox/<id>` cuya
  fila ya no existe en SQLite; limpia ficheros con mtime > 14 días sin
  referencia.
- Si la cuota usada supera 200 MB se avisa al usuario (raro pero posible
  en pueblos sin red durante días).

### 6.4 Privacidad y permisos

- En Android, las rutas internas son privadas a la app: no requieren
  `READ_MEDIA_IMAGES`.
- En iOS, idem el sandbox.
- Si en el futuro queremos exponer las imágenes a otras apps, lo haremos
  vía content provider / `Photos.framework` con permiso explícito.

---

## 7. Cambios de UI/UX

### 7.1 CheckinScreen

- Botón **"Enviar"** sigue diciendo "Enviar"; **no** lo cambiamos a "Encolar"
  para no añadir jerga. La diferencia se comunica en la pantalla siguiente.
- Añadimos chip pequeño bajo el botón: **"Sin conexión — se enviará al
  recuperarla"** cuando `connectivity == none`.
- Si la app detecta GPS sin red al pulsar enviar, no hay confirmación extra:
  acepta y encola.

### 7.2 CheckinResultScreen

Dos modos:

- **Confirmado** (online): igual que hoy, con puntos/insignias.
- **Pendiente**: ilustración distinta + texto "Lo enviaremos automáticamente
  cuando recuperes conexión." + botón "Ver mis check‑ins". No mostramos
  recompensa porque el backend aún no la calculó.

### 7.3 Historial del proyecto (UserCheckinsView)

La lista mezcla `CheckinHistoryItem` (servidor) con `OutboxEntry`
(pendientes locales) — los pendientes encabezan la lista con un badge
"Pendiente" y, si están en `failed`, "Reintentando…" con tap‑to‑detail.

### 7.4 Estado global de sincronización

- `SyncStatus` en `Riverpod` con valores `idle | offline | syncing | error`.
- En la `AppBar` del `Dashboard` y `ProjectDetail`:
  - `offline`: icono `cloud_off` + tooltip "Sin conexión".
  - `syncing`: spinner + número de pendientes.
  - `error`: icono ámbar + tap abre `OutboxScreen` con detalle.
- En **Ajustes** añadimos pantalla **"Datos pendientes"**:
  - Listado de outbox por proyecto.
  - Acciones por ítem: "Reintentar ahora", "Editar y reintentar" (sólo
    `dead` con error de validación), "Descartar".
  - Acción global: "Reintentar todos".

### 7.5 Banners

- Banner persistente al inicio del Dashboard si hay `outbox > 0`:
  - "Tienes N check‑ins por enviar — Reintentar ahora ▸".
  - Color: `tertiary` (no es error, es información).
- Snack al cerrar la app con cola pendiente: "Tus check‑ins se enviarán al
  recuperar conexión." (solo la primera vez, para no ser molestos).

### 7.6 Accesibilidad e i18n

- Todos los textos se añaden a `app_en.arb`, `app_es.arb`, `app_pt.arb`.
- Iconos llevan `Semantics(label: ...)`. Estados de cola se anuncian.

---

## 8. Cambios en backend (resumen, ver MIGRATION_PLAN §4.2 #5)

Para que el contrato sea idempotente y robusto:

1. **Idempotency-Key**: `POST /checkin` acepta header `Idempotency-Key:
   <uuid>`. Nueva colección `checkin_idempotency` (key, userId, checkinId,
   createdAt, ttl 7 días).
   - Si la key existe **y** el userId coincide → devolver `200 OK` con el
     check‑in original (no recomputar gamificación) **+** header
     `X-Original-Resource: <id>`.
   - Si la key existe pero userId distinto → `409 Conflict`.
   - Si no existe → procesar normalmente y guardar la entrada.
2. **Validación de tamaño/tipo**: rechazar imágenes > 5 MB o MIME fuera de
   `image/jpeg|png|webp` con `422` y `fieldErrors[image]`.
3. **Endpoint health‑check**: `GET /health` ligero (sin auth) para que el
   `ConnectivityService` distinga "interfaz" de "alcanzable".
4. **Errores tipados**: respuesta de error JSON consistente
   `{ code, message, details? }` para que el cliente sepa si es retryable.

Estas dos primeras se consideran **bloqueantes** para Phase 2; el resto son
mejoras complementarias.

---

## 9. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Reloj del cliente desfasado → `datetime` raro | Datos sucios, gamificación injusta | Enviar también `clientCapturedAt` y `serverReceivedAt`; validar en backend; advertir si Δ > 24 h. |
| Captive portal / Wi‑Fi sin internet real | Cola "atascada" | Ping `GET /health` antes de drenar; si falla, considerar offline. |
| Espacio en disco escaso | Encolar falla silenciosamente | `ImageStore.persist` mide y, si free < 50 MB, devuelve error claro al usuario antes de añadir a cola. |
| Cambio de cuenta antes de drenar | Confusión | Confirmación de logout (§5.6) + `userId` en cola. |
| Backend rechaza por validación nueva (cliente viejo) | Cola muerta | Endpoint que devuelve `details` + UI con "Editar y reintentar". |
| `image_picker` en iOS escribe en `/private/var/...` y el SO lo purga | Pérdida de fotos | Copia inmediata a `outbox/<id>/` antes de salir de la pantalla. |
| Migraciones DB con cola llena | Pérdida de datos | Tests que abren v(N‑1) con seeds y suben a vN; `_migrations` no destructivo. |
| Reentrancia del drainer | Doble envío | `Mutex` global + filas en `inflight` con TTL (re‑adoptar si `inflight` lleva > 10 min). |
| Permisos de notificaciones denegados | El usuario no se entera del fallo | Banner persistente en Dashboard + badge en AppBar; las push son extra, no único canal. |
| Drift de zona horaria | `datetime` UTC equivocado | Capturamos siempre con `DateTime.now().toUtc()`; UI formatea con TZ del dispositivo. |

---

## 10. Plan de ejecución

Se ejecuta sobre `feature/offline-sync` partiendo de la línea base actual
(Phase 1 funcionando online).

### Sprint A — Cimientos (3‑4 días)

1. Añadir dependencias a `pubspec.yaml` y `flutter pub get`.
2. `core/sync/app_database.dart` con esquema v1 + helper de migración.
3. `core/storage/image_store.dart` y tests.
4. `core/sync/connectivity_service.dart` con stream + ping.
5. Wire en `bootstrap.dart` con providers.
6. Tests: abrir/cerrar DB, persist+sweep imágenes, ping mockeado.

### Sprint B — Outbox de check‑ins (4‑5 días)

7. `OutboxEntry`, `OutboxDao`, `OutboxService`, `OutboxDrainer`.
8. Modificar `CheckinsRemoteSource.submit` para aceptar `idempotencyKey`.
9. Cambiar `CheckinsRepositoryImpl.submitCheckin` para devolver
   `CheckinSubmissionOutcome`.
10. Hookear `AppLifecycle` + `connectivity stream` al `drain()`.
11. Riverpod: `outboxProvider`, `syncStatusProvider`, badges en AppBar.
12. Tests unitarios con `sqflite_common_ffi` (CI macOS/Linux).

### Sprint C — UI/UX (3‑4 días)

13. `CheckinResultScreen` con modo "Pendiente".
14. `UserCheckinsView` mostrando outbox + historial mezclados.
15. Pantalla **"Datos pendientes"** en Ajustes con acciones.
16. Banner Dashboard + chip "sin conexión" en `CheckinScreen`.
17. i18n (ES/EN/PT) y a11y.

### Sprint D — Backend (paralelo a B/C, ~3 días backend)

18. `Idempotency-Key` en `POST /checkin` (con tests).
19. `GET /health` y validación de tamaño/MIME.
20. Coordinar despliegue: cliente *acepta no recibir el header* (lo trata
    como envío normal) → permite envío gradual.

### Sprint E — Datos cacheados para lectura (3‑4 días)

21. `ProjectsLocalSource`, `TasksLocalSource`, `LeaderboardLocalSource`.
22. Helper `staleWhileRevalidate` y refactor de los repositorios actuales.
23. Chip "Última actualización" en Dashboard y ProjectDetail.
24. Tests de fallback cuando no hay red.

### Sprint F — Mapas offline (opcional, 2‑3 días)

25. Cache de tiles con `flutter_cache_manager`.
26. Pre‑caché on‑demand al entrar a `ProjectDetail` con red.
27. Mensajería "mapas no descargados".

### Sprint G — Background sync (opcional, 2‑3 días)

28. `workmanager` (Android): periodic 1 h o oneShot al gain network.
29. `BGTaskScheduler` (iOS) con identifier `com.rayuela.sync`.
30. QA en dispositivos reales.

### Sprint H — Telemetría, hardening, release (2‑3 días)

31. Métricas locales (contadores, último error) accesibles desde Ajustes.
32. Tests E2E con backend stub.
33. Pruebas de campo: avión‑modo, Wi‑Fi capado, app cerrada por SO,
    actualizar versión con cola llena.
34. Notas de release y comunicación a usuarios.

---

## 11. Criterios de aceptación (verificables)

| # | Criterio | Cómo verificarlo |
|---|---|---|
| AC‑1 | Sin red, el usuario puede componer y "enviar" un check‑in y ver feedback inmediato. | Test E2E con `connectivity_plus` mockeado. |
| AC‑2 | Al recuperar red, la cola se drena automáticamente sin acción del usuario. | Stream de conectividad mockeado pasa a `wifi`; outbox queda vacía en < 60 s. |
| AC‑3 | Reabrir la app con red dispara el drenado al primer `resumed`. | Test de `OutboxLifecycle` con `WidgetsBindingObserver`. |
| AC‑4 | Un check‑in nunca se duplica si el cliente reintenta tras un error de red durante el envío. | Backend devuelve la misma resource con `Idempotency-Key`; test de doble POST. |
| AC‑5 | Reiniciar el teléfono no pierde un check‑in encolado. | Smoke test manual + test sqflite con cierre/apertura. |
| AC‑6 | Logout con cola pide confirmación. | Test de widget. |
| AC‑7 | El usuario ve qué está pendiente y puede reintentar/descartar. | Pantalla "Datos pendientes" testeada. |
| AC‑8 | Lecturas offline: dashboard y detalle de proyecto muestran datos en caché si están. | Test E2E con `connectivity == none` tras un primer fetch. |
| AC‑9 | Migración v1→v2 (futura) preserva la cola. | Test que crea seeds en v1, abre en v2. |
| AC‑10 | El uso de almacenamiento de la app no excede 250 MB en uso normal. | Métrica en Ajustes + test de `sweepOrphans`. |

---

## 12. Decisiones abiertas para confirmar

1. ¿Permitimos **editar** un check‑in `dead` (cambiar foto / taskType) o
   sólo "descartar/reintentar"? Recomendación: sólo descartar/reintentar
   en la primera versión; editar es complejo y poco frecuente.
2. ¿Pre‑caché de tiles ON por defecto o opt‑in? Recomendación: opt‑in con
   toggle en Ajustes para no consumir datos a usuarios con tarifas
   limitadas.
3. ¿Background sync en la primera entrega o lo dejamos al sprint G como
   "fast follow"? Recomendación: fast follow — la cola al `resumed` cubre
   el 95 % de casos y es mucho menos riesgoso.
4. ¿`drift` o `sqflite` "a pelo"? Recomendación: `sqflite` directo. Drift
   añade DSL y generación, no compensa para 5 tablas. Si crece, migrar.

---

## Apéndice A — Esqueleto de `OutboxService.drain()`

```dart
class OutboxService {
  OutboxService(this._dao, this._remote, this._imageStore, this._connectivity,
      this._tokens);

  final _drainLock = Mutex();

  Future<void> drain() => _drainLock.protect(_drainLoop);

  Future<void> _drainLoop() async {
    if (!await _connectivity.isOnlineForReal()) return;
    final userId = await _tokens.readUserId();
    if (userId == null) return;

    var processed = 0;
    while (processed < 50) {
      final entry = await _dao.nextEligible(userId, now: DateTime.now());
      if (entry == null) break;

      await _dao.markInflight(entry.id);
      final outcome = await _attempt(entry);
      switch (outcome) {
        case _Done():
          await _imageStore.deleteForOutbox(entry.id);
          await _dao.delete(entry.id);
          processed++;
        case _Retryable(:final error):
          await _dao.bumpAttempt(entry.id, error: error,
              nextAt: DateTime.now().add(_backoff(entry.attemptCount + 1)));
          break; // sale del while: respetamos la cola
        case _Permanent(:final error):
          await _dao.markDead(entry.id, error: error);
          processed++;
        case _AlreadyExists():
          await _imageStore.deleteForOutbox(entry.id);
          await _dao.delete(entry.id);
          processed++;
      }
    }
    _statusController.add(processed > 0 ? SyncStatus.idle : SyncStatus.idle);
  }
}
```

Detalles a refinar: clasificación de errores en `_attempt`, manejo de
`inflight` huérfanos (re‑adoptar tras 10 min), métricas, etc.

---

## Apéndice B — Resumen de archivos a tocar/crear

**Nuevos**

- `lib/core/sync/app_database.dart`
- `lib/core/sync/connectivity_service.dart`
- `lib/core/sync/outbox/outbox_entry.dart`
- `lib/core/sync/outbox/outbox_dao.dart`
- `lib/core/sync/outbox/outbox_service.dart`
- `lib/core/sync/outbox/outbox_drainer.dart`
- `lib/core/sync/outbox/outbox_lifecycle.dart`
- `lib/core/sync/outbox/sync_status.dart`
- `lib/core/storage/image_store.dart`
- `lib/features/checkin/data/sources/checkins_local_source.dart`
- `lib/features/checkin/presentation/widgets/outbox_badge.dart`
- `lib/features/checkin/presentation/widgets/pending_checkin_tile.dart`
- `lib/features/checkin/presentation/providers/outbox_providers.dart`
- `lib/features/dashboard/data/sources/projects_local_source.dart`
- `lib/features/tasks/data/sources/tasks_local_source.dart`
- `lib/features/leaderboard/data/sources/leaderboard_local_source.dart`
- `lib/features/profile/presentation/screens/pending_data_screen.dart`
- (i18n ARB updates)

**Modificados**

- `pubspec.yaml` (deps).
- `lib/app/bootstrap.dart` (init DB + servicios).
- `lib/shared/providers/core_providers.dart` (nuevos providers).
- `lib/features/checkin/data/sources/checkins_remote_source.dart`
  (`Idempotency-Key`).
- `lib/features/checkin/data/repositories/checkins_repository_impl.dart`
  (outcome).
- `lib/features/checkin/presentation/screens/checkin_screen.dart`
  (manejar outcome).
- `lib/features/checkin/presentation/screens/checkin_result_screen.dart`
  (modo "Pendiente").
- `lib/features/checkin/presentation/widgets/user_checkins_view.dart`
  (mezclar pendientes).
- `lib/features/dashboard/data/repositories/projects_repository_impl.dart`
  (`staleWhileRevalidate`).
- `lib/features/tasks/data/repositories/tasks_repository_impl.dart` (idem).
- `lib/features/leaderboard/data/repositories/leaderboard_repository_impl.dart`
  (idem).

Backend (`rayuela-NodeBackend`):

- `src/module/checkin/checkin.controller.ts` (header `Idempotency-Key`).
- `src/module/checkin/checkin.service.ts` (look‑up de idempotencia).
- Nueva colección + dao `checkin_idempotency`.
- `src/module/health/health.controller.ts` (nuevo).
- DTO de error consistente.

---

## Apéndice C — Cómo se integra con la sección §3.7 del MIGRATION_PLAN

Este documento **expande** §3.7 ("Offline & sync (phase 2)") sin
contradecirlo:

- Ya describía `sqflite` + `pending_checkins` + `Idempotency-Key`.
- Aquí concretamos esquema, ciclo de vida, errores, UI, plan, riesgos y AC.
- Las dependencias añadidas (`connectivity_plus`, `path_provider`, `mutex`,
  `uuid`) son compatibles con la stack listada en §3.1.
- No requiere mover features fuera de la arquitectura clean ya en uso.
