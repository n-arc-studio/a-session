class Song {
  const Song({
    required this.id,
    required this.projectId,
    required this.title,
    required this.midiObjectKey,
    this.musicxmlObjectKey,
    this.bpm,
  });

  final String id;
  final String projectId;
  final String title;
  final String midiObjectKey;
  final String? musicxmlObjectKey;
  final int? bpm;

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      title: json['title'] as String,
      midiObjectKey: json['midi_object_key'] as String,
      musicxmlObjectKey: json['musicxml_object_key'] as String?,
      bpm: json['bpm'] as int?,
    );
  }
}
