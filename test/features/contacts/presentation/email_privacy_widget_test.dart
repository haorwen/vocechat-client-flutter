import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/auth/presentation/account_switcher_sheet.dart';
import 'package:vocechat_client/features/contacts/application/contacts_provider.dart';
import 'package:vocechat_client/features/contacts/presentation/contacts_screen.dart';
import 'package:vocechat_client/features/settings/presentation/settings_screen.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';
import 'package:vocechat_client/shared/widgets/voce_avatar.dart';

import '../../../support/email_privacy_fixture.dart';

Widget app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  testWidgets(
      'mounted desktop details hide immediately and restore without navigation',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = Fixture();
    await tester.runAsync(() => s.start());
    await tester.pumpWidget(UncontrolledProviderScope(
        container: s.container, child: app(const ContactsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Helper'));
    await tester.pumpAndSettle();
    expect(find.text('@helper'), findsOneWidget);
    s.fail = true;
    await tester.runAsync(() => s.config(true));
    await tester.pumpAndSettle();
    expect(find.text('@helper'), findsNothing);
    expect(find.text('#7'), findsOneWidget);
    expect(find.text('@'), findsNothing);
    expect(find.text('null'), findsNothing);
    expect(find.text('Helper'), findsNWidgets(2));
    s.fail = false;
    await tester.runAsync(() => s.config(false));
    await tester.pumpAndSettle();
    expect(find.text('@helper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [390.0, 1000.0]) {
    testWidgets('open avatar profile removes cached email at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = Fixture();
      await tester.runAsync(() => s.start());
      await tester.pumpWidget(UncontrolledProviderScope(
          container: s.container, child: app(const ContactsScreen())));
      await tester.pumpAndSettle();
      final avatar =
          find.byWidgetPredicate((w) => w is VoceAvatar && w.name == 'Helper');
      await tester.tap(avatar);
      await tester.pumpAndSettle();
      expect(find.text('helper@example.com'), findsOneWidget);
      s.fail = true;
      await tester.runAsync(() => s.config(true));
      await tester.pumpAndSettle();
      expect(find.text('helper@example.com'), findsNothing);
      expect(find.text('#7'), findsOneWidget);
      expect(find.text('@'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('server bot flag controls grouping even with null email',
      (tester) async {
    final s = Fixture();
    await tester.runAsync(() => s.start(initiallyHidden: true));
    // Exercise the rendered sections with an explicit false and a bot-like name.
    final container = ProviderContainer(overrides: [
      contactsProvider.overrideWith(BotContacts.new),
    ], parent: s.container);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: app(const ContactsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('BOT - 1'), findsOneWidget);
    expect(find.text('CONTACT - 1'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    expect(find.text('Helper'), findsOneWidget);
    expect(find.text('Robot enthusiast'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'My Account and account switcher consume the redacted live profile',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = Fixture();
    await tester.runAsync(() => s.start());
    await tester.pumpWidget(UncontrolledProviderScope(
        container: s.container, child: app(const SettingsScreen())));
    await tester.pumpAndSettle();
    expect(find.text(self.email!), findsOneWidget);
    s.fail = true;
    await tester.runAsync(() => s.config(true));
    await tester.pumpAndSettle();
    expect(find.text(self.email!), findsNothing);
    expect(find.text('—'), findsWidgets);
    // Open the same switcher used by Settings, while keeping it mounted.
    final context = tester.element(find.byType(SettingsScreen));
    showAccountSwitcherSheet(context);
    await tester.pumpAndSettle();
    expect(find.text('Self'), findsWidgets);
    expect(find.text(self.email!), findsNothing);
    expect(s.saved.email, isNull);
    expect(tester.takeException(), isNull);
  });
}

class BotContacts extends Contacts {
  @override
  Future<List<ContactInfo>> build() async => [
        ContactInfo.fromJson(
            {'uid': 7, 'name': 'Helper', 'email': null, 'is_bot': true}),
        ContactInfo.fromJson({
          'uid': 8,
          'name': 'Robot enthusiast',
          'email': null,
          'is_bot': false
        }),
      ];
}
