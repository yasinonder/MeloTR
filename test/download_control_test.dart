import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:melotr/download_control.dart';

void main() {
  test('cancel unblocks a stalled request', () async {
    final control = DownloadControl();
    final hung = Completer<String>();
    final result = control.untilCancelled(hung.future);
    await control.cancel();
    await expectLater(result, throwsA(isA<DownloadCancelled>()));
    expect(control.isCancelled, isTrue);
  });

  test('cancel invokes current stop callback', () async {
    final control = DownloadControl();
    var closed = false;
    control.registerStop(() async { closed = true; });
    await control.cancel();
    expect(closed, isTrue);
    expect(() => control.check(), throwsA(isA<DownloadCancelled>()));
  });

  test('the final media-save stage cannot be cancelled', () async {
    final control = DownloadControl();
    control.startFinalizing();
    await control.cancel();
    expect(control.isCancelled, isFalse);
  });
}
