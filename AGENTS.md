# AGENTS.md (Mobile)

This file defines the mobile-specific standards and workflows for the Rayuela Flutter application.

## Mobile Overview

`rayuela-mobile` is a Flutter-based mobile application designed for citizen-science volunteers. It allows users to subscribe to projects, view their progress, and perform check-ins (GPS + Photo) to contribute data.

## Stack
- **Framework:** Flutter 3.27+
- **Language:** Dart 3.6+
- **State Management:** Riverpod 2.5 (No code generation)
- **Navigation:** GoRouter 14
- **Networking:** Dio 5
- **UI:** Material 3, flutter_map (OSM), image_picker

## Development Commands
- `flutter pub get` — Install dependencies
- `flutter run --dart-define-from-file=.env.development` — Run with local environment config
- `flutter test` — Run all unit and widget tests
- `flutter analyze` — Run static analysis
- `flutter format lib test` — Format code according to project standards

## Project Structure
We follow a **feature-first** architecture within `lib/features/`. Each feature is divided into layers:

- `presentation/` — Widgets, Screens, and Riverpod Providers.
- `domain/` — Pure business logic, Entities, and Abstract Repository interfaces.
- `data/` — Data Transfer Objects (DTOs), Data Sources (Remote/Local), and Repository implementations.

Shared logic lives in:
- `core/` — Infrastructure (network, storage, router, theme).
- `shared/` — Common widgets used across multiple features.

## Environment Configuration
Configuration is managed via `--dart-define-from-file`.
- Base: `.env.example`
- Development: `.env.development` (Use `10.0.2.2` for localhost on Android emulators).

## Coding Standards
- **Defensive Parsing:** Hand-write DTO `fromJson` methods to handle backend wire-shape changes gracefully without crashing the app.
- **Provider Scope:** Use `ProviderScope` at the root and prefer functional providers (`@riverpod` equivalent pattern but manual since we don't use code-gen yet).
- **Lints:** Follow `flutter_lints` as defined in `analysis_options.yaml`.

## Issue Tracking
- All issues are tracked in the GitHub Project: [Rayuela Workspace Board](https://github.com/orgs/Rayuela-v2/projects/1).
- **CRITICAL:** Note that the Project Board view is filtered to display issues from the `Rayuela-v2/rayuela-NodeBackend` repository. Therefore, even for Mobile tasks, always create the issue in `Rayuela-v2/rayuela-NodeBackend` and link it to the project board.
