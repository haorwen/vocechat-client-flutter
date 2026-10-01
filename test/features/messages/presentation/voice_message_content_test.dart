import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/core/storage/account_store.dart';
import 'package:vocechat_client/core/storage/secure_token_store.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/messages/presentation/file_message_content.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

const _resourcePath = '2026/9/27/eeea4896-32c9-47d1-b5d3-80bce837bd1a';
const _recordingName = 'voice_1727421000000.m4a';
const _audioChannel = MethodChannel('com.ryanheise.just_audio.methods');
const _sessionChannel = MethodChannel('com.ryanheise.audio_session');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _Tokens tokens;
  late Dio dio;
  late List<String> resourceRequests;
  late List<String> playerCalls;

  setUp(() async {
    tokens = _Tokens();
    resourceRequests = [];
    playerCalls = [];
    dio = Dio()
      ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        resourceRequests.add(options.uri.toString());
        handler.reject(DioException(requestOptions: options));
      }));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_audioChannel, (call) async {
      playerCalls.add(call.method);
      return <String, dynamic>{};
    });
    messenger.setMockMethodCallHandler(_sessionChannel, (_) async => null);

    container = ProviderContainer(overrides: [
      serverStoreProvider.overrideWith(_Servers.new),
      accountStoreProvider.overrideWith(_Accounts.new),
      secureTokenStoreProvider('server::7').overrideWith((ref) => tokens),
      dioProvider.overrideWithValue(dio),
    ]);
    // Keep the async stores available before the renderer reads the server URL.
    container.listen(serverStoreProvider, (_, __) {});
    container.listen(accountStoreProvider, (_, __) {});
    await container.read(serverStoreProvider.future);
    await container.read(accountStoreProvider.future);
  });

  tearDown(() {
    container.dispose();
    dio.close(force: true);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_audioChannel, null);
    messenger.setMockMethodCallHandler(_sessionChannel, null);
  });

  Future<void> pumpMessage(
    WidgetTester tester, {
    required String content,
    Map<String, dynamic>? properties,
    String messageContentType = 'vocechat/audio',
    bool sending = false,
  }) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: FileMessageContent(
            content: content,
            properties: properties,
            messageContentType: messageContentType,
            sending: sending,
            progress: sending ? 0.4 : null,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  void expectNoResourceLoading() {
    expect(tokens.readCount, 0);
    expect(resourceRequests, isEmpty);
    expect(playerCalls, isNot(contains('init')));
  }

  final voiceBodies = <String, String>{
    'Android bare resource path': _resourcePath,
    'JSON object resource path': jsonEncode({'path': _resourcePath}),
    'JSON string resource path': jsonEncode(_resourcePath),
  };
  for (final body in voiceBodies.entries) {
    testWidgets('${body.key} renders as voice without attachment metadata',
        (tester) async {
      await pumpMessage(tester, content: body.value);

      expect(find.text('Voice Message'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
      expect(find.text(_resourcePath), findsNothing);
      expect(find.text(_resourcePath.split('/').last), findsNothing);
      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNotNull);
      expectNoResourceLoading();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'recorded m4a renders voice controls without a filename or download',
      (tester) async {
    await pumpMessage(
      tester,
      content: jsonEncode({'path': _resourcePath}),
      properties: const {
        'name': _recordingName,
        'content_type': 'audio/mp4',
        'size': 4096,
      },
    );

    expect(find.text('Voice Message'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle), findsOneWidget);
    expect(find.text(_recordingName), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
    expectNoResourceLoading();
    expect(tester.takeException(), isNull);
  });

  for (final file in [
    (name: 'meeting.m4a', mime: 'audio/mp4'),
    (name: 'music.mp3', mime: 'audio/mpeg'),
    (name: _recordingName, mime: 'audio/mp4'),
  ]) {
    testWidgets('selected ${file.name} remains a downloadable file',
        (tester) async {
      await pumpMessage(
        tester,
        content: jsonEncode({'path': _resourcePath}),
        messageContentType: 'vocechat/file',
        properties: {
          'name': file.name,
          'content_type': file.mime,
          'size': 4096,
        },
      );

      expect(find.text(file.name), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed,
          isNotNull);
      expect(find.text('Voice Message'), findsNothing);
      expect(find.byIcon(Icons.play_circle), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expectNoResourceLoading();
      expect(tester.takeException(), isNull);
    });
  }

  for (final sending in [true, false]) {
    testWidgets(
        '${sending ? 'uploading' : 'failed'} local voice retains disabled voice controls',
        (tester) async {
      await pumpMessage(
        tester,
        content: jsonEncode({'path': 'local:recording-1'}),
        properties: const {
          'name': _recordingName,
          'content_type': 'audio/mp4',
        },
        sending: sending,
      );

      expect(find.text('Voice Message'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(
          tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(find.text(_recordingName), findsNothing);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
      if (sending) {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester
              .widget<CircularProgressIndicator>(
                  find.byType(CircularProgressIndicator))
              .value,
          0.4,
        );
      } else {
        expect(find.byIcon(Icons.play_circle), findsOneWidget);
      }

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expectNoResourceLoading();
      expect(find.text('Voice Message'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Servers extends ServerStore {
  @override
  Future<ServerState> build() async => const ServerState(
        currentServerId: 'server',
        servers: [
          ServerConfig(
            id: 'server',
            baseUrl: 'https://chat.example.test',
            name: 'Test server',
          ),
        ],
      );
}

class _Accounts extends AccountStore {
  @override
  Future<AccountState> build() async =>
      const AccountState(currentAccountId: 'server::7');
}

class _Tokens extends SecureTokenStore {
  _Tokens() : super(id: 'server::7');

  int readCount = 0;

  @override
  Future<TokenData?> readTokens() async {
    readCount++;
    return null;
  }
}
