import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MeloTube independently branded source tree', () {
    final config = File('pubspec.yaml').readAsStringSync();
    expect(config, contains('name: melotube'));
    expect(config, contains('version: 0.1.0+1'));

    final gradle = File('android/app/build.gradle').readAsStringSync();
    expect(gradle, contains('applicationId "com.melotube.player"'));

    final notice = File('MELOTUBE_CHANGES.md').readAsStringSync();
    expect(notice, contains('SongTube-derived'));
    expect(notice, contains('GPL-3.0'));

    final license = File('LICENSE').readAsStringSync();
    expect(license, contains('GNU GENERAL PUBLIC LICENSE'));
  });
}
