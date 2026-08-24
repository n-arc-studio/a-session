# MVP UI/UX Implementation Plan

Last updated: 2026-08-24
Status: Ready to implement
Scope: Mobile UI/UX + minimum API extension
Priority: Improve performance practice experience first
Target horizon: 3-6 weeks

## Goal

Improve the core flow for practice sessions with fewer mistakes and faster completion:
Select -> Practice -> Record -> Review -> Share

## In Scope

- Session tab usability improvements in Flutter
- Error and loading feedback improvements
- Song selector discoverability improvements
- Minimum API additions needed by UI
- Backward-compatible API changes only

## Out of Scope

- Full authentication and authorization implementation
- Large-scale architecture migration
- Desktop-only feature expansion

## Phases

## Phase 0: Baseline

1. Convert UX priorities from mobile docs into acceptance checklist.
2. Measure current flow pain points in 5 tabs.
3. Freeze baseline behavior for regression checks.

## Phase 1: Session UX hardening

1. Add visible loading state during API operations.
2. Refine recording strip flow: Record -> Stop -> Play -> Upload.
3. Split large HomeScreen responsibilities into smaller UI blocks:
   - Transport controls
   - Recording controls
   - Mixer panel
   - Take list panel

## Phase 2: Playback sync and start position

1. Define start position behavior and state transitions.
2. Add playback position awareness in UI.
3. Define offset apply order for playback and recording review.

## Phase 3: Minimum API extension

1. Add songs list query options with compatibility:
   - limit
   - offset
   - sort
2. Add song search endpoint for selector UX.
3. Standardize error response shape for user-facing message mapping.

## Phase 4: Verification

1. API compatibility check with existing clients.
2. Boundary tests for songs/reviews/takes.
3. Widget-level checks for recording and transport flows.
4. Manual E2E validation for the full user journey.

## Acceptance Criteria

1. Users can complete Select -> Practice -> Record -> Review -> Share without confusion.
2. Loading and failure states are always visible and understandable.
3. Song selection stays usable as data volume grows.
4. Existing API client behavior remains valid.

## Primary Work Files

- mobile/lib/screens/home_screen.dart
- mobile/lib/services/api_service.dart
- app/presentation/routers/songs.py
- app/application/services/impl.py
- app/infrastructure/repositories/postgres.py
- tests/test_songs.py
- tests/test_takes.py
- tests/test_reviews.py

## Change Log

- 2026-08-24: Initial implementation plan created from design review findings.
