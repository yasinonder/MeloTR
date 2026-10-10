import 'package:flutter_test/flutter_test.dart';
import 'package:newpipeextractor_dart/newpipeextractor_dart.dart' as np;
import 'package:melotr/audio_data_profile.dart';
import 'package:melotr/newpipe_audio_service.dart';

void main() {
  np.AudioOnlyStream source(int bitrate, String format) =>
      np.AudioOnlyStream(null,
          'https://rr1.googlevideo.com/videoplayback', bitrate,
          format, format, 'audio/' + format);

  test('audio selection responds to data saving profiles', () {
    final streams = [
      source(160, 'webm'),
      source(64, 'webm'),
      source(96, 'm4a'),
    ];
    expect(NewPipeAudioService.preferredSources(
        streams, AudioDataProfile.saver).first.averageBitrate, 64);
    expect(NewPipeAudioService.preferredSources(
        streams, AudioDataProfile.balanced).first.averageBitrate, 96);
    expect(NewPipeAudioService.preferredSources(
        streams, AudioDataProfile.quality).first.averageBitrate, 160);
  });

  test('file extensions are restricted to safe audio containers', () {
    expect(NewPipeAudioService.extensionFor('webm'), 'webm');
    expect(NewPipeAudioService.extensionFor('bad/../png'), 'm4a');
  });
}
