import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/voice/application/incoming_call_provider.dart';
import 'package:vocechat_client/features/voice/application/voice_controller.dart';
import 'package:vocechat_client/features/voice/domain/voice_models.dart';
import 'package:vocechat_client/features/voice/presentation/incoming_call_banner.dart';
import 'package:vocechat_client/features/voice/presentation/voice_operations_bar.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('active call overlay stays visible and can be dragged',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          voiceControllerProvider.overrideWith(_ActiveVoiceController.new),
        ],
        child: _localizedApp(home: const _SwitchingPageHost()),
      ),
    );
    await tester.pumpAndSettle();

    final callBar = find.byType(VoiceOperationsBar);
    final dragHandle = find.byKey(const ValueKey('voice-call-drag-handle'));
    expect(callBar, findsOneWidget);
    expect(dragHandle, findsOneWidget);

    final initialTopLeft = tester.getTopLeft(callBar);
    await tester.drag(dragHandle, const Offset(-120, 80));
    await tester.pump();
    final draggedTopLeft = tester.getTopLeft(callBar);
    expect(draggedTopLeft.dx, lessThan(initialTopLeft.dx));
    expect(draggedTopLeft.dy, greaterThan(initialTopLeft.dy));

    await tester.tap(find.byKey(const ValueKey('switch-page')));
    await tester.pump();
    expect(find.text('contacts-page'), findsOneWidget);
    expect(callBar, findsOneWidget);
    expect(tester.getTopLeft(callBar), draggedTopLeft);

    await tester.drag(dragHandle, const Offset(2000, 2000));
    await tester.pump();
    await tester.pump();
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
    final bottomRight = tester.getBottomRight(callBar);
    expect(bottomRight.dx, lessThanOrEqualTo(screenSize.width - 12));
    expect(bottomRight.dy, lessThanOrEqualTo(screenSize.height - 12));
  });

  testWidgets('answering an incoming call opens the matching DM',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/contacts',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(
            body: Stack(
              children: [
                child,
                const IncomingCallBanner(),
              ],
            ),
          ),
          routes: [
            GoRoute(
              path: '/contacts',
              builder: (context, state) => const SizedBox.expand(),
            ),
            GoRoute(
              path: '/home/chat/:id',
              builder: (context, state) => Text(state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthenticatedController.new),
        incomingCallProvider.overrideWith(_RingingCallController.new),
        userDirectoryProvider.overrideWith(_UserDirectory.new),
        voiceControllerProvider.overrideWith(_AnswerVoiceController.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Caller'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.call));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, '/home/chat/u-42');
    expect(find.text('u-42'), findsOneWidget);
    expect(
      container.read(voiceControllerProvider)?.context,
      const MessageTarget.user(uid: 42),
    );
  });
}

Widget _localizedApp({required Widget home}) {
  return MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: home,
  );
}

class _SwitchingPageHost extends StatefulWidget {
  const _SwitchingPageHost();

  @override
  State<_SwitchingPageHost> createState() => _SwitchingPageHostState();
}

class _SwitchingPageHostState extends State<_SwitchingPageHost> {
  bool _showContacts = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Text(_showContacts ? 'contacts-page' : 'chat-page'),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: IconButton(
              key: const ValueKey('switch-page'),
              onPressed: () => setState(() => _showContacts = true),
              icon: const Icon(Icons.people),
            ),
          ),
          const IncomingCallBanner(),
        ],
      ),
    );
  }
}

class _ActiveVoiceController extends VoiceController {
  @override
  VoicingInfo? build() => const VoicingInfo(
        context: MessageTarget.user(uid: 42),
        connectionState: VoiceConnectionState.connected,
      );
}

class _AnswerVoiceController extends VoiceController {
  @override
  VoicingInfo? build() => null;

  @override
  Future<void> join(MessageTarget context) async {
    state = VoicingInfo(
      context: context,
      connectionState: VoiceConnectionState.connected,
    );
  }
}

class _RingingCallController extends IncomingCall {
  @override
  IncomingCallState build() => const IncomingCallState(
        fromUid: 42,
        toUid: 7,
        calling: true,
      );
}

class _AuthenticatedController extends AuthController {
  @override
  Future<AuthState> build() async => const AuthState.authenticated(
        user: VoceUser(uid: 7, name: 'Self'),
      );
}

class _UserDirectory extends UserDirectory {
  @override
  Future<Map<int, UserSummary>> build() async => const {
        42: UserSummary(uid: 42, name: 'Caller'),
      };
}
