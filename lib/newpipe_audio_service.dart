import 'dart:async';
import 'dart:io';

import 'package:newpipeextractor_dart/newpipeextractor_dart.dart' as np;
import 'package:path_provider/path_provider.dart';

import 'audio_data_profile.dart';
import 'audio_stream_diagnostics.dart';
import 'download_control.dart';
import 'mp3_import_service.dart';
import 'signed_audio_transfer.dart';

/// Experimental native Android extractor used alongside the legacy engine.
/// Media hosts may deny downloads; this is not an access-control bypass.
class NewPipeAudioService {
  final Mp3ImportService _converter = Mp3ImportService();

  static String extensionFor(String? value) {
    final ext = (value ?? '').toLowerCase().trim();
    return const {'webm', 'm4a', 'ogg', 'mp3', 'opus', 'aac'}.contains(ext)
        ? ext
        : 'm4a';
  }

  static List<np.AudioOnlyStream> preferredSources(
      Iterable<np.AudioOnlyStream> sources, AudioDataProfile profile) {
    return rankAudioByDataCost<np.AudioOnlyStream>(
      streams: sources,
      profile: profile,
      bitrateBitsPerSecond: (s) => s.averageBitrate * 1000,
      sizeBytes: (s) => s.size ?? 0,
      audioCodec: (s) => s.formatMimeType ?? s.formatSuffix ?? '',
    ).where((s) => s.url != null && s.url!.isNotEmpty).take(3).toList();
  }

  Future<String> saveMp3({
    required String videoId,
    required String title,
    required Duration? duration,
    required AudioDataProfile profile,
    required void Function(String) onStatus,
    required void Function(double) onProgress,
    required DownloadControl cancellation,
  }) async {
    onStatus('1/4 · NewPipe ses bağlantısı aranıyor…');
    final streams = await cancellation.untilCancelled(
      np.VideoExtractor.getAudioOnlyStreams(
        'https://www.youtube.com/watch?v=' + videoId,
      ).timeout(const Duration(seconds: 40)),
    );
    cancellation.check();
    final candidates = preferredSources(streams, profile);
    if (candidates.isEmpty) {
      throw const FormatException('NewPipe kullanılabilir ses bulamadı.');
    }

    final root = await getApplicationSupportDirectory();
    final job = Directory(root.path + '/melotr_jobs/np_' +
        DateTime.now().microsecondsSinceEpoch.toString());
    await job.create(recursive: true);
    var receivedTotal = 0;
    Object? lastFailure;
    try {
      for (var i = 0; i < candidates.length; i++) {
        cancellation.check();
        final source = candidates[i];
        final uri = Uri.tryParse(source.url!);
        if (uri == null || !SignedAudioTransfer.isSupported(uri)) {
          lastFailure = const FormatException(
            'Bu akışın medya sunucusu desteklenen HTTPS adresi değil.');
          continue;
        }
        final knownSize = source.size ?? 0;
        final estimated = knownSize > 0
            ? knownSize / (1024 * 1024)
            : profile.estimatedMegaBytes(duration);
        if (estimated > profile.downloadLimitMegabytes) {
          throw FormatException('Tahmini ses dosyası ' +
              estimated.toStringAsFixed(1) + ' MB; mobil veri sınırı aşılıyor.');
        }
        final file = File(job.path + '/sound_' + i.toString() +
            '.' + extensionFor(source.formatSuffix));
        final indexLabel = (i + 1).toString() + '/' +
            candidates.length.toString();
        onStatus('2/4 · NewPipe ' + indexLabel + ' · ~' +
            estimated.toStringAsFixed(1) + ' MB');
        onProgress(0);
        var counted = 0;
        try {
          await SignedAudioTransfer().download(
            uri: uri,
            destination: file,
            cancellation: cancellation,
            byteLimit: profile.downloadLimitBytes - receivedTotal,
            expectedBytes: knownSize,
            onUpdate: (bytes, expected) {
              if (bytes > counted) {
                receivedTotal += bytes - counted;
                counted = bytes;
              }
              onStatus('2/4 · NewPipe ' + indexLabel + ' · ' +
                  (bytes / (1024 * 1024)).toStringAsFixed(2) + ' MB');
              if (expected != null && expected > 0) {
                onProgress((bytes / expected).clamp(0.0, 1.0));
              }
            },
          );
          cancellation.check();
          onProgress(1);
          return await _converter.fromAppTemporaryMedia(
            mediaFile: file,
            title: title,
            kbps: profile.outputMp3Kbps,
            onStatus: onStatus,
            cancellation: cancellation,
          );
        } on DownloadCancelled {
          rethrow;
        } on AudioAccessDenied {
          // Do not retry a denied origin and waste mobile data.
          rethrow;
        } catch (e) {
          lastFailure = e;
          if (counted >= 256 * 1024 ||
              receivedTotal >= profile.downloadLimitBytes) {
            throw FormatException(
                'Veri koruması: büyük bir aktarım başarısız. ' +
                'Tekrar indirme yapılmadı. Son hata: ' + e.toString());
          }
          onStatus('2/4 · Kaynak başarısız, alternatif ses deneniyor…');
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {}
        }
      }
      throw FormatException('NewPipe ses akışları indirilemedi: ' +
          lastFailure.toString());
    } finally {
      try {
        if (await job.exists()) await job.delete(recursive: true);
      } catch (_) {}
    }
  }
}
