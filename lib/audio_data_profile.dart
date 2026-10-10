/// Data usage settings are for the downloaded audio *source*,
/// not the output MP3 bitrate. MP3 re-encoding never restores lost quality.
enum AudioDataProfile {
  saver('Veri tasarrufu', 64, 40, 96, 128, 20),
  balanced('Dengeli', 96, 64, 144, 160, 40),
  quality('Yüksek kalite', 160, 112, 192, 192, 60);

  const AudioDataProfile(
    this.label,
    this.targetSourceKbps,
    this.minimumSourceKbps,
    this.maximumSourceKbps,
    this.outputMp3Kbps,
    this.downloadLimitMegabytes,
  );

  final String label;
  final int targetSourceKbps;
  final int minimumSourceKbps;
  final int maximumSourceKbps;
  final int outputMp3Kbps;
  final int downloadLimitMegabytes;

  int get downloadLimitBytes => downloadLimitMegabytes * 1024 * 1024;

  /// This is an indicative estimate; actual streams may have other bitrates.
  double estimatedMegaBytes(Duration? duration) {
    if (duration == null) return 0;
    return duration.inSeconds * targetSourceKbps * 1000 /
        (8 * 1024 * 1024);
  }
}

/// The source stream ranking is independent of any one extract library.
/// It prioritizes efficient audio-only source formats over video streams.
List<T> rankAudioByDataCost<T>({
  required Iterable<T> streams,
  required AudioDataProfile profile,
  required int Function(T) bitrateBitsPerSecond,
  required int Function(T) sizeBytes,
  required String Function(T) audioCodec,
}) {
  double rank(T s) {
    final kbps = bitrateBitsPerSecond(s) / 1000;
    if (kbps <= 0) return 10000;
    var value = (kbps - profile.targetSourceKbps).abs();
    if (kbps > profile.maximumSourceKbps) {
      value += 200 + kbps - profile.maximumSourceKbps;
    } else if (kbps < profile.minimumSourceKbps) {
      value += 80 + profile.minimumSourceKbps - kbps;
    }
    final codec = audioCodec(s).toLowerCase();
    if (codec.contains('opus')) value -= 8;
    // Within the same quality tier, prefer fewer actual network bytes.
    final bytes = sizeBytes(s);
    if (bytes > 0) value += bytes / (1024 * 1024) * 0.1;
    return value;
  }

  final ranked = streams.toList();
  ranked.sort((a, b) => rank(a).compareTo(rank(b)));
  return ranked;
}
