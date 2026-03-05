# A:SESSION Mobile MVP

Flutterクライアントです。以下をMVPとして実装しています。

- バックエンドAPI疎通確認
- 曲一覧作成 (`/songs`)
- MusicXML譜面をWebView表示 (OpenSheetMusicDisplay)
- 端末録音
- Presigned URLアップロード (`/takes/presign-upload`)
- Take登録 (`/takes`)
- チームTake一覧と同時再生

## 前提

- 先にルートでDockerバックエンドを起動

```powershell
docker compose up -d
```

## 実行

```powershell
cd mobile
flutter pub get
flutter run
```

## 接続設定

アプリ上部の `API Base URL` と `MinIO Base URL` を環境に合わせて設定します。

- Android Emulator: `http://10.0.2.2:8000`, `http://10.0.2.2:9000`
- iOS Simulator: `http://localhost:8000`, `http://localhost:9000`
- 実機: PCのLAN IPに置き換え

## メモ

- 譜面表示は `songs.musicxml_object_key` を使って `MinIO/score-bucket` から読み込みます。
- リアルタイムトレースとMIDI再生同期は次フェーズで追加する想定です。
