import 'dart:io';

import 'package:dio/dio.dart';

import '../models/song.dart';
import '../models/take.dart';
import '../models/review.dart';

class PresignedUpload {
  const PresignedUpload({
    required this.objectKey,
    required this.uploadUrl,
    required this.expiresInSeconds,
  });

  final String objectKey;
  final String uploadUrl;
  final int expiresInSeconds;

  factory PresignedUpload.fromJson(Map<String, dynamic> json) {
    return PresignedUpload(
      objectKey: json['object_key'] as String,
      uploadUrl: json['upload_url'] as String,
      expiresInSeconds: json['expires_in_seconds'] as int,
    );
  }
}

class ApiService {
  ApiService({required this.baseUrl})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  final Dio _dio;
  String baseUrl;

  void updateBaseUrl(String nextBaseUrl) {
    baseUrl = nextBaseUrl;
    _dio.options.baseUrl = nextBaseUrl;
  }

  Future<void> healthCheck() async {
    await _dio.get('/health');
  }

  Future<List<Song>> listSongs(String projectId) async {
    final response = await _dio.get(
      '/songs',
      queryParameters: {'project_id': projectId},
    );
    final data = response.data as List<dynamic>;
    return data
        .map((item) => Song.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Song> createSong({
    required String projectId,
    required String title,
    required String midiObjectKey,
    String? musicxmlObjectKey,
    int? bpm,
    String? createdBy,
  }) async {
    final response = await _dio.post(
      '/songs',
      data: {
        'project_id': projectId,
        'title': title,
        'midi_object_key': midiObjectKey,
        'musicxml_object_key': musicxmlObjectKey,
        'bpm': bpm,
        'created_by': createdBy,
      },
    );
    return Song.fromJson(response.data as Map<String, dynamic>);
  }

  Future<PresignedUpload> presignTakeUpload({
    required String songId,
    required String userId,
    required String fileName,
    required String contentType,
  }) async {
    final response = await _dio.post(
      '/takes/presign-upload',
      data: {
        'song_id': songId,
        'user_id': userId,
        'filename': fileName,
        'content_type': contentType,
      },
    );
    return PresignedUpload.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> uploadToPresignedUrl({
    required String uploadUrl,
    required String filePath,
    required String contentType,
  }) async {
    final uploadDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    final file = File(filePath);
    final bytes = await file.readAsBytes();

    await uploadDio.put(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {'Content-Type': contentType, 'Content-Length': bytes.length},
      ),
    );
  }

  Future<Take> createTake({
    required String songId,
    required String userId,
    required String audioObjectKey,
    required int durationMs,
    required int offsetMs,
    int? sampleRate,
  }) async {
    final response = await _dio.post(
      '/takes',
      data: {
        'song_id': songId,
        'user_id': userId,
        'audio_object_key': audioObjectKey,
        'duration_ms': durationMs,
        'offset_ms': offsetMs,
        'sample_rate': sampleRate,
      },
    );
    return Take.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Take>> listTakes(String songId) async {
    final response = await _dio.get(
      '/takes',
      queryParameters: {'song_id': songId},
    );
    final data = response.data as List<dynamic>;
    return data
        .map((item) => Take.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<String> getTakeDownloadUrl(String takeId) async {
    final response = await _dio.get('/takes/$takeId/download-url');
    return (response.data as Map<String, dynamic>)['download_url'] as String;
  }

  Future<String> getSongMidiDownloadUrl(String songId) async {
    final response = await _dio.get('/songs/$songId/midi-download-url');
    return (response.data as Map<String, dynamic>)['download_url'] as String;
  }

  Future<String> getSongScoreDownloadUrl(String songId) async {
    final response = await _dio.get('/songs/$songId/score-download-url');
    return (response.data as Map<String, dynamic>)['download_url'] as String;
  }

  Future<Review> createReview({
    required String songId,
    required String reviewerId,
    required int rating,
    String? comment,
  }) async {
    final response = await _dio.post(
      '/reviews',
      data: {
        'song_id': songId,
        'reviewer_id': reviewerId,
        'rating': rating,
        'comment': comment,
      },
    );
    return Review.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Review>> listReviews(String songId) async {
    final response = await _dio.get(
      '/reviews',
      queryParameters: {'song_id': songId},
    );
    final data = response.data as List<dynamic>;
    return data
        .map((item) => Review.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
