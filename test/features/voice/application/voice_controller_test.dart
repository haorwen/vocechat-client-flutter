import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/voice/application/avo_interaction_controller.dart';
import 'package:vocechat_client/features/voice/application/voice_controller.dart';
import 'package:vocechat_client/features/voice/data/agora_api.dart';
import 'package:vocechat_client/features/voice/domain/voice_models.dart';
import 'package:vocechat_client/shared/models/avo_interaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // RTC tests use desktop unless a case explicitly exercises mobile PiP.
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

  test('video reception is ready before joining without camera capture',
      () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    client.engine.videoSetupWait = Completer<void>();
    final join = client.controller.join(const MessageTarget.user(uid: 42));

    await Future<void>.delayed(Duration.zero);
    expect(client.engine.enableVideoCalls, 1);
    expect(client.engine.joinCalls, 0);

    client.engine.videoSetupWait!.complete();
    await join;
    expect(client.engine.localVideoEnabled, isFalse);
    expect(client.engine.options.publishCameraTrack, isFalse);
    expect(client.engine.options.autoSubscribeVideo, isTrue);
    expect(client.engine.mediaSetup,
        ['enable-video', 'local-video:false', 'join']);
  });

  test('iOS remote video prepares native PiP and stops on return', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    client.engine.confirmJoin();
    client.engine.remoteJoined(42);
    await Future<void>.delayed(Duration.zero);
    expect(client.engine.pip.configurations, isEmpty);

    client.engine.remoteVideoDecoding(42);
    await Future<void>.delayed(Duration.zero);
    final pip = client.engine.pip;
    expect(pip.observer, isNotNull);
    expect(pip.configurations, hasLength(1));
    final configuration = pip.configurations.single;
    expect(configuration.autoEnterEnabled, isTrue);
    expect(configuration.sourceContentView, 0);
    expect(configuration.contentView, 0);
    expect(configuration.controlStyle, 2);
    expect(configuration.videoStreams, hasLength(1));
    final stream = configuration.videoStreams!.single;
    expect(stream.connection.channelId, 'vocechat:dm:42');
    expect(stream.connection.localUid, 7);
    expect(stream.canvas.uid, 42);
    expect(stream.canvas.sourceType, VideoSourceType.videoSourceRemote);

    client.controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);
    pip.reportState(AgoraPipState.pipStateStarted);
    client.controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
    client.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    expect(pip.startCalls, 0);
    expect(pip.configurations, hasLength(1));

    client.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(pip.stopCalls, 1);
    expect(pip.activated, isFalse);
  });

  test('closing or leaving a call releases local camera capture', () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    client.engine.confirmJoin();
    client.engine.remoteJoined(42);
    client.engine.remoteVideoDecoding(42);

    await client.controller.openCamera();
    expect(client.engine.localVideoEnabled, isTrue);
    await client.controller.closeCamera();
    expect(client.engine.localVideoEnabled, isFalse);
    expect(client.info?.video, isFalse);
    expect(client.controller.members.value.byId[42]?.video, isTrue);
    expect(client.info?.connectionState, VoiceConnectionState.connected);

    await client.controller.openCamera();
    expect(client.engine.localVideoEnabled, isTrue);
    await client.controller.leave();
    expect(client.engine.localVideoEnabled, isFalse);
    expect(client.info, isNull);
    await client.controller.join(const MessageTarget.user(uid: 55));
    expect(client.engine.localVideoEnabled, isFalse);
    expect(client.engine.options.publishCameraTrack, isFalse);
    expect(client.engine.enableVideoCalls, 1);
  });

  for (final peerLeaves in [false, true]) {
    test('iOS disposes PiP when ${peerLeaves ? 'peer leaves' : 'camera stops'}',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final client = _CallClient(7);
      addTearDown(client.dispose);
      await client.controller.join(const MessageTarget.user(uid: 42));
      client.engine.confirmJoin();
      client.engine.remoteJoined(42);
      client.engine.remoteVideoDecoding(42);
      await Future<void>.delayed(Duration.zero);
      expect(client.engine.pip.configurations, hasLength(1));

      if (peerLeaves) {
        client.engine.handler.onUserOffline!(client.engine.connection, 42,
            UserOfflineReasonType.userOfflineQuit);
      } else {
        client.engine.handler.onUserMuteVideo!(
            client.engine.connection, 42, true);
      }
      await Future<void>.delayed(Duration.zero);
      expect(client.engine.pip.pipDisposeCalls, 1);
      client.controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(client.engine.pip.startCalls, 0);
      expect(client.engine.pip.configurations, hasLength(1));
    });
  }

  test('iOS manual PiP starts only when leaving the foreground', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final client = _CallClient(7);
    addTearDown(client.dispose);
    final pip = client.engine.pip..autoEnterSupported = false;
    await client.controller.join(const MessageTarget.user(uid: 42));
    client.engine.confirmJoin();
    client.engine.remoteJoined(42);
    client.engine.remoteVideoDecoding(42);
    await Future<void>.delayed(Duration.zero);
    expect(pip.configurations.single.autoEnterEnabled, isFalse);
    expect(pip.startCalls, 0);

    client.controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);
    expect(pip.startCalls, 1);

    // If the native window closes while backgrounded, hidden/paused and the
    // inactive transition on the way back must not reopen it.
    pip.reportState(AgoraPipState.pipStateStopped);
    client.controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await Future<void>.delayed(Duration.zero);
    client.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);
    client.controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
    client.controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);
    expect(pip.startCalls, 1);
    expect(pip.configurations, hasLength(1));

    client.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(pip.stopCalls, 1);
    client.controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);
    expect(pip.startCalls, 2);
  });

  test('failed iOS PiP setup cannot start an unconfigured window', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final client = _CallClient(7);
    addTearDown(client.dispose);
    final pip = client.engine.pip
      ..autoEnterSupported = false
      ..setupSucceeds = false;
    await client.controller.join(const MessageTarget.user(uid: 42));
    client.engine.confirmJoin();
    client.engine.remoteJoined(42);
    client.engine.remoteVideoDecoding(42);
    await Future<void>.delayed(Duration.zero);
    client.controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);
    expect(pip.startCalls, 0);
    expect(client.info?.connectionState, VoiceConnectionState.connected);
  });

  for (final waitingForSetup in [true, false]) {
    test(
        'iOS late ${waitingForSetup ? 'setup' : 'activation query'} does not reopen PiP while returning',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final client = _CallClient(7);
      addTearDown(client.dispose);
      final pip = client.engine.pip..autoEnterSupported = false;
      if (waitingForSetup) {
        pip.setupWait = Completer<void>();
      } else {
        pip.activatedWait = Completer<bool>();
      }
      await client.controller.join(const MessageTarget.user(uid: 42));
      client.engine.confirmJoin();
      client.engine.remoteJoined(42);
      client.engine.remoteVideoDecoding(42);
      await Future<void>.delayed(Duration.zero);

      client.controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      client.controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
      client.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      client.controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
      client.controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      if (waitingForSetup) {
        pip.setupWait!.complete();
      } else {
        pip.activatedWait!.complete(false);
      }
      await Future<void>.delayed(Duration.zero);
      expect(pip.startCalls, 0);

      // A fresh departure after the app has resumed is still eligible.
      client.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      client.controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(pip.startCalls, 1);
      expect(pip.configurations, hasLength(1));
    });
  }

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

  test('recovery waits for late video setup before replacing the engine',
      () async {
    final oldClient =
        _CallClient(7, cleanupTimeout: const Duration(milliseconds: 10));
    oldClient.engine.videoSetupWait = Completer<void>();
    final oldJoin =
        oldClient.controller.join(const MessageTarget.user(uid: 42));
    await Future<void>.delayed(Duration.zero);
    expect(oldClient.engine.enableVideoCalls, 1);
    expect(oldClient.engine.joinCalls, 0);
    oldClient.dispose();
    await oldClient.engine.released.future.timeout(const Duration(seconds: 1));

    final newClient = _CallClient(7);
    addTearDown(newClient.dispose);
    final newJoin =
        newClient.controller.join(const MessageTarget.user(uid: 42));
    await Future<void>.delayed(Duration.zero);
    expect(newClient.engine.initializeCalls, 0);
    oldClient.engine.videoSetupWait!.complete();
    await oldJoin;
    await newJoin;
    expect(oldClient.engine.releaseCalls, 2);
    expect(oldClient.engine.joinCalls, 0);
    expect(newClient.engine.enableVideoCalls, 1);
    expect(newClient.engine.localVideoEnabled, isFalse);
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

  test('camera controls expose the capabilities of each native platform', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        isVoiceCameraFlipSupported,
        platform == TargetPlatform.android || platform == TargetPlatform.iOS,
        reason: '$platform front/back camera switching',
      );
      expect(
        isVoiceCameraSelectionSupported,
        platform == TargetPlatform.windows || platform == TargetPlatform.macOS,
        reason: '$platform camera device selection',
      );
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('$platform switches the active camera without changing call state',
        () async {
      debugDefaultTargetPlatformOverride = platform;
      final client = _CallClient(7);
      addTearDown(client.dispose);
      await client.controller.join(const MessageTarget.user(uid: 42));
      client.engine.confirmJoin();
      await client.controller.openCamera();
      final before = client.info;

      await client.controller.switchCamera();

      expect(client.engine.switchCameraCalls, 1);
      expect(client.info, before);
      expect(await client.controller.getCameraDevices(), isNull);
      await client.controller.selectCamera('usb');
      expect(client.engine.videoDeviceManagerCalls, 0);
    });
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
    test('$platform enumerates and selects camera devices during video',
        () async {
      debugDefaultTargetPlatformOverride = platform;
      final client = _CallClient(7);
      addTearDown(client.dispose);
      await client.controller.join(const MessageTarget.user(uid: 42));
      client.engine.confirmJoin();
      await client.controller.setMuted(true);
      await client.controller.openCamera();
      client.engine.videoDevices.devices = const [
        VideoDeviceInfo(deviceId: 'built-in', deviceName: 'Built-in camera'),
        VideoDeviceInfo(deviceId: null, deviceName: 'Unavailable camera'),
        VideoDeviceInfo(deviceId: '', deviceName: 'Empty camera ID'),
        VideoDeviceInfo(deviceId: '   ', deviceName: 'Blank camera ID'),
        VideoDeviceInfo(deviceId: 'usb', deviceName: 'USB camera'),
      ];
      client.engine.videoDevices.selectedDeviceId = 'usb';
      final before = client.info;

      final cameras = await client.controller.getCameraDevices();

      expect(cameras, isNotNull);
      expect(cameras!.devices.map((device) => device.id), ['built-in', 'usb']);
      expect(cameras.devices.map((device) => device.name),
          ['Built-in camera', 'USB camera']);
      expect(cameras.selectedDeviceId, 'usb');
      expect(client.engine.videoDevices.enumerateCalls, 1);
      expect(client.engine.videoDevices.getDeviceCalls, 1);

      await client.controller.selectCamera('built-in');

      expect(client.engine.videoDevices.setDeviceIds, ['built-in']);
      expect(client.info, before);
      expect(client.info?.video, isTrue);
      expect(client.info?.muted, isTrue);
      await client.controller.selectCamera('   ');
      expect(client.engine.videoDevices.setDeviceIds, ['built-in']);
      await client.controller.switchCamera();
      expect(client.engine.switchCameraCalls, 0);
    });
  }

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.windows,
    TargetPlatform.macOS,
  ]) {
    test('$platform ignores camera changes outside active camera video',
        () async {
      debugDefaultTargetPlatformOverride = platform;
      final client = _CallClient(7);
      addTearDown(client.dispose);

      Future<void> expectNoCameraChange() async {
        await client.controller.switchCamera();
        expect(await client.controller.getCameraDevices(), isNull);
        await client.controller.selectCamera('usb');
        expect(client.engine.switchCameraCalls, 0);
        expect(client.engine.videoDeviceManagerCalls, 0);
      }

      await expectNoCameraChange();
      await client.controller.join(const MessageTarget.user(uid: 42));
      client.engine.confirmJoin();
      await expectNoCameraChange();
      await client.controller.openCamera();
      await client.controller.closeCamera();
      await expectNoCameraChange();
      await client.controller.startShareScreen();
      expect(client.info?.shareScreen, isTrue);
      await expectNoCameraChange();
      await client.controller.leave();
      await expectNoCameraChange();
    });
  }

  test('disposed controller ignores camera operations', () async {
    final client = _CallClient(7);
    await client.controller.join(const MessageTarget.user(uid: 42));
    await client.controller.openCamera();
    client.dispose();

    await client.controller.switchCamera();
    expect(await client.controller.getCameraDevices(), isNull);
    await client.controller.selectCamera('usb');

    expect(client.engine.switchCameraCalls, 0);
    expect(client.engine.videoDeviceManagerCalls, 0);
    await client.engine.released.future;
  });

  test('an empty camera list does not query a nonexistent current device',
      () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    await client.controller.openCamera();
    client.engine.videoDevices.devices = const [
      VideoDeviceInfo(deviceId: null),
      VideoDeviceInfo(deviceId: ''),
    ];

    final cameras = await client.controller.getCameraDevices();

    expect(cameras, isNotNull);
    expect(cameras!.devices, isEmpty);
    expect(cameras.selectedDeviceId, isNull);
    expect(client.engine.videoDevices.getDeviceCalls, 0);
  });

  test('camera switching propagates native errors and preserves call state',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    await client.controller.openCamera();
    final before = client.info;
    final error = StateError('Native camera switch failed');
    client.engine.switchCameraError = error;

    await expectLater(client.controller.switchCamera(), throwsA(same(error)));

    expect(client.info, before);
  });

  for (final operation in ['enumerate', 'get', 'set']) {
    test('camera device $operation propagates native errors', () async {
      final client = _CallClient(7);
      addTearDown(client.dispose);
      await client.controller.join(const MessageTarget.user(uid: 42));
      await client.controller.openCamera();
      final before = client.info;
      final error = StateError('Native camera device $operation failed');
      final devices = client.engine.videoDevices;
      switch (operation) {
        case 'enumerate':
          devices.enumerateError = error;
        case 'get':
          devices.getDeviceError = error;
        case 'set':
          devices.setDeviceError = error;
      }

      await expectLater(
        operation == 'set'
            ? client.controller.selectCamera('usb')
            : client.controller.getCameraDevices(),
        throwsA(same(error)),
      );

      expect(client.info, before);
    });
  }

  test('hanging up during camera enumeration skips reading the current device',
      () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    await client.controller.openCamera();
    final gate = Completer<List<VideoDeviceInfo>>();
    client.engine.videoDevices.enumerateWait = gate;

    final loading = client.controller.getCameraDevices();
    await Future<void>.delayed(Duration.zero);
    expect(client.engine.videoDevices.enumerateCalls, 1);
    await client.controller.leave();
    gate.complete(const [VideoDeviceInfo(deviceId: 'usb', deviceName: 'USB')]);

    expect(await loading, isNull);
    expect(client.engine.videoDevices.getDeviceCalls, 0);
    expect(client.info, isNull);
  });

  test('closing the camera during enumeration skips reading the current device',
      () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    await client.controller.openCamera();
    final gate = Completer<List<VideoDeviceInfo>>();
    client.engine.videoDevices.enumerateWait = gate;

    final loading = client.controller.getCameraDevices();
    await Future<void>.delayed(Duration.zero);
    await client.controller.closeCamera();
    gate.complete(const [VideoDeviceInfo(deviceId: 'usb', deviceName: 'USB')]);

    expect(await loading, isNull);
    expect(client.engine.videoDevices.getDeviceCalls, 0);
    expect(client.info?.video, isFalse);
  });

  test('camera enumeration cannot return devices for a subsequent call',
      () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    await client.controller.openCamera();
    final gate = Completer<String>();
    client.engine.videoDevices.getDeviceWait = gate;

    final loading = client.controller.getCameraDevices();
    await Future<void>.delayed(Duration.zero);
    expect(client.engine.videoDevices.getDeviceCalls, 1);
    await client.controller.leave();
    await client.controller.join(const MessageTarget.user(uid: 55));
    await client.controller.openCamera();
    gate.complete('usb');

    expect(await loading, isNull);
    expect(client.info?.context, const MessageTarget.user(uid: 55));
    expect(client.info?.video, isTrue);
  });

  test('hanging up during camera preview cannot restore or publish video',
      () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    final gate = Completer<void>();
    client.engine.startPreviewWait = gate;

    final opening = client.controller.openCamera();
    await Future<void>.delayed(Duration.zero);
    expect(client.engine.startPreviewCalls, 1);
    await client.controller.leave();
    gate.complete();
    await opening;

    expect(client.info, isNull);
    expect(
      client.engine.channelMediaUpdates
          .where((options) => options.publishCameraTrack == true),
      isEmpty,
    );
  });

  test('an old pending camera close cannot disable a subsequent video call',
      () async {
    final client = _CallClient(7);
    addTearDown(client.dispose);
    await client.controller.join(const MessageTarget.user(uid: 42));
    await client.controller.openCamera();
    final gate = Completer<void>();
    client.engine.muteLocalVideoWait = gate;

    final closing = client.controller.closeCamera();
    await Future<void>.delayed(Duration.zero);
    expect(client.engine.mutedLocalVideoCalls.last, isTrue);
    await client.controller.leave();
    await client.controller.join(const MessageTarget.user(uid: 55));
    await client.controller.openCamera();
    final updatesBeforeCompletion = client.engine.channelMediaUpdates.length;
    gate.complete();
    await closing;

    expect(client.info?.context, const MessageTarget.user(uid: 55));
    expect(client.info?.video, isTrue);
    expect(
        client.engine.channelMediaUpdates, hasLength(updatesBeforeCompletion));
    expect(client.engine.channelMediaUpdates.last.publishCameraTrack, isTrue);
  });

  for (final opening in [true, false]) {
    test('pending camera ${opening ? 'open' : 'close'} preserves mute changes',
        () async {
      final client = _CallClient(7);
      addTearDown(client.dispose);
      await client.controller.join(const MessageTarget.user(uid: 42));
      if (!opening) await client.controller.openCamera();
      final gate = Completer<void>();
      if (opening) {
        client.engine.startPreviewWait = gate;
      } else {
        client.engine.muteLocalVideoWait = gate;
      }

      final changing = opening
          ? client.controller.openCamera()
          : client.controller.closeCamera();
      await Future<void>.delayed(Duration.zero);
      if (opening) {
        expect(client.engine.startPreviewCalls, 1);
      } else {
        expect(client.engine.mutedLocalVideoCalls.last, isTrue);
      }
      await client.controller.setMuted(true);
      gate.complete();
      await changing;

      expect(client.info?.muted, isTrue);
      expect(client.info?.video, opening);
      expect(client.info?.context, const MessageTarget.user(uid: 42));
    });
  }
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
  int enableVideoCalls = 0;
  bool? localVideoEnabled;
  final mediaSetup = <String>[];
  int switchCameraCalls = 0;
  int startPreviewCalls = 0;
  int videoDeviceManagerCalls = 0;
  final mutedLocalVideoCalls = <bool>[];
  final channelMediaUpdates = <ChannelMediaOptions>[];
  Object? switchCameraError;
  Completer<void>? leaveWait;
  Completer<void>? releaseWait;
  Completer<void>? initializeWait;
  Completer<void>? videoSetupWait;
  Completer<void>? volumeSetupWait;
  Completer<void>? startPreviewWait;
  Completer<void>? muteLocalVideoWait;
  final released = Completer<void>();
  final pip = _FakePipController();
  final videoDevices = _FakeVideoDeviceManager();

  @override
  Future<void> initialize(RtcEngineContext context) async {
    initializeCalls++;
    await initializeWait?.future;
  }

  @override
  Future<void> enableVideo() async {
    enableVideoCalls++;
    mediaSetup.add('enable-video');
    await videoSetupWait?.future;
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
    mediaSetup.add('join');
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

  void remoteJoined(int uid) => handler.onUserJoined!(connection, uid, 0);

  void remoteVideoDecoding(int uid) => handler.onRemoteVideoStateChanged!(
        connection,
        uid,
        RemoteVideoState.remoteVideoStateDecoding,
        RemoteVideoStateReason.remoteVideoStateReasonInternal,
        0,
      );

  @override
  Future<void> leaveChannel({LeaveChannelOptions? options}) async {
    leaveCalls++;
    if (failLeave) throw StateError('Native leave failed');
    await leaveWait?.future;
  }

  @override
  Future<void> stopPreview({VideoSourceType? sourceType}) async {}

  @override
  Future<void> startPreview({
    VideoSourceType sourceType = VideoSourceType.videoSourceCameraPrimary,
  }) async {
    startPreviewCalls++;
    await startPreviewWait?.future;
  }

  @override
  Future<void> enableLocalVideo(bool enabled) async {
    localVideoEnabled = enabled;
    mediaSetup.add('local-video:$enabled');
  }

  @override
  Future<void> muteLocalVideoStream(bool mute) async {
    mutedLocalVideoCalls.add(mute);
    if (mute) await muteLocalVideoWait?.future;
  }

  @override
  Future<void> muteLocalAudioStream(bool mute) async {}

  @override
  Future<void> updateChannelMediaOptions(ChannelMediaOptions options) async {
    channelMediaUpdates.add(options);
  }

  @override
  Future<void> switchCamera() async {
    switchCameraCalls++;
    if (switchCameraError case final error?) throw error;
  }

  @override
  VideoDeviceManager getVideoDeviceManager() {
    videoDeviceManagerCalls++;
    return videoDevices;
  }

  @override
  Future<List<ScreenCaptureSourceInfo>> getScreenCaptureSources({
    required SIZE thumbSize,
    required SIZE iconSize,
    required bool includeScreen,
  }) async =>
      const [
        ScreenCaptureSourceInfo(
          type: ScreenCaptureSourceType.screencapturesourcetypeScreen,
          sourceId: 1,
          primaryMonitor: true,
        ),
      ];

  @override
  Future<void> startScreenCaptureByDisplayId({
    required int displayId,
    required Rectangle regionRect,
    required ScreenCaptureParameters captureParams,
  }) async {}

  @override
  Future<void> startScreenCapture(
      ScreenCaptureParameters2 captureParams) async {}

  @override
  Future<void> stopScreenCapture() async {}

  @override
  Future<void> release({bool sync = false}) async {
    releaseCalls++;
    if (!released.isCompleted) released.complete();
    await releaseWait?.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVideoDeviceManager implements VideoDeviceManager {
  List<VideoDeviceInfo> devices = const [
    VideoDeviceInfo(deviceId: 'usb', deviceName: 'USB camera'),
  ];
  String selectedDeviceId = 'usb';
  int enumerateCalls = 0;
  int getDeviceCalls = 0;
  final setDeviceIds = <String>[];
  Object? enumerateError;
  Object? getDeviceError;
  Object? setDeviceError;
  Completer<List<VideoDeviceInfo>>? enumerateWait;
  Completer<String>? getDeviceWait;

  @override
  Future<List<VideoDeviceInfo>> enumerateVideoDevices() async {
    enumerateCalls++;
    if (enumerateError case final error?) throw error;
    return enumerateWait != null ? await enumerateWait!.future : devices;
  }

  @override
  Future<String> getDevice() async {
    getDeviceCalls++;
    if (getDeviceError case final error?) throw error;
    return getDeviceWait != null
        ? await getDeviceWait!.future
        : selectedDeviceId;
  }

  @override
  Future<void> setDevice(String deviceIdUTF8) async {
    setDeviceIds.add(deviceIdUTF8);
    if (setDeviceError case final error?) throw error;
    selectedDeviceId = deviceIdUTF8;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePipController implements AgoraPipController {
  bool failDispose = false;
  bool supported = true;
  bool autoEnterSupported = true;
  bool setupSucceeds = true;
  bool startSucceeds = true;
  bool activated = false;
  int startCalls = 0;
  int stopCalls = 0;
  int pipDisposeCalls = 0;
  AgoraPipStateChangedObserver? observer;
  final configurations = <AgoraPipOptions>[];
  Completer<void>? setupWait;
  Completer<bool>? activatedWait;
  Completer<void>? disposeWait;

  @override
  Future<void> registerPipStateChangedObserver(
      AgoraPipStateChangedObserver observer) async {
    this.observer = observer;
  }

  @override
  Future<void> unregisterPipStateChangedObserver() async {
    observer = null;
  }

  @override
  Future<bool> pipIsSupported() async => supported;

  @override
  Future<bool> pipIsAutoEnterSupported() async => autoEnterSupported;

  @override
  Future<bool> isPipActivated() async =>
      activatedWait != null ? await activatedWait!.future : activated;

  @override
  Future<bool> pipSetup(AgoraPipOptions options) async {
    configurations.add(options);
    await setupWait?.future;
    return setupSucceeds;
  }

  @override
  Future<bool> pipStart() async {
    startCalls++;
    if (startSucceeds) reportState(AgoraPipState.pipStateStarted);
    return startSucceeds;
  }

  @override
  Future<void> pipStop() async {
    stopCalls++;
    reportState(AgoraPipState.pipStateStopped);
  }

  @override
  Future<void> pipDispose() async {
    pipDisposeCalls++;
    activated = false;
  }

  void reportState(AgoraPipState state, [String? error]) {
    activated = state == AgoraPipState.pipStateStarted;
    observer?.onPipStateChanged(state, error);
  }

  @override
  Future<void> dispose() async {
    if (failDispose) throw StateError('Native PiP disposal failed');
    await disposeWait?.future;
    await pipDispose();
    await unregisterPipStateChangedObserver();
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
