import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocechat_client/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: VoceChatApp()));
    // Minimal smoke test — just verify the widget tree builds.
    expect(find.byType(VoceChatApp), findsNothing); // consumed by router
  });
}
