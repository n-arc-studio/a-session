import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/song.dart';
import '../models/take.dart';
import '../services/api_service.dart';
import '../services/recorder_service.dart';
import '../widgets/score_webview.dart';

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
  final TextEditingController _songIdController = TextEditingController();
  final TextEditingController _songTitleController = TextEditingController();
  final TextEditingController _songMidiKeyController = TextEditingController();
  final TextEditingController _songMusicXmlKeyController = TextEditingController();
  final TextEditingController _songBpmController = TextEditingController();
  final TextEditingController _offsetMsController = TextEditingController(text: '0');

  late ApiService _api;
  final RecorderService _recorder = RecorderService();
  final Stopwatch _recordStopwatch = Stopwatch();

  List<Song> _songs = const [];
  List<Take> _takes = const [];
  final Set<String> _selectedTakeIds = <String>{};
  final List<AudioPlayer> _players = <AudioPlayer>[];

  int _tabIndex = 0;
  bool _isBusy = false;
  bool _isRecording = false;
  String? _lastRecordPath;
  String? _scorePreviewUrl;

  @override
  void initState() {
    super.initState();
    _api = ApiService(baseUrl: _apiBaseUrlController.text.trim());
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _minioBaseUrlController.dispose();
    _scoreBucketController.dispose();
    _projectIdController.dispose();
    _userIdController.dispose();
    _songIdController.dispose();
    _songTitleController.dispose();
    _songMidiKeyController.dispose();
    _songMusicXmlKeyController.dispose();
    _songBpmController.dispose();
    _offsetMsController.dispose();
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('API connection OK')));
    });
  }

  Future<void> _loadSongs() async {
    final projectId = _projectIdController.text.trim();
    if (projectId.isEmpty) {
      _showMessage('Project ID is required.');
      return;
    }

    await _runGuarded(() async {
      final songs = await _api.listSongs(projectId);
      setState(() {
        _songs = songs;
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
      _showMessage('Project ID, title, MIDI key are required.');
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
      });
    });
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showMessage('Microphone permission is required.');
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
    final songId = _songIdController.text.trim();
    final userId = _userIdController.text.trim();
    final offsetMs = int.tryParse(_offsetMsController.text.trim()) ?? 0;
    final path = _lastRecordPath;

    if (songId.isEmpty || userId.isEmpty || path == null || path.isEmpty) {
      _showMessage('Song ID, User ID and a recording are required.');
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      _showMessage('Recording file does not exist: $path');
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

      _showMessage('Take uploaded and registered.');
    });
  }

  Future<void> _loadTakes() async {
    final songId = _songIdController.text.trim();
    if (songId.isEmpty) {
      _showMessage('Song ID is required.');
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
    final selected = _takes.where((take) => _selectedTakeIds.contains(take.id)).toList();
    if (selected.isEmpty) {
      _showMessage('Select at least one take.');
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

  String _buildScoreUrlForSong(Song song) {
    final base = _minioBaseUrlController.text.trim();
    final bucket = _scoreBucketController.text.trim();
    final key = song.musicxmlObjectKey ?? '';
    return '$base/$bucket/$key';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('A:SESSION MVP'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                runSpacing: 8,
                spacing: 8,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _apiBaseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'API Base URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _projectIdController,
                      decoration: const InputDecoration(
                        labelText: 'Project ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _songIdController,
                      decoration: const InputDecoration(
                        labelText: 'Song ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        labelText: 'User ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _isBusy ? null : _healthCheck,
                    child: const Text('API Check'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildSongsAndScoreTab(),
                  _buildRecordTab(),
                  _buildTeamMixTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.music_note), label: 'Songs/Score'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Record'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Team Mix'),
        ],
      ),
    );
  }

  Widget _buildSongsAndScoreTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Wrap(
            runSpacing: 8,
            spacing: 8,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _songTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Song Title',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _songMidiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'MIDI Object Key',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _songMusicXmlKeyController,
                  decoration: const InputDecoration(
                    labelText: 'MusicXML Object Key',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _songBpmController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'BPM',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton(
                onPressed: _isBusy ? null : _createSong,
                child: const Text('Create Song'),
              ),
              FilledButton.tonal(
                onPressed: _isBusy ? null : _loadSongs,
                child: const Text('Load Songs'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minioBaseUrlController,
                  decoration: const InputDecoration(
                    labelText: 'MinIO Base URL',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _scoreBucketController,
                  decoration: const InputDecoration(
                    labelText: 'Score Bucket',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 360,
                  child: Card(
                    child: ListView.builder(
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        return ListTile(
                          title: Text(song.title),
                          subtitle: Text(song.id),
                          trailing: song.musicxmlObjectKey == null
                              ? null
                              : const Icon(Icons.menu_book),
                          onTap: () {
                            setState(() {
                              _songIdController.text = song.id;
                              _scorePreviewUrl = song.musicxmlObjectKey == null
                                  ? null
                                  : _buildScoreUrlForSong(song);
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: _scorePreviewUrl == null
                        ? const Center(
                            child: Text('MusicXML付きの曲を選ぶと譜面を表示します'),
                          )
                        : Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  _scorePreviewUrl!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(child: ScoreWebView(musicXmlUrl: _scorePreviewUrl!)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _isBusy || _isRecording ? null : _startRecording,
                child: const Text('Start Recording'),
              ),
              FilledButton.tonal(
                onPressed: _isBusy || !_isRecording ? null : _stopRecording,
                child: const Text('Stop Recording'),
              ),
              FilledButton(
                onPressed: _isBusy || _lastRecordPath == null ? null : _uploadLastTake,
                child: const Text('Upload Last Take'),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _offsetMsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Offset (ms)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Recording: ${_isRecording ? 'ON' : 'OFF'}'),
          Text('Last file: ${_lastRecordPath ?? '-'}'),
          Text('Duration: ${_recordStopwatch.elapsedMilliseconds} ms'),
          const SizedBox(height: 16),
          const Text(
            '録音手順:\n'
            '1) Start Recording\n'
            '2) Stop Recording\n'
            '3) Song ID / User ID を確認\n'
            '4) Upload Last Take',
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMixTab() {
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
                child: const Text('Load Takes'),
              ),
              FilledButton(
                onPressed: _isBusy ? null : _playSelectedTakes,
                child: const Text('Play Selected Together'),
              ),
              FilledButton.tonal(
                onPressed: _isBusy ? null : () => _runGuarded(_stopAllPlayers),
                child: const Text('Stop'),
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
                  return CheckboxListTile(
                    value: selected,
                    title: Text('User: ${take.userId}'),
                    subtitle: Text('Take: ${take.id}\nOffset: ${take.offsetMs} ms'),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedTakeIds.add(take.id);
                        } else {
                          _selectedTakeIds.remove(take.id);
                        }
                      });
                    },
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
