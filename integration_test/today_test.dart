import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lifeos/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline sample priority can be completed and reset', (tester) async {
    await tester.pumpWidget(const LifeApp());
    await tester.pumpAndSettle();
    final complete = find.byKey(const Key('complete-assignment'));
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 sample priorities complete'), findsOneWidget);
    final reset = find.byKey(const Key('reset-sample'));
    await tester.ensureVisible(reset);
    await tester.tap(reset);
    await tester.pumpAndSettle();
    expect(find.text('0 of 3 sample priorities complete'), findsOneWidget);
  });
}
