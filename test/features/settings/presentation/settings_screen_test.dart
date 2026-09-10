import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/settings/application/app_info_provider.dart';
import 'package:vocechat_client/features/settings/application/server_version_provider.dart';
import 'package:vocechat_client/features/settings/presentation/avo_settings_screen.dart';
import 'package:vocechat_client/features/settings/presentation/settings_screen.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final width in [390.0, 1000.0]) {
    testWidgets('AVO opens only from its own menu at width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_RegularAuthController.new),
          serverStoreProvider.overrideWith(_TestServerStore.new),
        ],
        child: _localizedApp(),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(AvoSettingsCard), findsNothing);

      await tester.tap(find.text('AVO'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AvoSettingsCard), findsOneWidget);
      expect(find.byKey(const Key('avo-name')), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (width < 700) {
        await tester.tap(find.byIcon(Icons.arrow_back));
      } else {
        await tester.tap(find.text('My Account'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(AvoSettingsCard), findsNothing);
    });

    for (final fail in [false, true]) {
      testWidgets('About loads server version (failure=$fail) at width $width',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final serverVersion = Completer<String>();

        await tester.pumpWidget(ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_RegularAuthController.new),
            serverStoreProvider.overrideWith(_TestServerStore.new),
            appPackageInfoProvider.overrideWith((ref) async => PackageInfo(
                  appName: 'VoceChat',
                  packageName: 'chat.voce',
                  version: '0.3.21',
                  buildNumber: '21',
                )),
            serverVersionProvider.overrideWith((ref) => serverVersion.future),
          ],
          child: _localizedApp(),
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.text('About').last);
        await tester.pumpAndSettle();
        expect(find.text('SERVER VERSION'), findsOneWidget);
        expect(find.text('…'), findsOneWidget);
        expect(find.text('0.3.21 (21)'), findsOneWidget);

        if (fail) {
          serverVersion.completeError(Exception('Server unavailable'));
        } else {
          serverVersion.complete('0.5.22');
        }
        await tester.pumpAndSettle();
        expect(find.text(fail ? '—' : '0.5.22'), findsOneWidget);
        expect(find.text('0.3.21 (21)'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('regular user can confirm account deletion', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_RegularAuthController.new),
        serverStoreProvider.overrideWith(_TestServerStore.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _localizedApp(),
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.text('Delete account');
    expect(deleteButton, findsOneWidget);

    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Delete this account?'), findsOneWidget);
    final confirmLabel = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete account'),
    );
    await tester.tap(confirmLabel);
    await tester.pump();

    final controller = container.read(authControllerProvider.notifier)
        as _RegularAuthController;
    expect(controller.deleteCalls, 1);
  });

  testWidgets('initial uid 1 account cannot be deleted', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_InitialAuthController.new),
          serverStoreProvider.overrideWith(_TestServerStore.new),
        ],
        child: _localizedApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete account'), findsNothing);
  });
}

Widget _localizedApp() {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: const Scaffold(body: SettingsScreen()),
  );
}

class _RegularAuthController extends AuthController {
  int deleteCalls = 0;

  @override
  Future<AuthState> build() async => const AuthState.authenticated(
        user: VoceUser(uid: 7, name: 'Regular user', email: 'user@example.com'),
      );

  @override
  Future<void> deleteCurrentAccount() async {
    deleteCalls++;
  }
}

class _InitialAuthController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.authenticated(
        user: VoceUser(uid: 1, name: 'Initial user'),
      );
}

class _TestServerStore extends ServerStore {
  @override
  Future<ServerState> build() async => const ServerState(
        servers: [
          ServerConfig(
            id: 'server',
            baseUrl: 'https://chat.example.com',
            name: 'Test server',
          ),
        ],
        currentServerId: 'server',
      );
}
