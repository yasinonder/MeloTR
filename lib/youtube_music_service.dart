import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'mp3_import_service.dart';

/// Unofficial YouTube access; restrictions and availability may change.
/// Only save recordings that the user has permission to download.
class YoutubeMusicService {
  final YoutubeExplode _youtube = YoutubeExplode();
  final Mp3ImportService _converter = Mp3ImportService();

  static String? videoIdFromInput(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null || !['https', 'http'].contains(uri.scheme)) return null;
    final host = uri.host.toLowerCase();
    if (host == 'youtu.be' || host == 'www.youtu.be' ||
        host == 'youtube.com' || host.endsWith('.youtube.com')) {
      return VideoId.parseVideoId(input.trim());
    }
    return null;
  }

  Future<List<Video>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return <Video>[];
    final id = videoIdFromInput(trimmed);
    if (id != null) {
      final video = await _youtube.videos.get(id);
      return <Video>[video];
    }
    final results = await _youtube.search.search(trimmed);
    return results.toList(growable: false);
  }

  Future<String> saveMp3(
    Video video, {
    required int kbps,
    required void Function(String) onStatus,
    required void Function(double) onProgress,
  }) async {
    onStatus('Ses akışı hazırlanıyor…');
    final manifest = await _youtube.videos.streams.getManifest(video.id);
    if (manifest.audioOnly.isEmpty) {
      throw const FormatException('Bu video için indirilebilir ses bulunamadı.');
    }
    final info = manifest.audioOnly.withHighestBitrate();
    final root = await getApplicationSupportDirectory();
    final work = Directory(root.path + '/melotr_jobs/yt_' +
        DateTime.now().microsecondsSinceEpoch.toString());
    await work.create(recursive: true);
    final input = File(work.path + '/source.' + info.container.name);
    onStatus('Ses indiriliyor…');
    final sink = input.openWrite();
    int received = 0;
    try {
      await for (final bytes in _youtube.videos.streams.get(info)) {
        sink.add(bytes);
        received += bytes.length;
        if (info.size.totalBytes > 0) {
          onProgress((received / info.size.totalBytes).clamp(0.0, 1.0));
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    if (!await input.exists() || await input.length() < 1024) {
      throw const FormatException('İndirilen ses boş veya hatalı.');
    }
    onProgress(1.0);
    // The converter removes temporary bytes only after MediaStore verification.
    return _converter.fromAppTemporaryMedia(
      mediaFile: input,
      title: video.title,
      kbps: kbps,
      onStatus: onStatus,
    );
  }

  void dispose() => _youtube.close();
}
