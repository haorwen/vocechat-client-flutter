import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/voice/application/avo_interaction_controller.dart';
import 'package:vocechat_client/features/voice/application/voice_controller.dart';
import 'package:vocechat_client/features/voice/data/agora_api.dart';
import 'package:vocechat_client/features/voice/domain/voice_models.dart';
import 'package:vocechat_client/shared/models/avo_interaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Exercise RTC independently of the mobile-only native PiP extension.
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final callerUid in [42, 7]) {
    final calleeUid = callerUid == 42 ? 7 : 42;
    test('DM $callerUid calls $calleeUid: both join callee room', () async {
      final caller = _CallClient(callerUid);
      final callee = _CallClient(calleeUid);
      addTearDown(caller.dispose);
      addTearDown(callee.dispose);

      await caller.controller.join(MessageTarget.user(uid: calleeUid));
      expect(caller.info?.joining, isTrue);
      expect(caller.info?.connectionState, VoiceConnectionState.connecting);
      expect(caller.controller.members.value.ids, isEmpty);
      caller.engine.confirmJoin();

      await callee.controller.join(
        MessageTarget.user(uid: callerUid),
        dmChannelOwnerUid: calleeUid,
      );
      callee.engine.confirmJoin();

      expect(caller.api.requestedUid, calleeUid);
      expect(callee.api.requestedUid, calleeUid);
      expect(caller.engine.connection.channelId, 'vocechat:dm:$calleeUid');
      expect(callee.engine.connection.channelId,
          caller.engine.connection.channelId);
      expect(caller.engine.connection.localUid, callerUid);
      expect(callee.engine.connection.localUid, calleeUid);
      expect(
          caller.engine.joinToken, 'token:$callerUid:vocechat:dm:$calleeUid');
      expect(
          callee.engine.joinToken, 'token:$calleeUid:vocechat:dm:$calleeUid');

      // RTC reports peers only when their channels match.
      caller.engine.handler.onUserJoined!(
          caller.engine.connection, calleeUid, 0);
      callee.engine.handler.onUserJoined!(
          callee.engine.connection, callerUid, 0);
      for (final client in [caller, callee]) {
        expect(client.controller.members.value.ids,
            unorderedEquals([callerUid, calleeUid]));
        expect(client.info?.joining, isFalse);
        expect(client.info?.connectionState, VoiceConnectionState.connected);
        expect(client.engine.options.publishMicrophoneTrack, isTrue);
        expect(client.engine.options.autoSubscribeAudio, isTrue);
      }
      expect(caller.info?.context, MessageTarget.user(uid: calleeUid));
      expect(callee.info?.context, MessageTarget.user(uid: callerUid));
      expect(callee.avo.room, MessageTarget.user(uid: callerUid));
    });
  }

  test('group call still requests its group channel', () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.group(gid: 99));
    expect(client.api.requestedUid, isNull);
    expect(client.api.requestedGid, 99);
    expect(client.engine.connection.channelId, 'vocechat:group:99');
    client.engine.confirmJoin();
    expect(client.info?.joining, isFalse);
  });

  test('native join failure is not overwritten by request completion',
      () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    client.engine.failDuringJoin = true;
    await client.controller.join(const MessageTarget.user(uid: 42));
    expect(client.info?.connectionState, VoiceConnectionState.failed);
    expect(client.info?.joining, isFalse);
    expect(client.controller.members.value.ids, isEmpty);
    expect(client.avo.room, isNull);
  });

  test('late events after hanging up do not restore call or participants',
      () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    await client.controller.leave();
    client.engine.confirmJoin();
    client.engine.handler.onUserJoined!(client.engine.connection, 42, 0);
    expect(client.info, isNull);
    expect(client.controller.members.value.ids, isEmpty);
    expect(client.avo.room, isNull);
  });

  test('old leave callback cannot erase a subsequent call roster', () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    client.engine.confirmJoin();
    final oldConnection = client.engine.connection;
    await client.controller.leave();
    await client.controller.join(const MessageTarget.user(uid: 55));
    client.engine.confirmJoin();
    client.engine.handler.onUserJoined!(client.engine.connection, 55, 0);
    client.engine.handler.onLeaveChannel?.call(oldConnection, const RtcStats());
    expect(client.controller.members.value.ids, unorderedEquals([7, 55]));
    expect(client.info?.context, const MessageTarget.user(uid: 55));
  });

  test('PiP and leave failures cannot skip native engine release', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final client = _CallClient(7);
    await client.controller.join(const MessageTarget.user(uid: 42));
    client.engine.pip.failDispose = true;
    client.engine.failLeave = true;
    client.dispose();
    await client.engine.released.future.timeout(const Duration(seconds: 1));
    expect(client.engine.handlerUnregistered, isTrue);
    expect(client.engine.leaveCalls, 1);
    expect(client.engine.releaseCalls, 1);
  });

  test('hung PiP and leave calls cannot prevent native engine release',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final client =
        _CallClient(7, cleanupTimeout: const Duration(milliseconds: 10));
    await client.controller.join(const MessageTarget.user(uid: 42));
    client.engine.pip.disposeWait = Completer<void>();
    client.engine.leaveWait = Completer<void>();
    client.dispose();
    await client.engine.released.future.timeout(const Duration(seconds: 1));
    expect(client.engine.leaveCalls, 1);
    expect(client.engine.releaseCalls, 1);
    client.engine.pip.disposeWait!.complete();
    client.engine.leaveWait!.complete();
  });

  test('late native callbacks are ignored after controller disposal', () async {
    final client = _CallClient(7);
    await client.controller.join(const MessageTarget.user(uid: 42));
    client.engine.confirmJoin();
    final handler = client.engine.handler;
    final connection = client.engine.connection;
    client.dispose();
    expect(() {
      handler.onJoinChannelSuccess!(connection, 0);
      handler.onUserJoined!(connection, 42, 0);
      handler.onUserMuteAudio!(connection, 42, true);
      handler.onUserMuteVideo!(connection, 42, true);
      handler.onAudioVolumeIndication!(
        connection,
        [const AudioVolumeInfo(uid: 0, volume: 20)],
        1,
        20,
      );
      handler.onNetworkQuality!(
          connection, 0, QualityType.qualityBad, QualityType.qualityBad);
      handler.onLocalVideoStateChanged!(
        VideoSourceType.videoSourceScreen,
        LocalVideoStreamState.localVideoStreamStateStopped,
        LocalVideoStreamReason.localVideoStreamReasonOk,
      );
    }, returnsNormally);
    await client.engine.released.future;
  });

  test('a recovered scope waits for the previous native release', () async {
    final oldClient = _CallClient(7);
    await oldClient.controller.join(const MessageTarget.user(uid: 42));
    oldClient.engine.releaseWait = Completer<void>();
    oldClient.dispose();
    await oldClient.engine.released.future;

    final newClient = _CallClient(7);
    addTearDown(newClient.dispose);
    final join = newClient.controller.join(const MessageTarget.user(uid: 42));
    await Future<void>.delayed(Duration.zero);
    expect(newClient.engine.initializeCalls, 0);
    oldClient.engine.releaseWait!.complete();
    await join;
    expect(newClient.engine.initializeCalls, 1);
  });

  test('a hung old release times out the new call without a second engine',
      () async {
    final oldClient = _CallClient(7);
    await oldClient.controller.join(const MessageTarget.user(uid: 42));
    final releaseGate = Completer<void>();
    oldClient.engine.releaseWait = releaseGate;
    oldClient.dispose();
    await oldClient.engine.released.future;

    final newClient =
        _CallClient(7, cleanupTimeout: const Duration(milliseconds: 10));
    final unrelatedUiState = StateProvider<int>((ref) => 0);
    try {
      final join = newClient.controller.join(const MessageTarget.user(uid: 42));
      expect(newClient.info?.joining, isTrue);
      // The native teardown barrier belongs to voice. Other state/UI work
      // remains usable while the call waits for the previous SDK instance.
      newClient.container.read(unrelatedUiState.notifier).state = 1;
      expect(newClient.container.read(unrelatedUiState), 1);
      await expectLater(join, throwsA(isA<TimeoutException>()));
      expect(newClient.info, isNull);
      expect(newClient.engine.initializeCalls, 0);
      expect(newClient.engine.joinCalls, 0);
      expect(newClient.controller.engineOrNull, isNull);
      newClient.container.read(unrelatedUiState.notifier).state = 2;
      expect(newClient.container.read(unrelatedUiState), 2);
    } finally {
      releaseGate.complete();
      // Let the process-wide barrier clear before another test creates an
      // engine. The fake gate must not leak into subsequent test cases.
      await Future<void>.delayed(Duration.zero);
      newClient.dispose();
    }
  });

  test('recovery releases an engine whose initialization completes late',
      () async {
    final oldClient =
        _CallClient(7, cleanupTimeout: const Duration(milliseconds: 10));
    oldClient.engine.initializeWait = Completer<void>();
    final oldJoin =
        oldClient.controller.join(const MessageTarget.user(uid: 42));
    await Future<void>.delayed(Duration.zero);
    expect(oldClient.engine.initializeCalls, 1);
    oldClient.dispose();
    await oldClient.engine.released.future.timeout(const Duration(seconds: 1));

    final newClient = _CallClient(7);
    addTearDown(newClient.dispose);
    final newJoin =
        newClient.controller.join(const MessageTarget.user(uid: 42));
    await Future<void>.delayed(Duration.zero);
    expect(newClient.engine.initializeCalls, 0);
    oldClient.engine.initializeWait!.complete();
    await oldJoin;
    await newJoin;
    expect(oldClient.engine.releaseCalls, 2);
    expect(newClient.engine.initializeCalls, 1);
  });

  test('overlapping joins share full setup and never use an unready engine',
      () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    client.engine.initializeWait = Completer<void>();
    client.engine.volumeSetupWait = Completer<void>();
    final first = client.controller.join(const MessageTarget.user(uid: 42));
    await Future<void>.delayed(Duration.zero);
    final second = client.controller.join(const MessageTarget.user(uid: 55));
    await Future<void>.delayed(Duration.zero);
    expect(client.engine.initializeCalls, 1);
    expect(client.engine.leaveCalls, 0);
    expect(client.engine.joinCalls, 0);

    client.engine.initializeWait!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(client.engine.joinCalls, 0);
    client.engine.volumeSetupWait!.complete();
    await Future.wait([first, second]);
    expect(client.engine.initializeCalls, 1);
    expect(client.engine.joinCalls, 1);
    expect(client.engine.connection.channelId, 'vocechat:dm:55');
    client.engine.confirmJoin();
    expect(client.info?.context, const MessageTarget.user(uid: 55));
  });
}

class _CallClient {
  _CallClient(int uid, {Duration? cleanupTimeout}) : api = _TokenApi(uid) {
    container = ProviderContainer(overrides: [
      agoraApiProvider.overrideWithValue(api),
      agoraRtcEngineFactoryProvider.overrideWithValue(() => engine),
      agoraPipControllerFactoryProvider.overrideWithValue((_) => engine.pip),
      avoInteractionControllerProvider.overrideWith(() => avo),
      if (cleanupTimeout != null)
        voiceResourceCleanupTimeoutProvider.overrideWithValue(cleanupTimeout),
    ]);
    controller = container.read(voiceControllerProvider.notifier);
  }

  final _TokenApi api;
  final engine = _FakeRtcEngine();
  final avo = _FakeAvoController();
  late final ProviderContainer container;
  late final VoiceController controller;
  VoicingInfo? get info => container.read(voiceControllerProvider);

  void dispose() => container.dispose();
}

// Mirrors the server contract: the token target selects the room; the
// authenticated user, not the target, selects the RTC participant uid.
class _TokenApi extends AgoraApi {
  _TokenApi(this.selfUid) : super(Dio());
  final int selfUid;
  int? requestedUid;
  int? requestedGid;

  @override
  Future<AgoraTokenResponse> generateToken({int? uid, int? gid}) async {
    requestedUid = uid;
    requestedGid = gid;
    final channel = uid != null ? 'vocechat:dm:$uid' : 'vocechat:group:$gid';
    return AgoraTokenResponse(
      agoraToken: 'token:$selfUid:$channel',
      appId: 'test-app',
      uid: selfUid,
      channelName: channel,
      expiredIn: 3600,
    );
  }
}

class _FakeRtcEngine implements RtcEngine {
  late RtcEngineEventHandler handler;
  late RtcConnection connection;
  late ChannelMediaOptions options;
  late String joinToken;
  bool failDuringJoin = false;
  bool failLeave = false;
  bool handlerUnregistered = false;
  int initializeCalls = 0;
  int leaveCalls = 0;
  int releaseCalls = 0;
  int joinCalls = 0;
  Completer<void>? leaveWait;
  Completer<void>? releaseWait;
  Completer<void>? initializeWait;
  Completer<void>? volumeSetupWait;
  final released = Completer<void>();
  final pip = _FakePipController();

  @override
  Future<void> initialize(RtcEngineContext context) async {
    initializeCalls++;
    await initializeWait?.future;
  }

  @override
  Future<void> enableAudioVolumeIndication({
    required int interval,
    required int smooth,
    required bool reportVad,
  }) async {
    await volumeSetupWait?.future;
  }

  @override
  void registerEventHandler(RtcEngineEventHandler eventHandler) {
    handler = eventHandler;
  }

  @override
  void unregisterEventHandler(RtcEngineEventHandler eventHandler) {
    handlerUnregistered = identical(handler, eventHandler);
  }

  @override
  Future<void> joinChannel({
    required String token,
    required String channelId,
    required int uid,
    required ChannelMediaOptions options,
  }) async {
    joinCalls++;
    connection = RtcConnection(channelId: channelId, localUid: uid);
    joinToken = token;
    this.options = options;
    if (failDuringJoin) {
      handler.onConnectionStateChanged!(
        connection,
        ConnectionStateType.connectionStateFailed,
        ConnectionChangedReasonType.connectionChangedInvalidToken,
      );
    }
  }

  void confirmJoin() => handler.onJoinChannelSuccess!(connection, 0);

  @override
  Future<void> leaveChannel({LeaveChannelOptions? options}) async {
    leaveCalls++;
    if (failLeave) throw StateError('Native leave failed');
    await leaveWait?.future;
  }

  @override
  Future<void> stopPreview({VideoSourceType? sourceType}) async {}

  @override
  Future<void> release({bool sync = false}) async {
    releaseCalls++;
    if (!released.isCompleted) released.complete();
    await releaseWait?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePipController implements AgoraPipController {
  bool failDispose = false;
  Completer<void>? disposeWait;

  @override
  Future<void> dispose() async {
    if (failDispose) throw StateError('Native PiP disposal failed');
    await disposeWait?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAvoController extends AvoInteractionController {
  MessageTarget? room;

  @override
  Map<int, RemoteAvoInteraction> build() => {};

  @override
  Future<void> joinRoom(MessageTarget room) async => this.room = room;

  @override
  Future<void> leaveRoom() async => room = null;
}
