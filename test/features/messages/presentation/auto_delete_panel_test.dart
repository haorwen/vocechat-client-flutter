import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/features/messages/application/burn_after_read_provider.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/presentation/chat_tool_panels.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

class _Auth extends AuthController {
  _Auth(this.admin, this.uid);
  final bool admin;
  final int uid;
  @override
  Future<AuthState> build() async => AuthState.authenticated(
      user: VoceUser(uid: uid, name: 'User', isAdmin: admin));
}

class _Cache implements MessageCache {
  List<Map<String, dynamic>>? groups;
  @override
  Future<List<Map<String, dynamic>>?> readGroupDirectory() async => groups;
  @override
  Future<void> writeGroupDirectory(List<Map<String, dynamic>> groups) async {
    this.groups = groups;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<({ProviderContainer container, List<RequestOptions> requests})> open(
    WidgetTester tester, {
    bool admin = true,
    int uid = 1,
    int? channelSeconds = 300,
    int personalSeconds = 600,
    bool personalSupported = true,
    bool isChannel = true,
    int? cachedChannelSeconds,
    bool failSave = false,
  }) async {
    final group = <String, dynamic>{
      'gid': 42,
      'name': 'Channel',
      'owner': 2,
      if (channelSeconds != null) 'auto_delete_after': channelSeconds,
    };
    final cache = _Cache();
    if (cachedChannelSeconds != null) {
      cache.groups = [
        {...group, 'auto_delete_after': cachedChannelSeconds}
      ];
    }
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      if (failSave && options.method != 'GET') {
        handler.reject(DioException(requestOptions: options));
        return;
      }
      handler.resolve(Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: options.method == 'GET'
              ? (options.path == '/api/group' ? [group] : group)
              : null));
    }));
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWith((ref) => dio),
      messageCacheProvider.overrideWith((ref) async => cache),
      authControllerProvider.overrideWith(() => _Auth(admin, uid)),
    ]);
    addTearDown(() {
      container.dispose();
      dio.close();
    });
    container.read(burnAfterReadProvider.notifier).applySnapshot(
        {42: personalSeconds}, {42: personalSeconds},
        supportsUsers: personalSupported, supportsGroups: personalSupported);
    await tester.binding.setSurfaceSize(const Size(600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () => showChatToolOverlay(context,
                          tool: ChatTool.autoDelete,
                          targetId: 42,
                          isChannel: isChannel),
                      child: const Text('Open'),
                    ))),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return (container: container, requests: requests);
  }

  Future<void> showOption(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.text(label), 160,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    await showOption(tester, label);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  RadioListTile<int> radio(WidgetTester tester, String label) =>
      tester.widget<RadioListTile<int>>(find.ancestor(
          of: find.text(label), matching: find.byType(RadioListTile<int>)));

  testWidgets('admin defaults to channel and saves scopes independently',
      (tester) async {
    final result = await open(tester);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    expect(radio(tester, '5 minutes').groupValue, 300);
    await select(tester, '1 month (30 days)');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final channelSave = result.requests.lastWhere((r) => r.method == 'PUT');
    expect(channelSave.path, '/api/group/42');
    expect(channelSave.data, {'auto_delete_after': 2592000});
    expect(
        result.container.read(burnAfterReadProvider).groupExpiresIn(42), 600);
    expect(
        result.container
            .read(groupDirectoryProvider)
            .requireValue[42]
            ?.autoDeleteAfter,
        2592000);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(radio(tester, '10 minutes').groupValue, 600);
    await select(tester, '1 hour');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final personalSave = result.requests.lastWhere((r) => r.method == 'POST');
    expect(personalSave.path, '/api/user/burn-after-reading');
    expect(personalSave.data, {
      'groups': [
        {'gid': 42, 'expires_in': 3600}
      ]
    });
    expect(
        result.container
            .read(groupDirectoryProvider)
            .requireValue[42]
            ?.autoDeleteAfter,
        2592000);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await showOption(tester, '1 month (30 days)');
    expect(radio(tester, '1 month (30 days)').groupValue, 2592000);
  });

  testWidgets('old server disables channel switch but keeps one month personal',
      (tester) async {
    final result =
        await open(tester, channelSeconds: null, cachedChannelSeconds: 300);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.onChanged, isNull);
    expect(toggle.value, isFalse);
    expect(
        find.text(
            'The server does not support this option. Upgrade the server to enable it.'),
        findsOneWidget);
    await showOption(tester, '1 month (30 days)');
    expect(radio(tester, '1 month (30 days)').onChanged, isNotNull);
    await select(tester, '1 month (30 days)');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result.requests.where((r) => r.method == 'PUT'), isEmpty);
    expect(result.requests.lastWhere((r) => r.method == 'POST').data, {
      'groups': [
        {'gid': 42, 'expires_in': 2592000}
      ]
    });
  });

  testWidgets('server without auto-delete disables month and save',
      (tester) async {
    final result =
        await open(tester, channelSeconds: null, personalSupported: false);
    await showOption(tester, '1 month (30 days)');
    expect(radio(tester, '1 month (30 days)').onChanged, isNull);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(result.requests.every((r) => r.method == 'GET'), isTrue);
  });

  testWidgets('ordinary members only edit personal settings', (tester) async {
    await open(tester, admin: false, uid: 3);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(radio(tester, '10 minutes').groupValue, 600);
  });

  testWidgets('channel owner defaults to entire channel', (tester) async {
    await open(tester, admin: false, uid: 2);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    expect(radio(tester, '5 minutes').groupValue, 300);
  });

  testWidgets('DMs save one month using the existing endpoint', (tester) async {
    final result = await open(tester, isChannel: false);
    expect(find.byType(SwitchListTile), findsNothing);
    await select(tester, '1 month (30 days)');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(result.requests.lastWhere((r) => r.method == 'POST').data, {
      'users': [
        {'uid': 42, 'expires_in': 2592000}
      ]
    });
  });

  testWidgets('failed saves keep the original policy', (tester) async {
    final result = await open(tester, failSave: true);
    await select(tester, '1 month (30 days)');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
        result.container
            .read(groupDirectoryProvider)
            .requireValue[42]
            ?.autoDeleteAfter,
        300);
    expect(find.text('Save failed'), findsOneWidget);
  });
}
