import 'package:flutter_test/flutter_test.dart';
import 'package:melotr/audio_stream_diagnostics.dart';

void main() {
  test('403 indicates access blocked, not MP3 conversion failure', () {
    expect(AudioStreamDiagnostic.describe(403), contains('HTTP 403'));
    expect(const AudioStreamDiagnostic(403, '').accessBlocked, isTrue);
    expect(const AudioStreamDiagnostic(206, '').accessBlocked, isFalse);
  });

  test('429 indicates rate limit', () {
    expect(AudioStreamDiagnostic.describe(429), contains('çok fazla istek'));
  });

  test('206 makes no false download success claim', () {
    expect(AudioStreamDiagnostic.describe(206), contains('aktaramadı'));
  });

  test('diagnostics refuse unrelated hosts', () async {
    final diagnosis = await diagnoseAudioStream(
        Uri.parse('https://example.com/video.mp4'));
    expect(diagnosis.statusCode, isNull);
    expect(diagnosis.detail, contains('uygun değil'));
  });
}
