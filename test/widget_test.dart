import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
 testWidgets('MeloTR app label works',(tester) async {
  await tester.pumpWidget(const MaterialApp(home:Scaffold(body:Text('MeloTR'))));
  expect(find.text('MeloTR'),findsOneWidget);
 });
}
