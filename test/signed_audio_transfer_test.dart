import 'package:flutter_test/flutter_test.dart';
import 'package:melotr/signed_audio_transfer.dart';

void main() {
  test('requires signed HTTPS googlevideo hostname', () {
    expect(SignedAudioTransfer.isSupported(
        Uri.parse('https://rr1---sn-a.googlevideo.com/videoplayback?id=abc')),
        isTrue);
    expect(SignedAudioTransfer.isSupported(
        Uri.parse('https://notgooglevideo.com/videoplayback')), isFalse);
    expect(SignedAudioTransfer.isSupported(
        Uri.parse('http://rr1.googlevideo.com/videoplayback')), isFalse);
    expect(SignedAudioTransfer.isSupported(
        Uri.parse('https://googlevideo.com.evil.test/media')), isFalse);
  });

  test('parses valid partial content ranges', () {
    final r = SignedAudioTransfer.parseContentRange('bytes 0-1023/4096');
    expect(r?.start, 0);
    expect(r?.end, 1023);
    expect(r?.total, 4096);
    expect(SignedAudioTransfer.parseContentRange('bytes 400-300/4096'), isNull);
    expect(SignedAudioTransfer.parseContentRange('bytes 0-4096/4096'), isNull);
    expect(SignedAudioTransfer.parseContentRange('not a range'), isNull);
  });
}
