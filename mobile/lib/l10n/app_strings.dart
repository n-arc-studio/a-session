import 'package:flutter/widgets.dart';

class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('ja'), Locale('en')];

  static AppStrings of(BuildContext context) {
    final strings = Localizations.of<AppStrings>(context, AppStrings);
    return strings ?? AppStrings(const Locale('en'));
  }

  static const LocalizationsDelegate<AppStrings> delegate =
      _AppStringsDelegate();

  bool get _isJa => locale.languageCode == 'ja';

  String tr(String ja, String en) => _isJa ? ja : en;

    String get appTitle => tr('A:SESSION Studio', 'A:SESSION Studio');
  String get settings => tr('接続設定', 'Connection Settings');
  String get apiBaseUrl => tr('API Base URL', 'API Base URL');
  String get minioBaseUrl => tr('MinIO Base URL', 'MinIO Base URL');
  String get scoreBucket => tr('Score Bucket', 'Score Bucket');
  String get projectId => tr('Project ID', 'Project ID');
  String get userId => tr('User ID', 'User ID');
  String get apiCheck => tr('API確認', 'API Check');
  String get apiOk => tr('API接続OK', 'API connection OK');

  String get songTitle => tr('曲名', 'Song Title');
  String get midiKey => tr('MIDI Object Key', 'MIDI Object Key');
  String get musicXmlKey => tr('MusicXML Object Key', 'MusicXML Object Key');
  String get bpm => 'BPM';
  String get createSong => tr('曲を作成', 'Create Song');
  String get songCreated => tr('曲を作成しました', 'Song created');

  String get home => tr('ホーム', 'Home');
  String get session => tr('練習', 'Practice');
  String get review => tr('レビュー', 'Review');
  String get team => tr('チーム', 'Team');
  String get library => tr('ライブラリ', 'Library');

  String get practiceFlow => tr('今日の練習フロー', 'Today\'s Practice Flow');
  String get selectSongFirst =>
      tr('まず曲を選ぶと練習を開始できます。', 'Select a song to start practicing.');
  String currentSong(String title) =>
      tr('選択中の曲: $title', 'Selected song: $title');
  String get resumeSession => tr('練習をはじめる', 'Start Practice');
  String get openLibrary => tr('ライブラリを開く', 'Open Library');
  String get refreshSongs => tr('曲を同期', 'Sync Songs');

  String get step1 => tr('曲を選ぶ', 'Select Song');
  String get step2 => tr('練習して録音', 'Practice and Record');
  String get step3 => tr('確認して共有', 'Review and Share');

  String get arranger => tr('アレンジャー', 'Arranger');
  String get practitioner => tr('練習者', 'Practitioner');
  String get evaluator => tr('評価者', 'Evaluator');
    String get openTeam => tr('チームを見る', 'Open Team');

  String get arrangerStep1 =>
      tr('楽譜を登録してチームに共有', 'Register score and share with teammates');
  String get arrangerStep2 =>
      tr('MIDIを登録してチームに共有', 'Register MIDI and share with teammates');
  String get arrangerStep3 =>
      tr('曲を選択して練習開始を案内', 'Select a song and guide team to start practice');
  String get arrangerPrimaryAction => tr('楽譜/MIDIを登録する', 'Register score/MIDI');

  String get practitionerStep1 =>
      tr('楽譜・MIDIをダウンロード', 'Download score and MIDI');
  String get practitionerStep2 =>
      tr('MIDIを流しながら録音', 'Record while playing MIDI');
  String get practitionerStep3 =>
      tr('トラック別に共有・取得', 'Share and fetch takes by track');
  String get practitionerPrimaryAction =>
      tr('練習画面へ', 'Go to Practice');

  String get evaluatorStep1 => tr('対象曲を選択', 'Select target song');
  String get evaluatorStep2 =>
      tr('第三者レビューと評価を記入', 'Write third-party review and rating');
  String get evaluatorStep3 => tr('評価結果を共有', 'Share review result');
    String get evaluatorPrimaryAction => tr('レビューを書く', 'Write Review');

  String get selectMusicXmlSong => tr(
    'ライブラリでMusicXML付きの曲を選択してください。',
    'Select a MusicXML song from Library.',
  );
  String bpmLabel(int bpm) => 'BPM $bpm';
  String get song => tr('曲', 'Song');
  String get teamSharedSong => tr('チーム公開曲', 'Team Shared Song');
    String get refresh => tr('再読み込み', 'Reload');
    String get newSong => tr('曲を追加', 'Add Song');
  String get countIn => tr('3拍カウントイン', 'Count-in 3 beats');
  String guideVolumeLabel(int percent) =>
      tr('ガイド音量 $percent%', 'Guide Volume $percent%');
  String startPositionLabel(String sec) =>
      tr('開始位置: ${sec}s', 'Start position: ${sec}s');
  String get play => tr('再生', 'Play');
  String get pause => tr('一時停止', 'Pause');
  String transportStateLabel(String state) => tr('状態: $state', 'State: $state');
  String get trebleClef => tr('ト音', 'Treble');
  String get bassClef => tr('ヘ音', 'Bass');
  String get midiStaffHint =>
      tr('MIDIをもとに指定トラックを五線譜表示', 'Render selected MIDI track on staff');
  String get mixer => tr('ミキサー', 'Mixer');
  String trackCountLabel(int count) =>
      tr('トラック数: $count', 'Track count: $count');
  String get soloSelected => tr('選択トラックをソロ', 'Solo Selected');
  String get resetMix => tr('ミックスを初期化', 'Reset Mix');
  String trackOnOff(bool on) => tr(on ? 'ON' : 'OFF', on ? 'ON' : 'OFF');
  String get permission => tr('パーミッション', 'Permission');
  String trackVolumeLabel(int percent) =>
      tr('音量: $percent%', 'Volume: $percent%');
  String get teammateTrackDownloads =>
      tr('チームの録音（トラック別）', 'Team Takes by Track');
  String teammateTakeTitle(int trackNo, String userId) =>
      tr('Track $trackNo - $userId', 'Track $trackNo - $userId');
    String get myRecording => tr('自分の録音', 'My Recording');
  String trackLabel(int index) => tr('Track $index', 'Track $index');
  String get percussionTrack =>
      tr('Percussion (MIDI Ch.10)', 'Percussion (MIDI Ch.10)');
  String get downloadScore => tr('楽譜をダウンロード', 'Download Score');
  String get downloadMidi => tr('MIDIをダウンロード', 'Download MIDI');

  String get record => tr('録音', 'Record');
  String get stop => tr('停止', 'Stop');
  String get upload => tr('アップロード', 'Upload');
  String recordingStatus(bool on) =>
      tr('録音: ${on ? 'ON' : 'OFF'}', 'Recording: ${on ? 'ON' : 'OFF'}');
  String durationMs(int ms) => tr('長さ: $ms ms', 'Duration: $ms ms');

  String get takeReview => tr('テイク確認', 'Take Review');
  String lastTake(String path) => tr('最新テイク: $path', 'Last take: $path');
  String offsetMs(int ms) => tr('オフセット: $ms ms', 'Offset: $ms ms');
    String get saveAndShare => tr('テイクを保存して共有', 'Save and Share Take');
    String get rerecord => tr('もう一度録音', 'Record Again');
  String get retry => tr('再試行', 'Retry');

    String get loadTeamTakes => tr('チームの録音を読み込む', 'Load Team Takes');
    String get playSelectedTogether => tr('選択した録音を重ねて再生', 'Play Selected Together');
  String get downloadTake => tr('このトラックをダウンロード', 'Download this track');
    String get loadSongs => tr('曲を読み込む', 'Load Songs');
    String get searchSongs => tr('曲名で検索', 'Search songs');
  String get noSongsMatch => tr('一致する曲がありません。', 'No matching songs.');

  String get thirdPartyReview => tr('第三者レビュー', 'Third-party Review');
  String ratingLabel(int rating) =>
      tr('評価: $rating / 5', 'Rating: $rating / 5');
  String get reviewComment => tr('レビューコメント', 'Review Comment');
    String get submitReview => tr('レビューを投稿', 'Submit Review');
    String get loadReviews => tr('みんなのレビューを見る', 'Load Reviews');
  String get reviewList => tr('レビュー一覧', 'Review List');
  String get noReviewsYet => tr('レビューはまだありません。', 'No reviews yet.');
  String reviewer(String reviewerId) =>
      tr('評価者: $reviewerId', 'Reviewer: $reviewerId');
  String countLabel(int count) => tr('件数: $count', 'Count: $count');

    String selected(String title) => tr('選択中: $title', 'Selected: $title');

  String get errorPrefix => tr('エラー', 'Error');
  String get errorNetwork =>
      tr('ネットワーク接続を確認してください。', 'Please check your network connection.');
  String get errorTimeout => tr(
    '通信がタイムアウトしました。しばらくして再試行してください。',
    'The request timed out. Please try again.',
  );
  String get errorRequest =>
      tr('入力内容を確認してください。', 'Please check your input and try again.');
  String get errorUnauthorized => tr(
    'この操作を実行する権限がありません。',
    'You do not have permission to perform this action.',
  );
  String get errorNotFound =>
      tr('対象データが見つかりませんでした。', 'The requested resource was not found.');
  String get errorServer => tr(
    'サーバーで問題が発生しました。しばらくして再試行してください。',
    'The server encountered an error. Please try again later.',
  );
  String get errorUnknown =>
      tr('予期しないエラーが発生しました。', 'An unexpected error occurred.');
  String get requireProjectId =>
      tr('Project ID は必須です。', 'Project ID is required.');
  String get requireSongFields => tr(
    'Project ID / 曲名 / MIDI key は必須です。',
    'Project ID, title, MIDI key are required.',
  );
  String get micRequired =>
      tr('マイク権限が必要です。', 'Microphone permission is required.');
  String get requireSongUserRecording =>
      tr('曲・ユーザー・録音ファイルが必要です。', 'Song, User and recording are required.');
  String fileNotFound(String path) =>
      tr('録音ファイルが見つかりません: $path', 'Recording file does not exist: $path');
  String get takeUploaded =>
      tr('テイクをアップロードしました。', 'Take uploaded and registered.');
  String get copiedScoreDownloadUrl =>
      tr('楽譜ダウンロードURLをコピーしました。', 'Copied score download URL.');
  String get copiedMidiDownloadUrl =>
      tr('MIDIダウンロードURLをコピーしました。', 'Copied MIDI download URL.');
  String get copiedTakeDownloadUrl =>
      tr('トラックダウンロードURLをコピーしました。', 'Copied take download URL.');
  String get requireSongAndReviewer =>
      tr('曲と評価者IDが必要です。', 'Song and reviewer ID are required.');
  String get reviewSubmitted => tr('レビューを送信しました。', 'Review submitted.');
  String get selectSongFirstForTeam =>
      tr('曲が未選択です。ライブラリから1曲選んでください。', 'Select a song in Library first.');
  String get selectAtLeastOneTake =>
      tr('少なくとも1つ選択してください。', 'Select at least one take.');
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => AppStrings.supportedLocales.any(
    (item) => item.languageCode == locale.languageCode,
  );

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
