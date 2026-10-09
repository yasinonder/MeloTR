import 'package:flutter_test/flutter_test.dart';
import 'package:melotr/music_library.dart';

void main() {
  test('süre gösterimi', () {
    expect(fmtDuration(const Duration(seconds: 7)), '0:07');
    expect(fmtDuration(const Duration(seconds: 198)), '3:18');
  });
  test('eksik etiketleri okunabilir yapar', () {
    expect(readableArtist('<unknown>'), 'Bilinmeyen sanatçı');
    expect(readableAlbum(null), 'Bilinmeyen albüm');
    expect(readableArtist('Duman'), 'Duman');
  });
}
