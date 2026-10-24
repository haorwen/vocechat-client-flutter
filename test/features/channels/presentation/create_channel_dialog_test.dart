import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/channels/application/conversation_providers.dart';
import 'package:vocechat_client/features/channels/application/pinned_chats_provider.dart';
import 'package:vocechat_client/features/channels/domain/pin_chat_models.dart';
import 'package:vocechat_client/features/channels/presentation/chat_list_screen.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/features/messages/application/chat_controller.dart';
import 'package:vocechat_client/features/messages/application/read_index_provider.dart';
import 'package:vocechat_client/features/messages/data/message_api.dart';
import 'package:vocechat_client/features/messages/data/message_cache.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/messages/presentation/chat_screen.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

const _existing = {'gid': 1, 'name': 'Existing channel'};
const _newName = 'New empty channel';
const _newTarget = MessageTarget.group(gid: 42);

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState.authenticated(user: VoceUser(uid: 7, name: 'Me'));
}

class _Servers extends ServerStore {
  @override
  Future<ServerState> build() async => const ServerState();
}

class _Users extends UserDirectory {
  @override
  Future<Map<int, UserSummary>> build() async => const {};
}

class _Pins extends PinnedChats {
  @override
  Future<List<PinChat>> build() async => const [];
}

class _Reads extends ReadIndex {
  @override
  Future<ReadIndexState> build() async => const ReadIndexState();
}

class _Chat extends ChatController {
  @override
  Future<List<ChatMessage>> build(MessageTarget target) async => const [];
}

class _Cache implements MessageCache {
  List<Map<String, dynamic>> conversations = [
    const ConversationItem(
      key: GroupConversationKey(1),
      name: 'Existing channel',
      isChannel: true,
    ).toJson(),
  ];

  @override
  Future<List<Map<String, dynamic>>?> readConversations() async =>
      conversations;

  @override
  Future<void> writeConversations(List<Map<String, dynamic>> items) async {
    conversations = items;
  }

  @override
  Future<List<Map<String, dynamic>>?> readGroupDirectory() async => [_existing];

  @override
  Future<void> writeGroupDirectory(List<Map<String, dynamic>> groups) async {}

  @override
  Future<List<ChatMessage>> read(MessageTarget target,
          {int limit = 500}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Messages extends MessageApi {
  _Messages() : super(Dio());
  Completer<List<ChatMessage>>? historyGate;

  @override
  Future<List<ChatMessage>> getHistory(MessageTarget target,
          {int? beforeMid, int limit = 30}) async =>
      historyGate == null ? const [] : await historyGate!.future;
}

// The list's loading overlay keeps an animated spinner mounted at zero opacity.
// Pump a bounded number of frames instead of waiting for all animations to stop.
Future<void> _pump(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  Future<
      ({
        ProviderContainer container,
        GoRouter router,
        Dio dio,
        _Cache cache,
        _Messages messages
      })> mount(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cache = _Cache();
    final messages = _Messages();
    final groups = <Map<String, dynamic>>[_existing];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final Object data;
      if (options.path == '/api/group' && options.method == 'POST') {
        final body = options.data as Map<String, dynamic>;
        expect(body['name'], _newName);
        groups.add({'gid': 42, 'name': body['name']});
        data = {'gid': 42};
      } else if (options.path == '/api/group') {
        data = List.of(groups);
      } else {
        expect(options.path, '/api/user');
        data = const [];
      }
      handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: data));
    }));
    final container = ProviderContainer(overrides: [
      dioProvider.overrideWith((ref) => dio),
      messageCacheProvider.overrideWith((ref) async => cache),
      messageApiProvider.overrideWith((ref) => messages),
      authControllerProvider.overrideWith(_Auth.new),
      serverStoreProvider.overrideWith(_Servers.new),
      userDirectoryProvider.overrideWith(_Users.new),
      pinnedChatsProvider.overrideWith(_Pins.new),
      readIndexProvider.overrideWith(_Reads.new),
      chatControllerProvider(_newTarget).overrideWith(_Chat.new),
    ]);
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(
        path: '/home',
        builder: (_, __) => const Scaffold(body: ChatListScreen()),
        routes: [
          GoRoute(
            path: 'chat/:id',
            builder: (_, state) =>
                Scaffold(body: ChatScreen(id: state.pathParameters['id']!)),
          ),
        ],
      ),
    ]);
    addTearDown(() {
      router.dispose();
      container.dispose();
      dio.close();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
      ),
    ));
    await _pump(tester);
    expect(find.text('Existing channel'), findsOneWidget);
    return (
      container: container,
      router: router,
      dio: dio,
      cache: cache,
      messages: messages
    );
  }

  Future<void> createChannel(WidgetTester tester) async {
    await tester.tap(find.byTooltip('New chat'));
    await _pump(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Channel name'), _newName);
    await tester.tap(find.text('Create'));
    await _pump(tester);
  }

  for (final width in [700.0, 1200.0]) {
    testWidgets(
        'creation retains the sidebar and selects the channel at $width',
        (tester) async {
      final s = await mount(tester, width);
      // A new channel must appear without a message or an SSE notification,
      // and opening it must not wait for other conversations' history.
      s.messages.historyGate = Completer<List<ChatMessage>>();
      final refresh =
          s.container.read(conversationsProvider.notifier).refresh();
      await _pump(tester);
      await createChannel(tester);

      expect(s.router.routeInformationProvider.value.uri.path, '/home');
      expect(find.byType(Dialog), findsNothing);
      expect(find.byTooltip('New chat'), findsOneWidget);
      expect(find.text('Existing channel'), findsOneWidget);
      expect(find.text(_newName), findsNWidgets(2));
      expect(tester.widget<ChatScreen>(find.byType(ChatScreen)).id, 'g-42');
      expect(tester.getTopLeft(find.byType(ChatScreen)).dx, greaterThan(0));
      expect(
          s.container
              .read(conversationsProvider)
              .requireValue
              .singleWhere((c) => c.key == const GroupConversationKey(42))
              .lastAt,
          isNull);

      s.messages.historyGate!.complete([]);
      await refresh;
      await _pump(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(s.cache.conversations.any((c) => c['id'] == 42), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('mobile opens the channel and keeps it in the list after back',
      (tester) async {
    final s = await mount(tester, 390);
    await createChannel(tester);
    expect(s.router.routeInformationProvider.value.uri.path, '/home/chat/g-42');
    expect(find.byTooltip('New chat'), findsNothing);
    expect(find.text(_newName), findsOneWidget);

    s.router.pop();
    await _pump(tester);
    expect(find.byTooltip('New chat'), findsOneWidget);
    expect(find.text(_newName), findsOneWidget);
    expect(find.text('Existing channel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a late roster response cannot remove a newly created channel',
      (tester) async {
    final s = await mount(tester, 1200);
    RequestInterceptorHandler? heldRequest;
    RequestOptions? heldOptions;
    s.dio.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path == '/api/group' &&
          options.method == 'GET' &&
          heldRequest == null) {
        heldOptions = options;
        heldRequest = handler;
      } else {
        handler.next(options);
      }
    }));
    final refresh = s.container.read(conversationsProvider.notifier).refresh();
    await _pump(tester);
    expect(heldRequest, isNotNull);
    await createChannel(tester);
    expect(find.text(_newName), findsNWidgets(2));

    // This snapshot was fetched before the POST and has no new channel.
    heldRequest!.resolve(Response(
        requestOptions: heldOptions!, statusCode: 200, data: [_existing]));
    await _pump(tester);
    await refresh;
    expect(find.text(_newName), findsNWidgets(2));

    // A subsequent authoritative refresh must not duplicate the local entry.
    final nextRefresh =
        s.container.read(conversationsProvider.notifier).refresh();
    await _pump(tester);
    await nextRefresh;
    expect(
        s.container
            .read(conversationsProvider)
            .requireValue
            .where((c) => c.key == const GroupConversationKey(42)),
        hasLength(1));
    expect(s.cache.conversations.where((c) => c['id'] == 42), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed creation stays in the form without adding a conversation',
      (tester) async {
    final s = await mount(tester, 1200);
    s.dio.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'POST') {
        handler.reject(DioException(requestOptions: options));
      } else {
        handler.next(options);
      }
    }));
    await createChannel(tester);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Failed to create channel'), findsOneWidget);
    expect(s.router.routeInformationProvider.value.uri.path, '/home');
    expect(find.byType(ChatScreen), findsNothing);
    expect(s.container.read(conversationsProvider).requireValue, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling creation leaves the list and selection alone',
      (tester) async {
    final s = await mount(tester, 1200);
    await tester.tap(find.byTooltip('New chat'));
    await _pump(tester);
    await tester.tap(find.byIcon(Icons.close));
    await _pump(tester);
    expect(s.router.routeInformationProvider.value.uri.path, '/home');
    expect(find.byType(ChatScreen), findsNothing);
    expect(s.container.read(conversationsProvider).requireValue, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
