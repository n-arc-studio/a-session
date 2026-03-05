# A:SESSION Backend MVP (Docker)

Flutter + WebView構成を前提にした、アカペラ練習サービスのMVPバックエンドです。

## 構成

- `api`: FastAPI
- `postgres`: メタデータ保存
- `minio`: 音声/MIDI/MusicXML保存 (S3互換)
- `minio-init`: バケット初期化

## セットアップ

1. 環境変数を作成

```powershell
Copy-Item .env.example .env
```

2. 起動

```powershell
docker compose up --build
```

3. 動作確認

- API Health: `http://localhost:8000/health`
- MinIO Console: `http://localhost:9001`

## MVP API

- `GET /health`
- `POST /songs`
- `GET /songs?project_id=...`
- `POST /takes/presign-upload`
- `POST /takes`
- `GET /takes?song_id=...`
- `GET /takes/{take_id}/download-url`

## 使い方フロー（録音アップロード）

1. `POST /takes/presign-upload` で `upload_url` を取得
2. Flutterから `PUT upload_url` で音声ファイルを直接アップロード
3. `POST /takes` で `audio_object_key` と同期情報（`offset_ms` など）を登録
4. メンバーは `GET /takes` で一覧取得し、`GET /takes/{id}/download-url` で再生/ダウンロード

## cURL 例

### Health

```bash
curl http://localhost:8000/health
```

### Song作成

```bash
curl -X POST http://localhost:8000/songs \
  -H "Content-Type: application/json" \
  -d '{
    "project_id":"00000000-0000-0000-0000-000000000001",
    "title":"Amazing Grace",
    "midi_object_key":"scores/amazing_grace.mid",
    "musicxml_object_key":"scores/amazing_grace.musicxml",
    "bpm":88,
    "created_by":"00000000-0000-0000-0000-000000000001"
  }'
```

### Presign Upload URL発行

```bash
curl -X POST http://localhost:8000/takes/presign-upload \
  -H "Content-Type: application/json" \
  -d '{
    "song_id":"<song-id>",
    "user_id":"<user-id>",
    "filename":"take1.webm",
    "content_type":"audio/webm"
  }'
```

## 次の実装候補

- 認証/JWT (Supabase Auth or custom)
- MIDI->MusicXML変換API (FastAPI + music21)
- 権限制御（プロジェクトメンバーのみ参照可能）
- ピッチ判定・ガイド評価
