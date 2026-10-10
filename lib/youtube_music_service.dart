import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'download_control.dart';
import 'audio_stream_diagnostics.dart';
import 'signed_audio_transfer.dart';
import 'audio_data_profile.dart';
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
    required AudioDataProfile profile,
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
    final choices = rankAudioByDataCost<AudioOnlyStreamInfo>(
      streams: manifest.audioOnly,
      profile: profile,
      bitrateBitsPerSecond: (s) => s.bitrate.bitsPerSecond,
      sizeBytes: (s) => s.size.totalBytes,
      audioCodec: (s) => s.audioCodec,
    ).take(3).toList();
    final root = await getApplicationSupportDirectory();
    final tempDir = Directory(root.path + '/melotr_jobs/yt_' +
        DateTime.now().microsecondsSinceEpoch.toString());
    await tempDir.create(recursive: true);
    Object? lastFailure;
    var totalDownloadedBytes = 0;

    try {
      for (var attempt = 0; attempt < choices.length; attempt++) {
        cancellation.check();
        final streamInfo = choices[attempt];
        final attemptLabel = (attempt + 1).toString() + '/' +
            choices.length.toString();
        final input = File(tempDir.path + '/source_' + attempt.toString() +
            '.' + streamInfo.container.name);
        final predictedMb = streamInfo.size.totalBytes > 0
            ? streamInfo.size.totalBytes / (1024 * 1024)
            : profile.estimatedMegaBytes(video.duration);
        if (predictedMb > profile.downloadLimitMegabytes) {
          throw FormatException('Sesin tahmini boyutu ' +
              predictedMb.toStringAsFixed(1) + ' MB. ' +
              profile.label + ' profilinin ' +
              profile.downloadLimitMegabytes.toString() +
              ' MB veri sınırı aşılıyor.');
        }
        onStatus('2/4 · Akış ' + attemptLabel + ' · yaklaşık ' +
            predictedMb.toStringAsFixed(1) + ' MB · ' +
            profile.label);
        onProgress(0);
        var received = 0;
        try {
          final sink = input.openWrite();
          final began = DateTime.now();
          var lastTick = DateTime.fromMillisecondsSinceEpoch(0);
          try {
            final bytesStream = _youtube.videos.streams.get(streamInfo)
                .timeout(
              const Duration(seconds:12),
              onTimeout: (events) => events.addError(
                TimeoutException('12 saniyedir ilk ses verisi alınamadı')),
            );
            final iterator = StreamIterator<List<int>>(bytesStream);
            cancellation.registerStop(() => iterator.cancel());
            try {
              while (await cancellation.untilCancelled(
                  iterator.moveNext().timeout(const Duration(seconds:14),
                    onTimeout: () => throw TimeoutException(
                      '14 saniyedir sunucudan ses paketi alınamadı')),
                )) {
                cancellation.check();
                if (DateTime.now().difference(began) >
                    const Duration(minutes:2)) {
                  throw TimeoutException('Bu ses akışı iki dakikayı aştı');
                }
                final chunk = iterator.current;
                received += chunk.length;
                totalDownloadedBytes += chunk.length;
                if (totalDownloadedBytes > profile.downloadLimitBytes) {
                  throw FormatException('Mobil veri sınırı aşıldı (' +
                      profile.downloadLimitMegabytes.toString() + ' MB). ' +
                      'Aktarım otomatik durduruldu.');
                }
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
          Object failure = e;
          if (received == 0) {
            // An independent Range request reveals common HTTP access errors.
            // The original library exception may hide the actual status.
            onStatus('2/4 · Akış ' + attemptLabel +
                ' · %0: HTTP erişimi kontrol ediliyor…');
            final check = await cancellation.untilCancelled(
              diagnoseAudioStream(streamInfo.url));
            cancellation.check();
            failure = FormatException(e.toString() + ' | ' + check.detail);
            // A 200/206 Range probe confirms an HTTP response. Try a direct
            // bounded, cancellable download of the *existing* signed audio
            // URL instead of repeating the stalled third-party stream reader.
            if (check.statusCode == 200 || check.statusCode == 206) {
              onStatus('2/4 · Akış ' + attemptLabel +
                  ' · Alternatif HTTP aktarımı başlıyor…');
              var fallbackCountedBytes = 0;
              try {
                await SignedAudioTransfer().download(
                  uri: streamInfo.url,
                  destination: input,
                  cancellation: cancellation,
                  byteLimit: profile.downloadLimitBytes - totalDownloadedBytes,
                  expectedBytes: streamInfo.size.totalBytes,
                  onUpdate: (amount, expected) {
                    if (amount > fallbackCountedBytes) {
                      totalDownloadedBytes += amount - fallbackCountedBytes;
                      fallbackCountedBytes = amount;
                    }
                    final mb = (amount / (1024 * 1024)).toStringAsFixed(2);
                    onStatus('2/4 · Alternatif HTTP · ' + mb + ' MB indirildi');
                    if (expected != null && expected > 0) {
                      onProgress((amount / expected).clamp(0.0, 1.0));
                    }
                  },
                );
                received = fallbackCountedBytes;
                onStatus('2/4 · HTTP aktarımı tamamlandı, MP3 hazırlanıyor…');
                onProgress(1.0);
                return await _converter.fromAppTemporaryMedia(
                  mediaFile: input,
                  title: video.title,
                  kbps: profile.outputMp3Kbps,
                  onStatus: onStatus,
                  cancellation: cancellation,
                );
              } on DownloadCancelled {
                rethrow;
              } on AudioAccessDenied {
                // HTTP 403/401/429 is an origin access denial, not low quality.
                rethrow;
              } catch (httpError) {
                received = fallbackCountedBytes;
                failure = FormatException(
                    'Kütüphane aktarımı: ' + e.toString() +
                    ' | Doğrudan HTTP aktarımı: ' + httpError.toString());
              }
            }
            if (check.accessBlocked) {
              throw AudioAccessDenied(check.statusCode!);
            }
          }
          // Do not waste mobile data by downloading another full source
          // after substantial bytes have already been received.
          if (received >= 256 * 1024 ||
              totalDownloadedBytes >= profile.downloadLimitBytes) {
            throw FormatException(
                'Veri tasarrufu: ' +
                (totalDownloadedBytes / (1024 * 1024))
                    .toStringAsFixed(1) +
                ' MB kullanıldı. Aynı medya tekrar indirilmedi. ' +
                'Son hata: ' + e.toString());
          }
          lastFailure = failure;
          onStatus('2/4 · Akış ' + attemptLabel +
              ' erişilemedi. Düşük veri kaybıyla alternatif deneniyor…');
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
          kbps: profile.outputMp3Kbps,
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
