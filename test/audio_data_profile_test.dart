import 'package:flutter_test/flutter_test.dart';
import 'package:melotr/audio_data_profile.dart';

class Source {
  const Source(this.kbps, this.codec, this.bytes);
  final int kbps;
  final String codec;
  final int bytes;
}

void main() {
  final sources = [
    const Source(64, 'opus', 1900000),
    const Source(96, 'opus', 2800000),
    const Source(128, 'aac', 3900000),
    const Source(160, 'opus', 4800000),
    const Source(256, 'aac', 7600000),
  ];

  List<Source> rank(AudioDataProfile profile) =>
      rankAudioByDataCost<Source>(
        streams: sources,
        profile: profile,
        bitrateBitsPerSecond: (s) => s.kbps * 1000,
        sizeBytes: (s) => s.bytes,
        audioCodec: (s) => s.codec,
      );

  test('data saver prefers lower-bitrate efficient audio', () {
    expect(rank(AudioDataProfile.saver).first.kbps, 64);
  });

  test('balanced profile uses efficient ~96 kbps source', () {
    expect(rank(AudioDataProfile.balanced).first.kbps, 96);
  });

  test('quality profile aims for ~160 kbps source', () {
    expect(rank(AudioDataProfile.quality).first.kbps, 160);
  });

  test('larger MP3 files do not affect downloaded source estimate', () {
    final profile = AudioDataProfile.balanced;
    final result = profile.estimatedMegaBytes(const Duration(minutes:4));
    expect(result, greaterThan(2));
    expect(result, lessThan(3.5));
    expect(profile.outputMp3Kbps, 160);
  });

  test('download ceilings are finite on mobile data', () {
    expect(AudioDataProfile.saver.downloadLimitBytes,
        lessThan(AudioDataProfile.balanced.downloadLimitBytes));
    expect(AudioDataProfile.balanced.downloadLimitBytes,
        lessThan(AudioDataProfile.quality.downloadLimitBytes));
  });

  test('a source over profile cap is deprioritized', () {
    expect(rank(AudioDataProfile.saver).first.kbps, lessThan(100));
    expect(rank(AudioDataProfile.balanced).last.kbps, 256);
  });
}
