import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../models/review.dart';
import '../models/song.dart';
import '../models/take.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../services/recorder_service.dart';

enum UserRole { arranger, practitioner, evaluator }

enum SessionTransportState { stopped, playing, paused }

class MixerTrack {
  MixerTrack({
    required this.id,
    required this.label,
    required this.isPercussion,
    this.isOn = true,
    this.permissionEnabled = true,
    this.volume = 0.8,
  });

  final int id;
  final String label;
  final bool isPercussion;
  bool isOn;
  bool permissionEnabled;
  double volume;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _apiBaseUrlController = TextEditingController(
    text: 'http://10.0.2.2:8000',
  );
  final TextEditingController _minioBaseUrlController = TextEditingController(
    text: 'http://10.0.2.2:9000',
  );
  final TextEditingController _scoreBucketController = TextEditingController(
    text: 'a-session-score',
  );
  final TextEditingController _projectIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _songTitleController = TextEditingController();
  final TextEditingController _songMidiKeyController = TextEditingController();
  final TextEditingController _songMusicXmlKeyController =
      TextEditingController();
  final TextEditingController _songBpmController = TextEditingController();
  final TextEditingController _offsetMsController = TextEditingController(
    text: '0',
  );
  final TextEditingController _reviewCommentController =
      TextEditingController();
  final TextEditingController _songSearchController = TextEditingController();

  late ApiService _api;
  final RecorderService _recorder = RecorderService();
  final Stopwatch _recordStopwatch = Stopwatch();

  List<Song> _songs = const [];
  List<Take> _takes = const [];
  List<Review> _reviews = const [];
  List<MixerTrack> _mixerTracks = <MixerTrack>[];
  final Set<String> _selectedTakeIds = <String>{};
  final List<AudioPlayer> _players = <AudioPlayer>[];

  Song? _selectedSong;
  String? _lastRecordPath;

  int _tabIndex = 0;
  UserRole _selectedRole = UserRole.practitioner;
  int _reviewRating = 4;
  int _sessionTrackCount = 6;
  int _selectedStaffTrackId = 1;
  bool _showTrebleClef = true;
  double _startPositionSeconds = 0;
  SessionTransportState _transportState = SessionTransportState.stopped;
  bool _didInitMixer = false;
  bool _isBusy = false;
  bool _isRecording = false;
  String _songSearchQuery = '';

  AppStrings get _s => AppStrings.of(context);

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: _apiBaseUrlController.text.trim());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitMixer) {
      return;
    }
    _mixerTracks = _buildMixerTracks(_sessionTrackCount);
    _didInitMixer = true;
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _minioBaseUrlController.dispose();
    _scoreBucketController.dispose();
    _projectIdController.dispose();
    _userIdController.dispose();
    _songTitleController.dispose();
    _songMidiKeyController.dispose();
    _songMusicXmlKeyController.dispose();
    _songBpmController.dispose();
    _offsetMsController.dispose();
    _reviewCommentController.dispose();
    _songSearchController.dispose();
    for (final player in _players) {
      player.dispose();
    }
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _runGuarded(
    Future<void> Function() action, {
    void Function(Object error)? onError,
  }) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    try {
      _api.updateBaseUrl(_apiBaseUrlController.text.trim());
      await action();
    } catch (error) {
      if (onError != null) {
        onError(error);
      } else {
        _showMessage('${_s.errorPrefix}: ${_toUserMessage(error)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  String _toUserMessage(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return _s.errorTimeout;
        case DioExceptionType.connectionError:
          return _s.errorNetwork;
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 400) {
            return _s.errorRequest;
          }
          if (statusCode == 401 || statusCode == 403) {
            return _s.errorUnauthorized;
          }
          if (statusCode == 404) {
            return _s.errorNotFound;
          }
          if (statusCode != null && statusCode >= 500) {
            return _s.errorServer;
          }
          return _s.errorUnknown;
        case DioExceptionType.cancel:
        case DioExceptionType.badCertificate:
        case DioExceptionType.unknown:
          if (error.error is SocketException) {
            return _s.errorNetwork;
          }
          return _s.errorUnknown;
      }
    }

    if (error is SocketException) {
      return _s.errorNetwork;
    }

    if (error is FileSystemException) {
      return _s.fileNotFound(error.path ?? '-');
    }

    return _s.errorUnknown;
  }

  Future<void> _healthCheck() async {
    await _runGuarded(() async {
      await _api.healthCheck();
      _showMessage(_s.apiOk);
    });
  }

  Future<void> _loadSongs() async {
    final projectId = _projectIdController.text.trim();
    if (projectId.isEmpty) {
      _showMessage(_s.requireProjectId);
      return;
    }

    await _runGuarded(() async {
      final songs = await _api.listSongs(projectId);
      setState(() {
        _songs = songs;
        if (_selectedSong != null) {
          final existing = songs
              .where((song) => song.id == _selectedSong!.id)
              .toList();
          _selectedSong = existing.isEmpty ? null : existing.first;
        }
      });
    });
  }

  Future<void> _createSong() async {
    final projectId = _projectIdController.text.trim();
    final title = _songTitleController.text.trim();
    final midiKey = _songMidiKeyController.text.trim();
    final musicXmlKey = _songMusicXmlKeyController.text.trim();
    final userId = _userIdController.text.trim();
    final bpm = int.tryParse(_songBpmController.text.trim());

    if (projectId.isEmpty || title.isEmpty || midiKey.isEmpty) {
      _showMessage(_s.requireSongFields);
      return;
    }

    await _runGuarded(() async {
      final song = await _api.createSong(
        projectId: projectId,
        title: title,
        midiObjectKey: midiKey,
        musicxmlObjectKey: musicXmlKey.isEmpty ? null : musicXmlKey,
        bpm: bpm,
        createdBy: userId.isEmpty ? null : userId,
      );
      setState(() {
        _songs = [..._songs, song];
        _selectedSong = song;
      });
      _showMessage('${_s.songCreated}: ${song.title}');
    });
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showMessage(_s.micRequired);
      return;
    }

    final tempDir = Directory.systemTemp.path;
    final path =
        '$tempDir/asession_take_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _runGuarded(() async {
      await _recorder.start(path);
      _recordStopwatch
        ..reset()
        ..start();
      setState(() {
        _isRecording = true;
        _lastRecordPath = null;
      });
    });
  }

  Future<void> _stopRecording() async {
    await _runGuarded(() async {
      final path = await _recorder.stop();
      _recordStopwatch.stop();
      setState(() {
        _isRecording = false;
        _lastRecordPath = path;
      });
    });
  }

  Future<void> _uploadLastTake() async {
    final songId = _selectedSong?.id ?? '';
    final userId = _userIdController.text.trim();
    final offsetMs = int.tryParse(_offsetMsController.text.trim()) ?? 0;
    final path = _lastRecordPath;

    if (songId.isEmpty || userId.isEmpty || path == null || path.isEmpty) {
      _showMessage(_s.requireSongUserRecording);
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      _showMessage(_s.fileNotFound(path));
      return;
    }

    final fileName = path.split(RegExp(r'[\\/]')).last;

    await _runGuarded(() async {
      final presigned = await _api.presignTakeUpload(
        songId: songId,
        userId: userId,
        fileName: fileName,
        contentType: 'audio/mp4',
      );

      await _api.uploadToPresignedUrl(
        uploadUrl: presigned.uploadUrl,
        filePath: path,
        contentType: 'audio/mp4',
      );

      await _api.createTake(
        songId: songId,
        userId: userId,
        audioObjectKey: presigned.objectKey,
        durationMs: _recordStopwatch.elapsedMilliseconds,
        offsetMs: offsetMs,
        sampleRate: 44100,
      );

      _showMessage(_s.takeUploaded);
    }, onError: (error) => _showUploadRetry(error));
  }

  void _showUploadRetry(Object error) {
    if (!mounted) {
      return;
    }
    final detail = _toUserMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_s.errorPrefix}: $detail'),
        action: SnackBarAction(
          label: _s.retry,
          onPressed: () {
            ScaffoldMessenger.of(context).clearSnackBars();
            _uploadLastTake();
          },
        ),
      ),
    );
  }

  Future<void> _loadTakes() async {
    final songId = _selectedSong?.id ?? '';
    if (songId.isEmpty) {
      _showMessage(_s.selectSongFirstForTeam);
      return;
    }

    await _runGuarded(() async {
      final takes = await _api.listTakes(songId);
      setState(() {
        _takes = takes;
        _selectedTakeIds
          ..clear()
          ..addAll(takes.map((take) => take.id));
      });
    });
  }

  Future<void> _playSelectedTakes() async {
    final selected = _takes
        .where((take) => _selectedTakeIds.contains(take.id))
        .toList();
    if (selected.isEmpty) {
      _showMessage(_s.selectAtLeastOneTake);
      return;
    }

    await _runGuarded(() async {
      await _stopAllPlayers();

      for (final take in selected) {
        final url = await _api.getTakeDownloadUrl(take.id);
        final player = AudioPlayer();
        await player.setUrl(url);
        _players.add(player);
      }

      for (final player in _players) {
        await player.play();
      }
    });
  }

  List<MixerTrack> _buildMixerTracks(
    int trackCount, {
    List<MixerTrack>? previous,
  }) {
    final safeCount = trackCount.clamp(4, 8);
    final result = <MixerTrack>[];

    final melodicCount = safeCount - 1;
    for (var i = 1; i <= melodicCount; i++) {
      MixerTrack? existing;
      if (previous != null) {
        for (final track in previous) {
          if (!track.isPercussion && track.id == i) {
            existing = track;
            break;
          }
        }
      }
      result.add(
        MixerTrack(
          id: i,
          label: _s.trackLabel(i),
          isPercussion: false,
          isOn: existing?.isOn ?? true,
          permissionEnabled: existing?.permissionEnabled ?? true,
          volume: existing?.volume ?? 0.8,
        ),
      );
    }

    MixerTrack? percussion;
    if (previous != null) {
      for (final track in previous) {
        if (track.isPercussion) {
          percussion = track;
          break;
        }
      }
    }
    result.add(
      MixerTrack(
        id: 10,
        label: _s.percussionTrack,
        isPercussion: true,
        isOn: percussion?.isOn ?? true,
        permissionEnabled: percussion?.permissionEnabled ?? true,
        volume: percussion?.volume ?? 0.8,
      ),
    );

    return result;
  }

  void _updateTrackCount(int nextCount) {
    setState(() {
      _sessionTrackCount = nextCount.clamp(4, 8);
      _mixerTracks = _buildMixerTracks(
        _sessionTrackCount,
        previous: _mixerTracks,
      );
      if (!_mixerTracks.any((track) => track.id == _selectedStaffTrackId)) {
        _selectedStaffTrackId = _mixerTracks.first.id;
      }
    });
  }

  Future<void> _playSessionTransport() async {
    final selectableTakes = _takes
        .where((take) => _selectedTakeIds.contains(take.id))
        .toList();
    if (selectableTakes.isEmpty) {
      _showMessage(_s.selectAtLeastOneTake);
      return;
    }

    await _runGuarded(() async {
      if (_players.isEmpty) {
        final activeTracks = _mixerTracks
            .where((track) => track.permissionEnabled && track.isOn)
            .toList();
        final takeCount = activeTracks.length > selectableTakes.length
            ? selectableTakes.length
            : activeTracks.length;

        for (var i = 0; i < takeCount; i++) {
          final take = selectableTakes[i];
          final track = activeTracks[i];
          final url = await _api.getTakeDownloadUrl(take.id);
          final player = AudioPlayer();
          await player.setUrl(url);
          await player.setVolume(track.volume);
          if (_startPositionSeconds > 0) {
            await player.seek(
              Duration(milliseconds: (_startPositionSeconds * 1000).round()),
            );
          }
          _players.add(player);
        }
      }

      for (final player in _players) {
        await player.play();
      }

      setState(() {
        _transportState = SessionTransportState.playing;
      });
    });
  }

  Future<void> _pauseSessionTransport() async {
    await _runGuarded(() async {
      for (final player in _players) {
        await player.pause();
      }
      setState(() {
        _transportState = SessionTransportState.paused;
      });
    });
  }

  Future<void> _stopSessionTransport() async {
    await _runGuarded(() async {
      await _stopAllPlayers();
      setState(() {
        _transportState = SessionTransportState.stopped;
      });
    });
  }

  Future<void> _playLastRecording() async {
    final path = _lastRecordPath;
    if (path == null || path.isEmpty) {
      return;
    }

    await _runGuarded(() async {
      final player = AudioPlayer();
      await player.setFilePath(path);
      await player.play();
      _players.add(player);
    });
  }

  void _resetMixer() {
    setState(() {
      _mixerTracks = _buildMixerTracks(_sessionTrackCount);
    });
  }

  void _soloStaffTrack() {
    setState(() {
      for (final track in _mixerTracks) {
        track.isOn = track.id == _selectedStaffTrackId;
      }
    });
  }

  Future<void> _copySongScoreDownloadUrl() async {
    final songId = _selectedSong?.id ?? '';
    if (songId.isEmpty) {
      _showMessage(_s.selectSongFirstForTeam);
      return;
    }

    await _runGuarded(() async {
      final url = await _api.getSongScoreDownloadUrl(songId);
      await Clipboard.setData(ClipboardData(text: url));
      _showMessage(_s.copiedScoreDownloadUrl);
    });
  }

  Future<void> _copySongMidiDownloadUrl() async {
    final songId = _selectedSong?.id ?? '';
    if (songId.isEmpty) {
      _showMessage(_s.selectSongFirstForTeam);
      return;
    }

    await _runGuarded(() async {
      final url = await _api.getSongMidiDownloadUrl(songId);
      await Clipboard.setData(ClipboardData(text: url));
      _showMessage(_s.copiedMidiDownloadUrl);
    });
  }

  Future<void> _copyTakeDownloadUrl(String takeId) async {
    await _runGuarded(() async {
      final url = await _api.getTakeDownloadUrl(takeId);
      await Clipboard.setData(ClipboardData(text: url));
      _showMessage(_s.copiedTakeDownloadUrl);
    });
  }

  Future<void> _loadReviews() async {
    final songId = _selectedSong?.id ?? '';
    if (songId.isEmpty) {
      _showMessage(_s.selectSongFirstForTeam);
      return;
    }

    await _runGuarded(() async {
      final reviews = await _api.listReviews(songId);
      setState(() {
        _reviews = reviews;
      });
    });
  }

  Future<void> _submitReview() async {
    final songId = _selectedSong?.id ?? '';
    final reviewerId = _userIdController.text.trim();
    final comment = _reviewCommentController.text.trim();

    if (songId.isEmpty || reviewerId.isEmpty) {
      _showMessage(_s.requireSongAndReviewer);
      return;
    }

    await _runGuarded(() async {
      await _api.createReview(
        songId: songId,
        reviewerId: reviewerId,
        rating: _reviewRating,
        comment: comment.isEmpty ? null : comment,
      );
      _reviewCommentController.clear();
      _showMessage(_s.reviewSubmitted);
      await _loadReviews();
    });
  }

  void _selectRole(UserRole role) {
    setState(() {
      _selectedRole = role;
    });
  }

  void _goToTab(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  Future<void> _stopAllPlayers() async {
    for (final player in _players) {
      await player.stop();
      await player.dispose();
    }
    _players.clear();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openConnectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s.settings,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _s.tr('接続情報を確認し、API疎通をテストします。', 'Update endpoint settings and test API connectivity.'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5E6B78),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiBaseUrlController,
                  decoration: InputDecoration(labelText: _s.apiBaseUrl),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _minioBaseUrlController,
                  decoration: InputDecoration(labelText: _s.minioBaseUrl),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _scoreBucketController,
                  decoration: InputDecoration(labelText: _s.scoreBucket),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _projectIdController,
                  decoration: InputDecoration(labelText: _s.projectId),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _userIdController,
                  decoration: InputDecoration(labelText: _s.userId),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonal(
                      onPressed: _isBusy ? null : _healthCheck,
                      child: Text(_s.apiCheck),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_s.tr('閉じる', 'Close')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openCreateSongSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s.newSong,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _s.tr('曲情報を登録して、すぐ練習フローに追加します。', 'Register a new song and add it to your practice flow.'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5E6B78),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _songTitleController,
                  decoration: InputDecoration(labelText: _s.songTitle),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _songMidiKeyController,
                  decoration: InputDecoration(labelText: _s.midiKey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _songMusicXmlKeyController,
                  decoration: InputDecoration(labelText: _s.musicXmlKey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _songBpmController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _s.bpm),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _isBusy
                      ? null
                      : () async {
                          await _createSong();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                  child: Text(_s.createSong),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _transportStateColor() {
    return switch (_transportState) {
      SessionTransportState.playing => const Color(0xFF1B9C5A),
      SessionTransportState.paused => const Color(0xFFD98E04),
      SessionTransportState.stopped => const Color(0xFF5E6B78),
    };
  }

  IconData _transportStateIcon() {
    return switch (_transportState) {
      SessionTransportState.playing => Icons.play_circle_fill,
      SessionTransportState.paused => Icons.pause_circle,
      SessionTransportState.stopped => Icons.stop_circle,
    };
  }

  Widget _buildShell(Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    IconData? icon,
    required Widget child,
    List<Widget>? actions,
  }) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5E6B78));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(title, style: titleStyle)),
                if (actions != null) ...actions,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: subtitleStyle),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    final songLabel = _selectedSong == null
        ? _s.selectSongFirst
        : _s.currentSong(_selectedSong!.title);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3D5E), Color(0xFF1E847F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _s.practiceFlow,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            songLabel,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFE2EEF8),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE67E22),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _goToTab(1),
                child: Text(_s.resumeSession),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFB9D3E6)),
                ),
                onPressed: () => _goToTab(4),
                child: Text(_s.openLibrary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_s.appTitle),
            Text(
              _selectedSong == null
                  ? _s.tr('曲を選んで開始', 'Pick a song to begin')
                  : _selectedSong!.title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5E6B78),
              ),
            ),
          ],
        ),
        bottom: _isBusy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
        actions: [
          IconButton(
            onPressed: _isBusy ? null : _loadSongs,
            icon: const Icon(Icons.sync_rounded),
            tooltip: _s.refreshSongs,
          ),
          IconButton(
            onPressed: _openConnectionSheet,
            icon: const Icon(Icons.tune),
            tooltip: _s.settings,
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildHomeTab(),
          _buildSessionTab(),
          _buildReviewTab(),
          _buildTeamTab(),
          _buildLibraryTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            label: _s.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.multitrack_audio_outlined),
            label: _s.session,
          ),
          NavigationDestination(
            icon: const Icon(Icons.rate_review_outlined),
            label: _s.review,
          ),
          NavigationDestination(icon: const Icon(Icons.groups), label: _s.team),
          NavigationDestination(
            icon: const Icon(Icons.library_music),
            label: _s.library,
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final roleTitle = switch (_selectedRole) {
      UserRole.arranger => _s.arranger,
      UserRole.practitioner => _s.practitioner,
      UserRole.evaluator => _s.evaluator,
    };

    final roleSteps = switch (_selectedRole) {
      UserRole.arranger => [
        _s.arrangerStep1,
        _s.arrangerStep2,
        _s.arrangerStep3,
      ],
      UserRole.practitioner => [
        _s.practitionerStep1,
        _s.practitionerStep2,
        _s.practitionerStep3,
      ],
      UserRole.evaluator => [
        _s.evaluatorStep1,
        _s.evaluatorStep2,
        _s.evaluatorStep3,
      ],
    };

    return _buildShell(
      ListView(
        children: [
          _buildHeroBanner(),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: _s.tr('クイックアクション', 'Quick Actions'),
            subtitle: _s.tr('よく使う操作にすぐアクセスできます。', 'Jump right into your most common actions.'),
            icon: Icons.rocket_launch_outlined,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonal(
                  onPressed: _isBusy ? null : _loadSongs,
                  child: Text(_s.refreshSongs),
                ),
                OutlinedButton(
                  onPressed: () => _goToTab(3),
                  child: Text(_s.openTeam),
                ),
                OutlinedButton(
                  onPressed: _openConnectionSheet,
                  child: Text(_s.settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: roleTitle,
            subtitle: _s.tr('あなたの役割に合わせた次の3ステップ', 'Your next three steps for this role'),
            icon: Icons.assignment_turned_in_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(_s.arranger),
                      selected: _selectedRole == UserRole.arranger,
                      onSelected: (_) => _selectRole(UserRole.arranger),
                    ),
                    ChoiceChip(
                      label: Text(_s.practitioner),
                      selected: _selectedRole == UserRole.practitioner,
                      onSelected: (_) => _selectRole(UserRole.practitioner),
                    ),
                    ChoiceChip(
                      label: Text(_s.evaluator),
                      selected: _selectedRole == UserRole.evaluator,
                      onSelected: (_) => _selectRole(UserRole.evaluator),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < roleSteps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      tileColor: const Color(0xFFF8FBFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: const Color(0xFFDDEDF7),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        child: Text('${i + 1}'),
                      ),
                      title: Text(roleSteps[i]),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (_selectedRole == UserRole.arranger)
                      FilledButton(
                        onPressed: () {
                          _goToTab(4);
                          _openCreateSongSheet();
                        },
                        child: Text(_s.arrangerPrimaryAction),
                      ),
                    if (_selectedRole == UserRole.practitioner)
                      FilledButton(
                        onPressed: () => _goToTab(1),
                        child: Text(_s.practitionerPrimaryAction),
                      ),
                    if (_selectedRole == UserRole.evaluator)
                      FilledButton(
                        onPressed: () => _goToTab(2),
                        child: Text(_s.evaluatorPrimaryAction),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTab() {
    return _buildShell(
      ListView(
        children: [
          _buildSectionCard(
            title: _s.tr('再生コントロール', 'Playback Control'),
            subtitle: _s.tr('曲選択・再生位置・トランスポートをここで管理します。', 'Control song selection, seek, and playback transport.'),
            icon: Icons.play_circle_outline,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Song>(
                        initialValue: _selectedSong,
                        decoration: InputDecoration(labelText: _s.teamSharedSong),
                        items: _songs
                            .map(
                              (song) => DropdownMenuItem<Song>(
                                value: song,
                                child: Text(song.title),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (song) {
                          setState(() {
                            _selectedSong = song;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonal(
                      onPressed: _isBusy ? null : _loadSongs,
                      child: Text(_s.refreshSongs),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _s.startPositionLabel(_startPositionSeconds.toStringAsFixed(1)),
                  ),
                ),
                Slider(
                  min: 0,
                  max: 120,
                  value: _startPositionSeconds,
                  onChanged: (v) => setState(() => _startPositionSeconds = v),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      onPressed: _isBusy ? null : _playSessionTransport,
                      child: Text(_s.play),
                    ),
                    FilledButton.tonal(
                      onPressed: _isBusy ? null : _pauseSessionTransport,
                      child: Text(_s.pause),
                    ),
                    OutlinedButton(
                      onPressed: _isBusy ? null : _stopSessionTransport,
                      child: Text(_s.stop),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _transportStateColor().withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_transportStateIcon(), size: 18, color: _transportStateColor()),
                      const SizedBox(width: 8),
                      Text(
                        _s.transportStateLabel(_transportState.name),
                        style: TextStyle(
                          color: _transportStateColor(),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: _s.tr('譜面ビュー', 'Score View'),
            subtitle: _s.midiStaffHint,
            icon: Icons.music_note_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    DropdownButton<int>(
                      value: _selectedStaffTrackId,
                      items: _mixerTracks
                          .map(
                            (track) => DropdownMenuItem<int>(
                              value: track.id,
                              child: Text(track.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedStaffTrackId = value;
                        });
                      },
                    ),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: true, label: Text(_s.trebleClef)),
                        ButtonSegment(value: false, label: Text(_s.bassClef)),
                      ],
                      selected: {_showTrebleClef},
                      onSelectionChanged: (value) {
                        setState(() {
                          _showTrebleClef = value.first;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCFEFF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDCE3EC)),
                  ),
                  child: CustomPaint(
                    painter: _MidiStaffPainter(
                      showTrebleClef: _showTrebleClef,
                      seed: _selectedStaffTrackId,
                    ),
                    child: Center(
                      child: Text(_s.midiStaffHint, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: _s.mixer,
            subtitle: _s.trackCountLabel(_sessionTrackCount),
            icon: Icons.tune,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  min: 4,
                  max: 8,
                  divisions: 4,
                  value: _sessionTrackCount.toDouble(),
                  onChanged: (value) => _updateTrackCount(value.round()),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonal(
                      onPressed: _soloStaffTrack,
                      child: Text(_s.soloSelected),
                    ),
                    OutlinedButton(
                      onPressed: _resetMixer,
                      child: Text(_s.resetMix),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 320,
                  child: ListView.builder(
                    itemCount: _mixerTracks.length,
                    itemBuilder: (context, index) {
                      final track = _mixerTracks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(track.label),
                              Row(
                                children: [
                                  Switch(
                                    value: track.isOn,
                                    onChanged: (value) {
                                      setState(() {
                                        track.isOn = value;
                                      });
                                    },
                                  ),
                                  Text(_s.trackOnOff(track.isOn)),
                                  const Spacer(),
                                  FilterChip(
                                    selected: track.permissionEnabled,
                                    label: Text(_s.permission),
                                    onSelected: (value) {
                                      setState(() {
                                        track.permissionEnabled = value;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Text(_s.trackVolumeLabel((track.volume * 100).round())),
                              Slider(
                                min: 0,
                                max: 1,
                                value: track.volume,
                                onChanged: (value) {
                                  setState(() {
                                    track.volume = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: _s.tr('録音と共有', 'Recording and Sharing'),
            subtitle: _s.tr('録音、アップロード、チーム音声確認をまとめて行えます。', 'Record, upload, and review team takes in one place.'),
            icon: Icons.graphic_eq,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _copySongScoreDownloadUrl,
                      icon: const Icon(Icons.download),
                      label: Text(_s.downloadScore),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _copySongMidiDownloadUrl,
                      icon: const Icon(Icons.audio_file),
                      label: Text(_s.downloadMidi),
                    ),
                    FilledButton.tonal(
                      onPressed: _isBusy ? null : _loadTakes,
                      child: Text(_s.loadTeamTakes),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _s.teammateTrackDownloads,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    itemCount: _takes.length,
                    itemBuilder: (context, index) {
                      final take = _takes[index];
                      final selected = _selectedTakeIds.contains(take.id);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Checkbox(
                          value: selected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedTakeIds.add(take.id);
                              } else {
                                _selectedTakeIds.remove(take.id);
                              }
                            });
                          },
                        ),
                        title: Text(_s.teammateTakeTitle(index + 1, take.userId)),
                        subtitle: Text(_s.offsetMs(take.offsetMs)),
                        trailing: IconButton(
                          onPressed: _isBusy ? null : () => _copyTakeDownloadUrl(take.id),
                          icon: const Icon(Icons.download),
                          tooltip: _s.downloadTake,
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 20),
                Text(
                  _s.myRecording,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      onPressed: _isBusy || _isRecording ? null : _startRecording,
                      child: Text(_s.record),
                    ),
                    FilledButton.tonal(
                      onPressed: _isBusy || !_isRecording ? null : _stopRecording,
                      child: Text(_s.stop),
                    ),
                    FilledButton.tonal(
                      onPressed: _isBusy || _lastRecordPath == null ? null : _playLastRecording,
                      child: Text(_s.play),
                    ),
                    OutlinedButton(
                      onPressed: _isBusy || _lastRecordPath == null ? null : _uploadLastTake,
                      child: Text(_s.upload),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_s.recordingStatus(_isRecording)),
                Text(_s.durationMs(_recordStopwatch.elapsedMilliseconds)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTab() {
    final offsetValue = ((double.tryParse(_offsetMsController.text) ?? 0).clamp(
      -300,
      300,
    )).toDouble();

    return _buildShell(
      ListView(
        children: [
          _buildSectionCard(
            title: _s.takeReview,
            subtitle: _s.tr('録音タイミングを調整して、共有前に仕上げます。', 'Fine tune recording offset before sharing.'),
            icon: Icons.waves_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_s.lastTake(_lastRecordPath ?? '-')),
                Text(_s.durationMs(_recordStopwatch.elapsedMilliseconds)),
                const SizedBox(height: 10),
                Text(_s.offsetMs(offsetValue.round())),
                Slider(
                  min: -300,
                  max: 300,
                  divisions: 60,
                  value: offsetValue,
                  onChanged: (value) {
                    setState(() {
                      _offsetMsController.text = value.round().toString();
                    });
                  },
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE67E22),
                        foregroundColor: Colors.white,
                      ),
                      onPressed:
                          _isBusy || _lastRecordPath == null ? null : _uploadLastTake,
                      child: Text(_s.saveAndShare),
                    ),
                    FilledButton.tonal(
                      onPressed: _isBusy || _isRecording ? null : _startRecording,
                      child: Text(_s.rerecord),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: _s.thirdPartyReview,
            subtitle: _s.tr('客観評価を追加して、改善ポイントを残します。', 'Add objective feedback and next improvements.'),
            icon: Icons.feedback_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_s.ratingLabel(_reviewRating)),
                Slider(
                  min: 1,
                  max: 5,
                  divisions: 4,
                  value: _reviewRating.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _reviewRating = value.round();
                    });
                  },
                ),
                TextField(
                  controller: _reviewCommentController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: _s.reviewComment),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      onPressed: _isBusy ? null : _submitReview,
                      child: Text(_s.submitReview),
                    ),
                    FilledButton.tonal(
                      onPressed: _isBusy ? null : _loadReviews,
                      child: Text(_s.loadReviews),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildSectionCard(
            title: _s.reviewList,
            subtitle: _s.countLabel(_reviews.length),
            icon: Icons.list_alt_outlined,
            child: Column(
              children: [
                if (_reviews.isEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(_s.noReviewsYet),
                  ),
                for (final review in _reviews)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.rate_review_outlined),
                    title: Text(_s.ratingLabel(review.rating)),
                    subtitle: Text(
                      '${_s.reviewer(review.reviewerId)}\n${review.comment ?? '-'}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTab() {
    return _buildShell(
      ListView(
        children: [
          _buildSectionCard(
            title: _s.team,
            subtitle: _s.tr('複数テイクを比較しながら、チーム全体の完成度を上げます。', 'Compare multiple takes to improve team performance.'),
            icon: Icons.groups,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonal(
                      onPressed: _isBusy ? null : _loadTakes,
                      child: Text(_s.loadTeamTakes),
                    ),
                    FilledButton(
                      onPressed: _isBusy ? null : _playSelectedTakes,
                      child: Text(_s.playSelectedTogether),
                    ),
                    OutlinedButton(
                      onPressed: _isBusy ? null : () => _runGuarded(_stopAllPlayers),
                      child: Text(_s.stop),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 460,
                  child: ListView.builder(
                    itemCount: _takes.length,
                    itemBuilder: (context, index) {
                      final take = _takes[index];
                      final selected = _selectedTakeIds.contains(take.id);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Checkbox(
                            value: selected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedTakeIds.add(take.id);
                                } else {
                                  _selectedTakeIds.remove(take.id);
                                }
                              });
                            },
                          ),
                          title: Text('${_s.tr('ユーザー', 'User')}: ${take.userId}'),
                          subtitle: Text(
                            '${_s.tr('テイク', 'Take')}: ${take.id}\n${_s.offsetMs(take.offsetMs)}',
                          ),
                          trailing: IconButton(
                            onPressed:
                                _isBusy ? null : () => _copyTakeDownloadUrl(take.id),
                            icon: const Icon(Icons.download),
                            tooltip: _s.downloadTake,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Song> get _filteredSongs {
    if (_songSearchQuery.isEmpty) {
      return _songs;
    }
    final query = _songSearchQuery.toLowerCase();
    return _songs
        .where((song) => song.title.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _onSongSearchChanged(String value) {
    setState(() {
      _songSearchQuery = value.trim();
    });
  }

  Widget _buildLibraryTab() {
    final songs = _filteredSongs;
    return _buildShell(
      ListView(
        children: [
          _buildSectionCard(
            title: _s.library,
            subtitle: _s.tr('曲の管理と選択はここで行います。', 'Manage and select songs here.'),
            icon: Icons.library_music_outlined,
            child: Column(
              children: [
                Row(
                  children: [
                    FilledButton.tonal(
                      onPressed: _isBusy ? null : _loadSongs,
                      child: Text(_s.loadSongs),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _openCreateSongSheet,
                      child: Text(_s.newSong),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _songSearchController,
                  decoration: InputDecoration(
                    hintText: _s.searchSongs,
                    prefixIcon: const Icon(Icons.search_outlined),
                    suffixIcon: _songSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_outlined),
                            onPressed: () {
                              _songSearchController.clear();
                              _onSongSearchChanged('');
                            },
                          ),
                  ),
                  onChanged: _onSongSearchChanged,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 520,
                  child: songs.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(_s.noSongsMatch),
                          ),
                        )
                      : ListView.builder(
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            final isSelected = _selectedSong?.id == song.id;
                            return Card(
                              color: isSelected
                                  ? const Color(0xFFEDF6FE)
                                  : Theme.of(context).cardTheme.color,
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                selected: isSelected,
                                onTap: () {
                                  setState(() {
                                    _selectedSong = song;
                                  });
                                  _showMessage(_s.selected(song.title));
                                },
                                title: Text(song.title),
                                subtitle: Text(song.id),
                                trailing: song.musicxmlObjectKey == null
                                    ? const Icon(Icons.music_note_outlined)
                                    : const Icon(Icons.menu_book),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MidiStaffPainter extends CustomPainter {
  _MidiStaffPainter({required this.showTrebleClef, required this.seed});

  final bool showTrebleClef;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF5B5B5B)
      ..strokeWidth = 1;

    final notePaint = Paint()..color = const Color(0xFF1C7C54);
    final width = size.width;
    final height = size.height;
    final top = height * 0.25;
    final gap = 16.0;

    for (var i = 0; i < 5; i++) {
      final y = top + (i * gap);
      canvas.drawLine(Offset(20, y), Offset(width - 20, y), linePaint);
    }

    final clefTextPainter = TextPainter(
      text: TextSpan(
        text: showTrebleClef ? 'G' : 'F',
        style: const TextStyle(fontSize: 28, color: Color(0xFF1C1C1C)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    clefTextPainter.paint(canvas, Offset(24, top - 12));

    final random = math.Random(seed * 97);
    final noteCount = 14;
    final stepX = (width - 90) / noteCount;

    for (var i = 0; i < noteCount; i++) {
      final x = 66 + (i * stepX);
      final yOffset = random.nextInt(9) - 4;
      final y = top + (2 * gap) - (yOffset * 6);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 11, height: 8),
        notePaint,
      );
      canvas.drawLine(Offset(x + 5, y), Offset(x + 5, y - 22), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MidiStaffPainter oldDelegate) {
    return oldDelegate.showTrebleClef != showTrebleClef ||
        oldDelegate.seed != seed;
  }
}
