import 'dart:async';
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
      final video = await _youtube.videos.get(id)
          .timeout(const Duration(seconds:25));
      return <Video>[video];
    }
    final results = await _youtube.search.search(trimmed)
        .timeout(const Duration(seconds:25));
    return results.toList(growable: false);
  }

  Future<String> saveMp3(
    Video video, {
    required int kbps,
    required void Function(String) onStatus,
    required void Function(double) onProgress,
  }) async {
    onStatus('1/4 · YouTube ses bilgisi alınıyor…');
    // Manifest requests can hang or be blocked by YouTube.
    final manifest = await _youtube.videos.streams.getManifest(video.id)
        .timeout(
          const Duration(seconds:35),
          onTimeout: () => throw TimeoutException(
            'YouTube ses bilgisine 35 saniyede yanıt vermedi. '
            'Başka bir video veya bağlantı deneyin.',
          ),
        );
    if (manifest.audioOnly.isEmpty) {
      throw const FormatException('Bu video için indirilebilir ses bulunamadı.');
    }
    final info = manifest.audioOnly.withHighestBitrate();
    final root = await getApplicationSupportDirectory();
    final work = Directory(root.path + '/melotr_jobs/yt_' +
        DateTime.now().microsecondsSinceEpoch.toString());
    await work.create(recursive: true);
    final input = File(work.path + '/source.' + info.container.name);
    onStatus('2/4 · Ses akışı indiriliyor…');
    final sink = input.openWrite();
    final started = DateTime.now();
    var lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);
    int received = 0;
    try {
      // No bytes for 25s => fail visibly instead of showing a spinner forever.
      // An absolute 5-minute limit also prevents slow endless transfers.
      final bytesStream = _youtube.videos.streams.get(info).timeout(
        const Duration(seconds:25),
        onTimeout: (sink) => sink.addError(TimeoutException(
          'YouTube ses verisi 25 saniyedir gelmiyor. '
          'Bağlantı veya video erişimi engellenmiş olabilir.',
        )),
      );
      await for (final bytes in bytesStream) {
        if (DateTime.now().difference(started) >
            const Duration(minutes:5)) {
          throw TimeoutException('İndirme 5 dakikayı geçti ve durduruldu.');
        }
        received += bytes.length;
        if (received > 180 * 1024 * 1024) {
          throw const FormatException('Ses verisi beklenenden büyük; işlem durduruldu.');
        }
        sink.add(bytes);
        final now = DateTime.now();
        if (now.difference(lastUiTick).inMilliseconds >= 400 ||
            (info.size.totalBytes > 0 && received >= info.size.totalBytes)) {
          lastUiTick = now;
          final mb = (received / (1024 * 1024)).toStringAsFixed(1);
          onStatus('2/4 · Ses indiriliyor: $mb MB');
          if (info.size.totalBytes > 0) {
            onProgress((received / info.size.totalBytes).clamp(0.0, 1.0));
          }
        }
      }
      await sink.flush();
    } on TimeoutException {
      rethrow;
    } on SocketException catch (e) {
      throw FormatException('YouTube bağlantısı kesildi: ${e.message}');
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
