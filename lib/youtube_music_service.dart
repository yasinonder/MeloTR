import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'download_control.dart';
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
    required DownloadControl cancellation,
  }) async {
    onStatus('1/4 · YouTube ses bilgisi alınıyor…');
    // Manifest requests can hang or be blocked by YouTube.
    final manifest = await cancellation.untilCancelled(
      _youtube.videos.streams.getManifest(video.id)
        .timeout(
          const Duration(seconds:35),
          onTimeout: () => throw TimeoutException(
            'YouTube ses bilgisine 35 saniyede yanıt vermedi. '
            'Başka bir video veya bağlantı deneyin.',
          ),
        ),
    );
    cancellation.check();
    if (manifest.audioOnly.isEmpty) {
      throw const FormatException('Bu video için indirilebilir ses bulunamadı.');
    }
    // If one stream is rejected, automatically try a different sound format.
    final choices = manifest.audioOnly.sortByBitrate().take(3).toList();
    final root = await getApplicationSupportDirectory();
    final tempDir = Directory(root.path + '/melotr_jobs/yt_' +
        DateTime.now().microsecondsSinceEpoch.toString());
    await tempDir.create(recursive: true);
    Object? lastFailure;

    try {
      for (var attempt = 0; attempt < choices.length; attempt++) {
        cancellation.check();
        final streamInfo = choices[attempt];
        final attemptLabel = (attempt + 1).toString() + '/' +
            choices.length.toString();
        final input = File(tempDir.path + '/source_' + attempt.toString() +
            '.' + streamInfo.container.name);
        onStatus('2/4 · Ses kaynağı ' + attemptLabel + ' deneniyor…');
        onProgress(0);
        try {
          final sink = input.openWrite();
          final began = DateTime.now();
          var lastTick = DateTime.fromMillisecondsSinceEpoch(0);
          var received = 0;
          try {
            final bytesStream = _youtube.videos.streams.get(streamInfo)
                .timeout(
              const Duration(seconds:18),
              onTimeout: (events) => events.addError(
                TimeoutException('18 saniyedir ses verisi alınamadı')),
            );
            final iterator = StreamIterator<List<int>>(bytesStream);
            cancellation.registerStop(() => iterator.cancel());
            try {
              while (await cancellation.untilCancelled(iterator.moveNext())) {
                cancellation.check();
                if (DateTime.now().difference(began) >
                    const Duration(minutes:2)) {
                  throw TimeoutException('Bu ses akışı iki dakikayı aştı');
                }
                final chunk = iterator.current;
                received += chunk.length;
                if (received > 180 * 1024 * 1024) {
                  throw const FormatException('Ses akışı 180 MB sınırını aştı');
                }
                sink.add(chunk);
                final now = DateTime.now();
                if (now.difference(lastTick).inMilliseconds >= 500 ||
                    (streamInfo.size.totalBytes > 0 &&
                        received >= streamInfo.size.totalBytes)) {
                  lastTick = now;
                  final amount = (received / (1024 * 1024))
                      .toStringAsFixed(1);
                  onStatus('2/4 · Akış ' + attemptLabel +
                      ' · ' + amount + ' MB indirildi');
                  if (streamInfo.size.totalBytes > 0) {
                    onProgress((received / streamInfo.size.totalBytes)
                        .clamp(0.0, 1.0));
                  }
                }
              }
              cancellation.check();
              await sink.flush();
            } finally {
              cancellation.registerStop(null);
              await iterator.cancel()
                  .timeout(const Duration(seconds:5), onTimeout: () {});
            }
          } finally {
            await sink.close();
          }
          cancellation.check();
          if (!await input.exists() || await input.length() < 1024) {
            throw const FormatException('Ses akışı boş veya eksik');
          }
        } on DownloadCancelled {
          rethrow;
        } catch (e) {
          lastFailure = e;
          onStatus('2/4 · Akış ' + attemptLabel +
              ' başarısız. Alternatif deneniyor…');
          // An incomplete file has no usable audio; remove just this copy.
          try {
            if (await input.exists()) await input.delete();
          } catch (_) {}
          continue;
        }
        onProgress(1.0);
        // If conversion fails, retain this complete temporary input
        // for diagnostics. The converter deletes it only on MP3 success.
        return await _converter.fromAppTemporaryMedia(
          mediaFile: input,
          title: video.title,
          kbps: kbps,
          onStatus: onStatus,
          cancellation: cancellation,
        );
      }
      throw FormatException('Bu videodan ses alınamadı. ' +
          choices.length.toString() +
          ' akış denendi. Son hata: ' + lastFailure.toString());
    } on DownloadCancelled {
      try {
        if (await tempDir.exists()) await tempDir.delete(recursive:true);
      } catch (_) {}
      rethrow;
    }
  }

  void dispose() => _youtube.close();
}
