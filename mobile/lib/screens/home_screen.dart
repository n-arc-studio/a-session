import 'dart:io';
import 'dart:math' as math;

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
  final TextEditingController _apiBaseUrlController =
      TextEditingController(text: 'http://10.0.2.2:8000');
  final TextEditingController _minioBaseUrlController =
      TextEditingController(text: 'http://10.0.2.2:9000');
  final TextEditingController _scoreBucketController =
      TextEditingController(text: 'a-session-score');
  final TextEditingController _projectIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _songTitleController = TextEditingController();
  final TextEditingController _songMidiKeyController = TextEditingController();
  final TextEditingController _songMusicXmlKeyController = TextEditingController();
  final TextEditingController _songBpmController = TextEditingController();
  final TextEditingController _offsetMsController = TextEditingController(text: '0');
  final TextEditingController _reviewCommentController = TextEditingController();

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
    for (final player in _players) {
      player.dispose();
    }
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
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
      _showMessage('${_s.errorPrefix}: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
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
          final existing =
              songs.where((song) => song.id == _selectedSong!.id).toList();
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
    });
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
    final selected =
        _takes.where((take) => _selectedTakeIds.contains(take.id)).toList();
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

  List<MixerTrack> _buildMixerTracks(int trackCount, {List<MixerTrack>? previous}) {
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
      _mixerTracks = _buildMixerTracks(_sessionTrackCount, previous: _mixerTracks);
      if (!_mixerTracks.any((track) => track.id == _selectedStaffTrackId)) {
        _selectedStaffTrackId = _mixerTracks.first.id;
      }
    });
  }

  Future<void> _playSessionTransport() async {
    final selectableTakes = _takes.where((take) => _selectedTakeIds.contains(take.id)).toList();
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
            await player.seek(Duration(milliseconds: (_startPositionSeconds * 1000).round()));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _apiBaseUrlController,
                decoration: InputDecoration(
                  labelText: _s.apiBaseUrl,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _minioBaseUrlController,
                decoration: InputDecoration(
                  labelText: _s.minioBaseUrl,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _scoreBucketController,
                decoration: InputDecoration(
                  labelText: _s.scoreBucket,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _projectIdController,
                decoration: InputDecoration(
                  labelText: _s.projectId,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _userIdController,
                decoration: InputDecoration(
                  labelText: _s.userId,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: _isBusy ? null : _healthCheck,
                child: Text(_s.apiCheck),
              ),
            ],
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
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _songTitleController,
                decoration: InputDecoration(
                  labelText: _s.songTitle,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _songMidiKeyController,
                decoration: InputDecoration(
                  labelText: _s.midiKey,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _songMusicXmlKeyController,
                decoration: InputDecoration(
                  labelText: _s.musicXmlKey,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _songBpmController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _s.bpm,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.appTitle),
        actions: [
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
            icon: const Icon(Icons.home_outlined),
            label: _s.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.piano),
            label: _s.session,
          ),
          NavigationDestination(
            icon: const Icon(Icons.equalizer),
            label: _s.review,
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups),
            label: _s.team,
          ),
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
      UserRole.arranger => [_s.arrangerStep1, _s.arrangerStep2, _s.arrangerStep3],
      UserRole.practitioner => [
        _s.practitionerStep1,
        _s.practitionerStep2,
        _s.practitionerStep3,
      ],
      UserRole.evaluator => [_s.evaluatorStep1, _s.evaluatorStep2, _s.evaluatorStep3],
    };

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_s.practiceFlow, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            _selectedSong == null
                ? _s.selectSongFirst
                : _s.currentSong(_selectedSong!.title),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(onPressed: () => _goToTab(1), child: Text(_s.resumeSession)),
                  FilledButton.tonal(onPressed: () => _goToTab(4), child: Text(_s.openLibrary)),
                  OutlinedButton(
                    onPressed: _isBusy ? null : _loadSongs,
                    child: Text(_s.refreshSongs),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<UserRole>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: UserRole.arranger, label: Text(_s.arranger)),
              ButtonSegment(value: UserRole.practitioner, label: Text(_s.practitioner)),
              ButtonSegment(value: UserRole.evaluator, label: Text(_s.evaluator)),
            ],
            selected: {_selectedRole},
            onSelectionChanged: (value) => _selectRole(value.first),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(roleTitle, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          for (var i = 0; i < roleSteps.length; i++)
                            ListTile(
                              leading: Icon(
                                switch (i) {
                                  0 => Icons.looks_one_outlined,
                                  1 => Icons.looks_two_outlined,
                                  _ => Icons.looks_3_outlined,
                                },
                              ),
                              title: Text(roleSteps[i]),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
                        OutlinedButton(
                          onPressed: () => _goToTab(3),
                          child: Text(_s.openTeam),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          final header = Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Song>(
                          initialValue: _selectedSong,
                          decoration: InputDecoration(
                            labelText: _s.teamSharedSong,
                            border: const OutlineInputBorder(),
                          ),
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
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _isBusy ? null : _loadSongs,
                        child: Text(_s.refreshSongs),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_s.startPositionLabel(_startPositionSeconds.toStringAsFixed(1))),
                            Slider(
                              min: 0,
                              max: 120,
                              value: _startPositionSeconds,
                              onChanged: (v) => setState(() => _startPositionSeconds = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isBusy ? null : _playSessionTransport,
                        child: Text(_s.play),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _isBusy ? null : _pauseSessionTransport,
                        child: Text(_s.pause),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _isBusy ? null : _stopSessionTransport,
                        child: Text(_s.stop),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(label: Text(_s.transportStateLabel(_transportState.name))),
                  ),
                ],
              ),
            ),
          );

          final staffPane = Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: CustomPaint(
                        painter: _MidiStaffPainter(
                          showTrebleClef: _showTrebleClef,
                          seed: _selectedStaffTrackId,
                        ),
                        child: Center(
                          child: Text(
                            _s.midiStaffHint,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          final mixerPane = Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_s.mixer, style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      Text(_s.trackCountLabel(_sessionTrackCount)),
                    ],
                  ),
                  Slider(
                    min: 4,
                    max: 8,
                    divisions: 4,
                    value: _sessionTrackCount.toDouble(),
                    onChanged: (value) => _updateTrackCount(value.round()),
                  ),
                  Wrap(
                    spacing: 8,
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
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _mixerTracks.length,
                      itemBuilder: (context, index) {
                        final track = _mixerTracks[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
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
          );

          final audioPane = Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                  const SizedBox(height: 8),
                  Text(_s.teammateTrackDownloads, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      itemCount: _takes.length,
                      itemBuilder: (context, index) {
                        final take = _takes[index];
                        final selected = _selectedTakeIds.contains(take.id);
                        return ListTile(
                          dense: true,
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
                  const Divider(),
                  Text(_s.myRecording, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                        onPressed: _isBusy || _lastRecordPath == null
                            ? null
                            : _playLastRecording,
                        child: Text(_s.play),
                      ),
                      OutlinedButton(
                        onPressed: _isBusy || _lastRecordPath == null
                            ? null
                            : _uploadLastTake,
                        child: Text(_s.upload),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_s.recordingStatus(_isRecording)),
                  Text(_s.durationMs(_recordStopwatch.elapsedMilliseconds)),
                ],
              ),
            ),
          );

          if (isWide) {
            return Column(
              children: [
                header,
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(flex: 6, child: staffPane),
                      const SizedBox(width: 12),
                      Expanded(flex: 4, child: mixerPane),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(height: 340, child: audioPane),
              ],
            );
          }

          return ListView(
            children: [
              header,
              const SizedBox(height: 12),
              SizedBox(height: 340, child: staffPane),
              const SizedBox(height: 12),
              SizedBox(height: 420, child: mixerPane),
              const SizedBox(height: 12),
              SizedBox(height: 420, child: audioPane),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewTab() {
    final offsetValue = ((double.tryParse(_offsetMsController.text) ?? 0)
        .clamp(-300, 300))
      .toDouble();

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          Text(_s.takeReview, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
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
          ),
          const SizedBox(height: 12),
          Text(_s.thirdPartyReview, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                    decoration: InputDecoration(
                      labelText: _s.reviewComment,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: Text(_s.reviewList),
                  trailing: Text(_s.countLabel(_reviews.length)),
                ),
                const Divider(height: 1),
                if (_reviews.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_s.noReviewsYet),
                    ),
                  ),
                for (final review in _reviews)
                  ListTile(
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: ListView.builder(
                itemCount: _takes.length,
                itemBuilder: (context, index) {
                  final take = _takes[index];
                  final selected = _selectedTakeIds.contains(take.id);
                  return ListTile(
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
                    subtitle: Text('${_s.tr('テイク', 'Take')}: ${take.id}\n${_s.offsetMs(take.offsetMs)}'),
                    trailing: IconButton(
                      onPressed: _isBusy ? null : () => _copyTakeDownloadUrl(take.id),
                      icon: const Icon(Icons.download),
                      tooltip: _s.downloadTake,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton.tonal(
                onPressed: _isBusy ? null : _loadSongs,
                child: Text(_s.loadSongs),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _openCreateSongSheet,
                child: Text(_s.newSong),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: ListView.builder(
                itemCount: _songs.length,
                itemBuilder: (context, index) {
                  final song = _songs[index];
                  final isSelected = _selectedSong?.id == song.id;
                  return ListTile(
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
                  );
                },
              ),
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
    return oldDelegate.showTrebleClef != showTrebleClef || oldDelegate.seed != seed;
  }
}
