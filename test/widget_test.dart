import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fine_ants_mobile/main.dart';
import 'package:fine_ants_mobile/src/services/account_store.dart';

void main() {
  testWidgets('Shows account setup when no accounts', (tester) async {
    final tmp = await Directory.systemTemp.createTemp('fine_ants_test_');
    await AccountStore.initialize(tmp.path);

    await tester.pumpWidget(const MyApp());
    // Allow FutureBuilder to resolve load()
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
  });
}
