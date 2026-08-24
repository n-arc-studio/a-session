# MVP Deferred Design Log

Last updated: 2026-08-25
Status: In progress

## Why deferred

Design and priority were finalized first. Implementation starts in the next execution phase.

## Pending backlog (MVP minimum)

1. [x] Session loading visibility (progress + interaction lock + completion feedback)
2. [x] Error category messages (network/input/server)
3. [x] Upload retry path for failed operations
4. [x] Song selection discovery (client filter short-term, API search in parallel)
5. [x] Songs list API query options (limit/offset/sort) with compatibility
6. [ ] Minimum access control policy before full auth

## Definition of Done

1. End-to-end flow works on real device without dropout.
2. Major failure paths show actionable next steps.
3. Song selector remains usable with larger datasets.
4. Existing API clients remain compatible.

## Resume Procedure

1. Start from pending backlog item 1.
2. Complete UI items first (1-4), then API items (5-6).
3. Run verification relevant to each completed item.
4. Mark completed items with date and evidence.

## Update Rules

1. Every update must include date, reason, and impact scope.
2. Keep unresolved items with one-line next action.
3. Keep README as index only, not the full plan body.

## Progress Log

- 2026-08-24: Deferred log created.
- 2026-08-24: Started implementation. Added API timeout settings, user-facing error mapping, and visible loading progress indicator in app bar. Impact scope: Flutter UI and mobile API client.
- 2026-08-24: Added upload retry path (backlog item 3). `_runGuarded` now accepts an optional `onError` callback; failed uploads surface a snackbar with a Retry action that re-invokes the last upload using the preserved recording path. Impact scope: Flutter UI only.
- 2026-08-24: Added client-side song filter (backlog item 4). Library tab now has a search field that filters songs by title; shows an empty state when nothing matches. Short-term solution while API search is built in parallel. Impact scope: Flutter UI only.
- 2026-08-25: Added query options to GET /songs (backlog item 5). Router accepts optional `limit` (1–200), `offset` (≥0), `sort_by`, and `sort_order` params; options flow through SongServiceImpl into PostgresSongRepository.list_by_project. Sort column is validated against an allowlist (`created_at`, `title`) to prevent SQL injection; invalid values fall back to the default sort. `limit=None` returns all rows, preserving backward compatibility with the mobile ApiService.listSongs (which sends only `project_id`). Validation rejects out-of-range limit and malformed sort_order with 422. Impact scope: backend API layer (router → service → repository). Verified with pytest: 18 passed (added 6 new tests for limit/offset/sort, allowlist fallback, and validation).
