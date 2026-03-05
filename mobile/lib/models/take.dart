class Take {
  const Take({
    required this.id,
    required this.songId,
    required this.userId,
    required this.audioObjectKey,
    required this.durationMs,
    required this.offsetMs,
    this.sampleRate,
  });

  final String id;
  final String songId;
  final String userId;
  final String audioObjectKey;
  final int durationMs;
  final int offsetMs;
  final int? sampleRate;

  factory Take.fromJson(Map<String, dynamic> json) {
    return Take(
      id: json['id'] as String,
      songId: json['song_id'] as String,
      userId: json['user_id'] as String,
      audioObjectKey: json['audio_object_key'] as String,
      durationMs: json['duration_ms'] as int,
      offsetMs: json['offset_ms'] as int,
      sampleRate: json['sample_rate'] as int?,
    );
  }
}
