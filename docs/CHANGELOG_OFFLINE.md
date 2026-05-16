# Phase 2 — Notas de release: check‑ins offline

> Resumen humano de lo que ship‑eó la migración a offline. Pegar a la
> nota de Play Store / TestFlight / News & Updates al cortar release.

---

## ✨ Lo nuevo

- **Check‑ins offline**. Si no tenés señal, la app guarda tu check‑in
  (foto, ubicación y datos) en el dispositivo y lo envía solo apenas
  vuelvas a tener red. No tenés que reintentar nada.
- **Pantalla "Pendiente"**. Cuando enviás sin red, ves una confirmación
  clara de que tu check‑in quedó guardado y se va a sincronizar
  después.
- **Banner del Dashboard + insignias en la AppBar**. Te decimos cuántos
  check‑ins están esperando enviarse y si estás offline, sincronizando
  o si algo falló.
- **"Datos pendientes" en Ajustes**. Listado de tus envíos en cola con
  acciones por fila (Reintentar ahora, Descartar) y un botón para
  reintentar todos.
- **Lecturas offline**. Proyectos suscriptos, tareas y leaderboard
  siguen funcionando sin red gracias a una caché local. Cada pantalla
  muestra "Actualizado hace X" o "Mostrando copia sin conexión" para
  que sepas qué tan vieja es la copia.
- **Mapas offline (opt‑in)**. Botón ⬇ en el mapa del proyecto que
  descarga las tiles para que el área siga visible sin red. Cap de
  ~30 MB por proyecto.
- **Sincronización en background**. La app drena la cola incluso
  cerrada, en cuanto el sistema operativo decide darle cycles
  (`WorkManager` en Android, `BGTaskScheduler` en iOS).
- **Idempotencia end‑to‑end**. Un reintento tras un timeout no genera
  un check‑in duplicado: el backend reconoce la `Idempotency-Key` y
  devuelve el original.

## 🛠 Cambios técnicos

- `POST /checkin` acepta header `Idempotency-Key`. Validación de
  imágenes (≤5 MB, MIME en `image/{jpeg,png,webp}`) con HTTP 413/400
  apropiados. Nuevo endpoint `GET /health` (sin auth) para el probe
  del cliente.
- Schema SQLite local v1 con outbox + caches por proyecto.
  Migraciones forward‑only y idempotentes.
- `staleWhileRevalidate` en repositories de proyectos / tareas /
  leaderboard.
- Tiles OSM cacheadas vía `flutter_cache_manager` con cap LRU 50 MB.
- Background sync con `workmanager 0.6.x` (v2 embedding only).

## ⚠️ Cosas a chequear al hacer el corte

- iOS: configurar `Info.plist` y `AppDelegate.swift` según
  `docs/BACKGROUND_SYNC_SETUP.md`.
- Android: `minSdkVersion ≥ 23`.
- Backend: deployar la rama con `Idempotency-Key`, `/health` y
  validación de imágenes ANTES del rollout del cliente. El cliente es
  tolerante (envía el header pero no lo requiere; trata 409 igual que
  200), pero sin backend nuevo no hay idempotencia real.

## 🧪 Cómo probar la feature antes del corte

1. Modo avión → componer check‑in → ver chip "Sin conexión".
2. Apretar Enviar → ver pantalla **Pendiente** + banner Dashboard.
3. Cerrar app → desactivar modo avión → reabrir.
4. Banner desaparece en segundos; el check‑in aparece en el historial
   sincronizado del proyecto.
5. Bonus: hacer dos check‑ins offline, verificar que el orden FIFO se
   respeta cuando vuelve la red.

## 🚫 Lo que **no** hace esta versión (out of scope)

- Edición offline de proyectos, tareas o insignias (eso vive en el
  panel admin web).
- Editar un check‑in en cola (sólo Descartar / Reintentar). Si la
  validación del backend lo rechaza, queda en `dead` y el voluntario
  decide.
- Push notifications de "tu check‑in se envió" (planeado para Phase 3).

## 🐞 Limitaciones conocidas

- iOS background tasks corren cuando el OS decide. Foreground
  triggers cubren el 95 % de casos.
- El leaderboard puede salir levemente desfasado en un replay (no
  recomputamos `gameStatus` para no doble‑contar).
- No hay todavía una vista global de "cuánto espacio usa la app". Los
  hooks (`ImageStore.totalBytesUsed`) están listos.

## 📚 Documentación de referencia

- [`docs/OFFLINE_CHECKINS.md`](./OFFLINE_CHECKINS.md) — walkthrough
  completo del sistema con diagramas.
- [`docs/OFFLINE_SYNC_PLAN.md`](./OFFLINE_SYNC_PLAN.md) — plan
  original con decisiones y trade‑offs.
- [`docs/BACKGROUND_SYNC_SETUP.md`](./BACKGROUND_SYNC_SETUP.md) —
  configuración nativa de iOS / Android.
