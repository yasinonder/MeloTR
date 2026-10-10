import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'download_control.dart';

/// Alternative HTTP transport for an already discovered, signed HTTPS
/// Googlevideo audio URL. No scraping, tokens, cookies, or access bypass.
/// Triggered only when the existing library returns zero bytes and a
/// diagnostic Range request confirms the media endpoint responds.
class SignedAudioTransfer {
  static const int chunkBytes = 4 * 1024 * 1024;

  static bool isSupported(Uri uri) {
    final host = uri.host.toLowerCase();
    return uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        (host == 'googlevideo.com' || host.endsWith('.googlevideo.com'));
  }

  static ({int start, int end, int? total})? parseContentRange(String? value) {
    if (value == null) return null;
    final m = RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$').firstMatch(value);
    if (m == null) return null;
    final start = int.parse(m.group(1)!);
    final end = int.parse(m.group(2)!);
    final total = m.group(3) == '*' ? null : int.parse(m.group(3)!);
    if (start < 0 || end < start || (total != null && end >= total)) {
      return null;
    }
    return (start: start, end: end, total: total);
  }

  /// Downloads only audio from a pre-authorized media URL. Cancelling closes
  /// the active socket and leaves cleanup to the caller's temporary job.
  Future<int> download({
    required Uri uri,
    required File destination,
    required DownloadControl cancellation,
    required int byteLimit,
    required int expectedBytes,
    required void Function(int received, int? expected) onUpdate,
  }) async {
    if (!isSupported(uri)) {
      throw const FormatException('Ses bağlantısı güvenli Googlevideo adresi değil.');
    }
    if (byteLimit < 1024) {
      throw const FormatException('Mobil veri sınırı dolmuş.');
    }
    if (expectedBytes > byteLimit) {
      throw const FormatException('Ses dosyası mobil veri sınırını aşıyor.');
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 10)
      ..autoUncompress = false;
    cancellation.registerStop(() async { client.close(force: true); });

    var downloaded = 0;
    int? total = expectedBytes > 0 ? expectedBytes : null;
    final startTime = DateTime.now();
    final output = destination.openWrite();
    var successful = false;

    try {
      // Chunked Range fetching is bounded by the data profile (20–60 MB).
      // This avoids relying on the third-party stream iterator which gave 0 B.
      for (var requestNumber = 0; requestNumber < 64; requestNumber++) {
        cancellation.check();
        if (DateTime.now().difference(startTime) >
            const Duration(minutes: 3)) {
          throw TimeoutException('HTTP ses aktarımı 3 dakikayı geçti.');
        }
        if (total != null && downloaded >= total) {
          successful = true;
          break;
        }

        final until = math.min(
          downloaded + chunkBytes - 1,
          math.min(byteLimit, total ?? byteLimit) - 1,
        );
        if (until < downloaded) break;
        final request = await cancellation.untilCancelled(
          client.getUrl(uri).timeout(const Duration(seconds: 9)),
        );
        request.followRedirects = false;
        request.headers.set(HttpHeaders.rangeHeader,
            'bytes=' + downloaded.toString() + '-' + until.toString());
        request.headers.set(HttpHeaders.acceptHeader, '*/*');
        final response = await cancellation.untilCancelled(
          request.close().timeout(const Duration(seconds: 12)),
        );

        if (response.statusCode == 401 ||
            response.statusCode == 403 ||
            response.statusCode == 429) {
          throw HttpException(
              'Ses sunucusu HTTP ' + response.statusCode.toString() +
              ' erişim kısıtı uyguladı.');
        }
        if (response.statusCode != 206 &&
            !(response.statusCode == 200 && downloaded == 0)) {
          throw HttpException('Beklenmeyen ses yanıtı: HTTP ' +
              response.statusCode.toString());
        }
        final mediaType = response.headers.contentType?.mimeType ?? '';
        if (mediaType == 'text/html' || mediaType.contains('json')) {
          throw const FormatException('Ses yerine HTML/JSON yanıtı geldi.');
        }

        final range = response.statusCode == 206
            ? parseContentRange(
                response.headers.value(HttpHeaders.contentRangeHeader))
            : null;
        if (response.statusCode == 206 &&
            (range == null || range.start != downloaded)) {
          throw const FormatException('Ses dosyasının HTTP aralık bilgisi geçersiz.');
        }
        if (range?.total != null) {
          total = range!.total;
          if (total! > byteLimit) {
            throw const FormatException('Ses dosyası mobil veri sınırını aşıyor.');
          }
        }

        final offsetAtRequest = downloaded;
        // Do not hold entire file in RAM, write each received chunk to disk.
        final iterator = StreamIterator<List<int>>(
          response.timeout(const Duration(seconds: 12)),
        );
        try {
          while (await cancellation.untilCancelled(
              iterator.moveNext().timeout(const Duration(seconds: 14)))) {
            cancellation.check();
            final bytes = iterator.current;
            downloaded += bytes.length;
            if (downloaded > byteLimit) {
              throw const FormatException('Mobil veri sınırı aşıldı.');
            }
            if (total != null && downloaded > total) {
              throw const FormatException('HTTP verisi belirtilen boyuttan fazla.');
            }
            output.add(bytes);
            onUpdate(downloaded, total);
          }
        } finally {
          await iterator.cancel()
              .timeout(const Duration(seconds: 5), onTimeout: () {});
        }
        if (downloaded == offsetAtRequest) {
          throw const FormatException('HTTP başarılı görünüyor fakat ses verisi gelmedi.');
        }
        if (range != null && downloaded != range.end + 1) {
          throw const FormatException('Ses aktarımı eksik HTTP aralığı döndürdü.');
        }
        if (response.statusCode == 200) {
          // A 200 response to Range must contain the complete file.
          if (total == null || downloaded == total) {
            successful = true;
            break;
          }
          throw const FormatException('Sunucu aralık isteğini yok saydı; dosya eksik.');
        }
        if (total != null && downloaded >= total) {
          successful = true;
          break;
        }
      }
      if (!successful || downloaded < 1024) {
        throw const FormatException('Ses dosyası tamamlanamadı.');
      }
      await output.flush();
      return downloaded;
    } finally {
      await output.close();
      cancellation.registerStop(null);
      client.close(force: true);
    }
  }
}
