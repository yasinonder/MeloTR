import 'package:flutter_test/flutter_test.dart';
import 'package:melotr/youtube_music_service.dart';

void main() {
  test('direct YouTube URL uses video ID, ignoring share parameters', () {
    expect(
      YoutubeMusicService.videoIdFromInput(
        'https://youtu.be/IPm8zgyDM5U?si=1uYzoPWKSYrmsfUh',
      ),
      'IPm8zgyDM5U',
    );
  });
  test('regular music search is not mistaken for a URL', () {
    expect(YoutubeMusicService.videoIdFromInput('Türkçe rock müzik'), null);
  });
  test('non-YouTube links are not interpreted as a YouTube video', () {
    expect(
      YoutubeMusicService.videoIdFromInput('https://example.com/music.mp4'),
      null,
    );
  });
}
