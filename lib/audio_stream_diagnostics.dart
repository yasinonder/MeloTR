import 'dart:async';
import 'dart:io';

/// HTTP status from an actual media download, not an MP3 conversion failure.
class AudioAccessDenied implements Exception {
  const AudioAccessDenied(this.statusCode);
  final int statusCode;
  String get userMessage => statusCode == 429
      ? 'Ses sunucusu çok fazla istek nedeniyle erişimi kısıtladı (429).'
      : 'Ses sunucusu HTTP $statusCode erişimini reddetti. '
        'MP3 kalitesini değiştirmek erişim engelini çözmez.';
  @override
  String toString() => 'AudioAccessDenied($statusCode)';
}

/// A *diagnostic* HTTP Range request made only after an audio stream failed
/// without receiving any bytes. Never probes user-supplied arbitrary hosts.
class AudioStreamDiagnostic {
  const AudioStreamDiagnostic(this.statusCode, this.detail);

  final int? statusCode;
  final String detail;

  static String describe(int code) {
    switch (code) {
      case 401:
      case 403:
        return 'Ses sunucusu HTTP $code erişim engeli verdi. '
            'Bu video bağlantısı indirmeye açık olmayabilir.';
      case 404:
      case 410:
        return 'Ses dosyası bağlantısı HTTP $code ile geçersiz görünüyor.';
      case 429:
        return 'Ses sunucusu HTTP 429: çok fazla istek, erişim geçici kısıtlanmış.';
      case 200:
      case 206:
        return 'Tanı isteği HTTP $code döndürdü; '
            'indirme kütüphanesi yine de ses verisi aktaramadı.';
      default:
        return 'Ses sunucusundan HTTP $code yanıtı alındı.';
    }
  }

  bool get accessBlocked =>
      statusCode == 401 || statusCode == 403 || statusCode == 429;
}

/// Sends at most a 1-byte Range request after a *failed* media transfer.
/// This does not bypass access rules or obtain protected streams.
/// Result is diagnostic only: different request headers may produce different
/// responses than the third-party downloader's original HTTP request.
Future<AudioStreamDiagnostic> diagnoseAudioStream(Uri uri) async {
  final host = uri.host.toLowerCase();
  if (uri.scheme != 'https' ||
      (host != 'googlevideo.com' && !host.endsWith('.googlevideo.com'))) {
    return const AudioStreamDiagnostic(null,
        'Ses akışı URL adresi tanı isteği için uygun değil.');
  }

  final http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 5);
  try {
    final request = await http.getUrl(uri)
        .timeout(const Duration(seconds: 6));
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');
    final response = await request.close()
        .timeout(const Duration(seconds: 6));
    return AudioStreamDiagnostic(
        response.statusCode,
        AudioStreamDiagnostic.describe(response.statusCode));
  } on TimeoutException {
    return const AudioStreamDiagnostic(null,
        'Tanı isteği zaman aşımına uğradı; ses sunucusu yanıt vermiyor.');
  } on SocketException {
    return const AudioStreamDiagnostic(null,
        'Tanı isteği sırasında bağlantı sağlanamadı.');
  } on HandshakeException {
    return const AudioStreamDiagnostic(null,
        'Tanı isteğinde HTTPS güvenli bağlantı kurulamadı.');
  } on HttpException {
    return const AudioStreamDiagnostic(null,
        'Tanı isteği HTTP bağlantı hatası verdi.');
  } finally {
    http.close(force: true);
  }
}
