# Rayuela Mobile — `docs/`

Índice de la carpeta. Si entrás nuevo al proyecto, leé en este orden:

| Doc | Para qué sirve |
|---|---|
| [`MIGRATION_PLAN.md`](./MIGRATION_PLAN.md) | Plan de migración Vue → Flutter. Contexto de negocio, scope, stack y arquitectura de la app mobile. |
| [`MIGRACION_RESUMEN.md`](./MIGRACION_RESUMEN.md) | Resumen narrativo de la migración con decisiones de diseño. |
| [`OFFLINE_SYNC_PLAN.md`](./OFFLINE_SYNC_PLAN.md) | **Plan original** del sistema offline: trade‑offs, esquema de datos, riesgos, criterios de aceptación. Es el doc de "por qué". |
| [`OFFLINE_CHECKINS.md`](./OFFLINE_CHECKINS.md) | **Walkthrough humano** del sistema offline con diagramas (Mermaid). Es el doc de "cómo funciona". Léelo antes de tocar código del flujo de check‑ins. |
| [`BACKGROUND_SYNC_SETUP.md`](./BACKGROUND_SYNC_SETUP.md) | Configuración nativa Android / iOS para `workmanager`. Pasos manuales en `Info.plist` y `AppDelegate.swift`. |
| [`CHANGELOG_OFFLINE.md`](./CHANGELOG_OFFLINE.md) | Notas de release de Phase 2: lo que se ship‑eó, qué chequear al cortar, limitaciones conocidas. |

## Ruta sugerida según rol

- **Devs nuevos**: `MIGRATION_PLAN` → `MIGRACION_RESUMEN` →
  `OFFLINE_CHECKINS`.
- **Tocar código del outbox / sync**: `OFFLINE_CHECKINS` →
  `OFFLINE_SYNC_PLAN` para los porqués.
- **Configurar build / release**: `BACKGROUND_SYNC_SETUP` y
  `CHANGELOG_OFFLINE`.
- **PMs / soporte**: `CHANGELOG_OFFLINE` y la sección "Experiencia"
  de `OFFLINE_CHECKINS`.
