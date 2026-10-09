import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Temel arayüz metni görüntülenebilir', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('MeloTR'))),
    ));
    expect(find.text('MeloTR'), findsOneWidget);
  });
}
