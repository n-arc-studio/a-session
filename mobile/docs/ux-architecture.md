# A:SESSION Frontend UX Architecture

## Project Overview
A:SESSION は、小規模チームでの協働練習と録音に特化した音楽アプリケーションです。
譜面共有からリハーサル、テイク録音、相互レビュー、成果共有までを、一連の体験として進められる設計になっています。
フロントエンド UX では、重要操作を常に見える位置に保ち、セッション中の画面遷移を最小化し、役割ごとの行動導線を明確にすることを重視します。
本ドキュメントは、その体験をデスクトップとモバイルの両方で実現するための情報設計、操作優先度、UI 構成ルールを定義します。

## Goal
- Keep singer focus in one continuous flow: `Select -> Practice -> Record -> Review -> Share`.
- Minimize context switching between screens during recording sessions.
- Provide explicit role-based journeys: `Arranger`, `Practitioner`, `Evaluator`.

## Information Architecture
- `Home`: Daily start point, quick resume actions.
- `Session`: Score + controls + recording actions in one place.
- `Review`: Sync offset adjustment and retake/share decisions.
- `Team`: Multi-take selection and simultaneous playback.
- `Library`: Song creation and song selection.

## Role-based Journeys
- `Arranger`
  - Upload score to teammates.
  - Upload MIDI to teammates.
  - Trigger: Home role switcher -> Arranger -> `Register score/MIDI`.
- `Practitioner`
  - Download score and MIDI.
  - Play and practice by track.
  - Record while guide MIDI is active.
  - Download teammate takes by track.
  - Upload own take by track.
  - Trigger: Home role switcher -> Practitioner -> `Go to practice session`.
- `Evaluator`
  - Submit third-party review/rating.
  - Browse submitted reviews by song.
  - Trigger: Home role switcher -> Evaluator -> `Write evaluation`.

## UX Priorities
1. Start practice in 3 taps or less.
2. Keep primary actions fixed: `Record`, `Stop`, `Upload`.
3. Expose offset correction as a simple slider.
4. Ensure clear state communication (recording on/off, selected song, last take).

## UI Composition Rules
- Settings moved to a bottom sheet to reduce top-level visual noise.
- Song creation moved to modal sheet to avoid a crowded main screen.
- Session screen uses responsive split layout:
  - Wide: score pane + control pane side by side.
  - Narrow: stacked score and control panes.

## Current MVP Mapping
- `Home`: Session resume and task checklist.
- `Session`: Song selector, score WebView, count-in toggle, guide volume, record controls.
- `Review`: Last take status + offset slider + save/share action.
- `Team`: Take list with checkbox selection and synced playback.
- `Library`: Song list and song selection for the active session.

## Added UX Entry Points
1. Role switcher on Home for Arranger/Practitioner/Evaluator.
2. Session quick actions for score/MIDI download URL copy.
3. Team per-track download URL action.
4. Review tab section for third-party rating/comment submit + review list.

## Session Tab Proposal (Most Understandable)

### 1) One-screen Information Hierarchy
- Top bar (always visible): `Song selector` + `Start position` + `Global transport`.
- Middle left: `MIDI staff view` (treble/bass switch, selected track rendering from MIDI only).
- Middle right: `Mixer` (track ON/OFF, volume, percussion enable/disable, track count 4-8).
- Bottom panel: `Practice audio` (teammate track download) + `My recording` (record, playback, upload).

Why this is easiest:
- Users can do selection, playback, score reading, mixing, recording without leaving Session.
- Global controls never move, so mistakes during practice are reduced.

### 2) Session Components by Requirement

#### A. Mixer
- Track count control: default `6`, minimum `4`, maximum `8`.
- One fixed percussion lane:
  - Label: `Percussion (MIDI Ch.10)`.
  - Cannot be removed.
  - Has `Enable/Disable` toggle.
- For each track lane:
  - `ON/OFF` switch (mute/unmute).
  - `Volume` slider (0-100).
  - `Target voice` label (Lead/Tenor/Bass etc, editable in metadata).
- Safe preset buttons:
  - `Solo Selected`.
  - `Reset Mix`.

#### B. Staff Notation (MIDI only)
- Source: parsed MIDI events (no MusicXML dependency).
- View mode:
  - `Treble` or `Bass` clef selector.
  - `Track selector` (which track is rendered).
- Playback sync:
  - Current beat cursor overlay.
  - Auto-scroll on/off.

#### C. Song Selection
- Data source: `songs` that are shared to teammates in current project.
- Selector UX:
  - Searchable dropdown.
  - Filter chips: `All`, `My team`, `Recently used`.
- On change:
  - Rehydrate mixer defaults.
  - Load MIDI and teammate takes for that song.

#### D. Global Transport
- Always visible controls:
  - `Play`, `Pause`, `Stop`.
  - Optional: tempo indicator and current position.
- State feedback:
  - Badge: `Playing`, `Paused`, `Stopped`.

#### E. Start Position
- Entry options:
  - Bar/beat input (e.g. `17:1`).
  - Timeline scrubber.
  - Quick markers (`A`, `B`, `Chorus`).
- Action:
  - `Set Start` applies to next play and recording count-in.

#### F. Track Audio Download (teammates)
- In bottom panel: list teammate takes grouped by track.
- Row actions:
  - `Preview`.
  - `Download`.
  - `Use in mix` toggle.

#### G. My Audio Record/Playback/Upload
- Single strip with explicit steps:
  - `Record` -> `Stop` -> `Play` -> `Upload`.
- Show:
  - Duration.
  - Offset.
  - Upload progress and retry.

### 3) Desktop and Mobile Layout
- Desktop (wide >= 980):
  - Left 65%: staff.
  - Right 35%: mixer.
  - Bottom full-width: transport + teammate audio + my recording.
- Mobile:
  - Sticky top: song selector + transport.
  - Tabs inside Session body:
    - `Score`
    - `Mixer`
    - `Audio`
  - Sticky bottom: Record/Stop/Upload quick bar.

### 4) Recommended Interaction Sequence
1. Select shared song.
2. Set start position.
3. Adjust mixer (track ON/OFF + volume + percussion enable).
4. Choose notation track and clef.
5. Play/Pause/Stop for practice.
6. Record my take while MIDI runs.
7. Playback and upload my take.
8. Download teammate track audio if needed.

### 5) Backend/Domain Requirements for This UX
- Shared song list endpoint with teammate visibility.
- MIDI parse endpoint or client parser output for per-track notation rendering.
- Track metadata schema (`track_index`, `is_percussion`, `permission_enabled`, `volume`).
- Start position in playback API (`bar`, `beat`, or `tick`).
- Teammate take list grouped by track and per-track download URL.

### 6) Clarification Notes
- `Permission` in mixer is treated as track-level `Enable/Disable` (including percussion lane).
- `MIDI ch10 percussion fixed` means one immutable lane exists even when track count changes.
