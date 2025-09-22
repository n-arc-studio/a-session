# a-session
  
## プロジェクト概要
a-sessionは、チームでのアカペラ練習をもっと簡単にできるサービスです。メンバー管理、練習スケジュール共有、音源アップロードなど、アカペラチームの活動をサポートします。

## 機能
- 楽譜のアップロード
- 楽譜のダウンロード
- 楽譜の閲覧
- チームでの楽譜共有
- 楽譜音源(MIDI)のアップロード
- 楽譜音源(MIDI)のダウンロード
- 楽譜音源(MIDI)の再生
- 楽譜音源(MIDI)のアシスト演奏
- 楽譜音源(MIDI)のアシスト演奏しながらのリアルタイムレコーディング（録音）
- 楽譜音源(MIDI)のミキサー機能（トラック別ボリューム調整）
- 楽譜音源(MIDI)のミキサー機能（MIDIとレコーディングデータの同時再生）
- 楽譜音源(MIDI)の譜面表示
- レコーディングデータのアップロード
- レコーディングデータのダウンロード
- メトロノーム機能
- メンバー管理機能
- 練習スケジュール管理

## 技術構成
- バックエンド: ASP.NET Web API
- フロントエンド: Flutter

## セットアップ手順

### バックエンド (ASP.NET)
1. PowerShellで以下を実行:
	```pwsh
	cd backend
	dotnet restore
	dotnet run
	```
2. APIは http://localhost:5000 で起動します。

### フロントエンド (Flutter)
1. PowerShellで以下を実行:
	```pwsh
	cd frontend
	flutter pub get
	flutter run
	```
2. アプリはエミュレータまたはWebで起動します。

## ディレクトリ構成
- backend/ : ASP.NET Web API プロジェクト
- frontend/ : Flutter プロジェクト