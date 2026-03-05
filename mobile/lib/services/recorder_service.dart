import 'package:record/record.dart';

class RecorderService {
  RecorderService() : _record = AudioRecorder();

  final AudioRecorder _record;

  Future<bool> hasPermission() => _record.hasPermission();

  Future<void> start(String filePath) {
    return _record.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: filePath,
    );
  }

  Future<String?> stop() => _record.stop();

  Future<void> dispose() => _record.dispose();
}
