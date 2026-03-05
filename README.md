# A:SESSION

A:SESSION is a team practice platform for a cappella workflows.
This repository contains a FastAPI backend and a Flutter mobile client for the MVP.

## What It Solves

- Arranger uploads score and MIDI assets for the team.
- Practitioner downloads score/MIDI, practices, records, and uploads takes.
- Evaluator submits third-party review and rating.

## Repository Structure

```text
.
|- app/                 FastAPI application
|- sql/                 DB initialization scripts
|- mobile/              Flutter mobile client
|- docker-compose.yml   Local dev stack
|- Dockerfile           API container build
|- requirements.txt     Python dependencies
```

## Current MVP Scope

### Backend

- Health check
- Song create/list
- Take presign upload + create/list + download URL
- Song MIDI/score download URL
- Review create/list

### Mobile

- Role-based journey entry points (Arranger / Practitioner / Evaluator)
- Session tab with mixer-oriented UI shell
- Team takes listing and per-take download URL copy
- Local recording, playback, and upload flow
- Review submission and review list

## Tech Stack

- API: FastAPI, Uvicorn
- DB: PostgreSQL 16
- Object Storage: MinIO (S3-compatible)
- Mobile: Flutter (Dart)
- Container: Docker Compose

## Local Setup

### 1. Prepare Environment File

```powershell
Copy-Item .env.example .env
```

Notes:
- On Windows, PostgreSQL host port is mapped to `5433` in `docker-compose.yml` to avoid conflicts.

### 2. Start Backend Stack

```powershell
docker compose up --build -d
```

### 3. Check Services

- API health: `http://localhost:8000/health`
- MinIO console: `http://localhost:9001`

## Run Mobile App

```powershell
cd mobile
flutter pub get
flutter run
```

### Mobile Connection Settings

Set in app settings screen:

- Android Emulator:
  - API Base URL: `http://10.0.2.2:8000`
  - MinIO Base URL: `http://10.0.2.2:9000`
- iOS Simulator:
  - API Base URL: `http://localhost:8000`
  - MinIO Base URL: `http://localhost:9000`
- Physical device:
  - Replace `localhost` with your PC LAN IP

## Environment Variables

Defined in `.env.example`:

- API: `APP_NAME`, `APP_ENV`, `APP_PORT`
- PostgreSQL: `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`
- MinIO: `MINIO_ENDPOINT`, `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`, `MINIO_SECURE`, `MINIO_BUCKET_AUDIO`, `MINIO_BUCKET_SCORE`
- CORS: `CORS_ORIGINS`

## API Endpoints (Current)

- `GET /health`
- `POST /songs`
- `GET /songs?project_id=...`
- `GET /songs/{song_id}/midi-download-url`
- `GET /songs/{song_id}/score-download-url`
- `POST /takes/presign-upload`
- `POST /takes`
- `GET /takes?song_id=...`
- `GET /takes/{take_id}/download-url`
- `POST /reviews`
- `GET /reviews?song_id=...`

## Core Workflow (Take Upload)

1. Request upload URL with `POST /takes/presign-upload`.
2. Upload audio file directly to MinIO via returned URL.
3. Register metadata with `POST /takes`.
4. Teammates fetch takes via `GET /takes` and `GET /takes/{id}/download-url`.

## Development Notes

- DB schema is initialized from `sql/init.sql`.
- Buckets are auto-created by `minio-init` service.
- Score bucket is configured for anonymous download in local dev.

## Testing

### Mobile smoke test

```powershell
cd mobile
flutter test test/widget_test.dart
```

## Roadmap Snapshot

### Must for MVP

- Stable Session workflow for song select, transport, mixer, recording, upload
- MIDI-driven notation rendering for selected track and clef
- Track-level teammate audio retrieval and download flow
- Review submission/list for evaluator flow

### Must before Release

- AuthN/AuthZ and team visibility control
- Precise track mapping across MIDI/mixer/takes
- Recording latency compensation and reliability features
- Security hardening, test expansion, monitoring and backup operations

## Related Docs

- Mobile details: `mobile/README.md`
- UX architecture: `mobile/docs/ux-architecture.md`

## License

No license file is currently included in this repository.
