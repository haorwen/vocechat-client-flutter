import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_log.dart';
import '../data/agora_api.dart';
import 'avo_interaction_controller.dart';
import '../domain/voice_models.dart';
import '../../messages/domain/message_models.dart';

part 'voice_controller.g.dart';

// ---------------------------------------------------------------------------
// VoiceController — owns the AgoraRtcEngine singleton for the app lifetime.
// ---------------------------------------------------------------------------
//
// Mirrors the web reference's `window.VOICE_CLIENT` + `useVoice.ts`: one
// engine instance, join/leave/mute/deafen/camera/screen-share, and a roster
// of remote members (speaking volume, mute, video flags). See
// `vocechat-web-just-reference/src/components/Voice/{index,useVoice}.ts`.
//
// Channel naming (`vocechat:dm:{uid}` / `vocechat:group:{gid}`) is decided
// server-side by `POST /admin/agora/token` — this controller never
// constructs channel names itself.

/// No official agora_rtc_engine support on Linux desktop — voice entry
/// points must be hidden there. Exposed as a plain function (not a provider)
/// so presentation widgets can check it without any Riverpod plumbing.
bool get isVoiceCallingSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;

bool get isVoiceCameraFlipSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get isVoiceCameraSelectionSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS);

final agoraRtcEngineFactoryProvider = Provider<RtcEngine Function()>(
  (ref) => createAgoraRtcEngine,
);

final agoraPipControllerFactoryProvider =
    Provider<AgoraPipController Function(RtcEngine)>(
  (ref) => (engine) => engine.createPipController(),
);

final voiceResourceCleanupTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

// Agora owns process-wide native resources. A new ProviderScope created by UI
// recovery must not create its engine while the previous scope is releasing it.
Future<void>? _pendingEngineRelease;

@Riverpod(keepAlive: true)
class VoiceController extends _$VoiceController with WidgetsBindingObserver {
  RtcEngine? _engine;
  Future<void>? _engineInitialization;
  Future<RtcEngine>? _engineSetup;
  int _callGeneration = 0;
  RtcEngineEventHandler? _eventHandler;
  AgoraPipController? _pipController;
  bool _disposed = false;
  late Duration _cleanupTimeout;
  String? _channelName;
  int? _localUid;
  int? _desiredPipRemoteUid;
  int? _configuredPipRemoteUid;
  bool _pipAutoEnterEnabled = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  Future<void> _pipOperations = Future<void>.value();

  /// Android PiP shrinks the Flutter activity itself. The app root listens to
  /// this notifier and temporarily covers the normal UI with the one eligible
  /// remote video. iOS renders the remote stream in a native PiP content view.
  final ValueNotifier<int?> pictureInPictureRemoteUid = ValueNotifier(null);

  RtcEngine? get engineOrNull => _engine;

  /// The joined channel name, or null if not currently in a call. Needed by
  /// [VoiceFullscreenView] to build the [RtcConnection] remote video canvases
  /// require.
  String? get channelNameOrNull => _channelName;

  /// Our own uid within the joined channel (the Agora-assigned uid, which
  /// mirrors the VoceChat uid per the server's token endpoint).
  int? get localUidOrNull => _localUid;

  @override
  VoicingInfo? build() {
    _cleanupTimeout = ref.read(voiceResourceCleanupTimeoutProvider);
    WidgetsBinding.instance.addObserver(this);
    members.addListener(_syncPictureInPictureEligibility);
    ref.onDispose(() {
      _disposed = true;
      WidgetsBinding.instance.removeObserver(this);
      members.removeListener(_syncPictureInPictureEligibility);
      _beginNativeDisposal();
      pictureInPictureRemoteUid.dispose();
      members.dispose();
    });
    return null;
  }

  final ValueNotifier<VoicingMembers> members =
      ValueNotifier(const VoicingMembers());

  void _beginNativeDisposal() {
    final pipController = _pipController;
    final engine = _engine;
    final initializing = _engineInitialization;
    final handler = _eventHandler;
    _engine = null;
    _engineInitialization = null;
    _pipController = null;
    _eventHandler = null;
    _channelName = null;
    _localUid = null;
    _desiredPipRemoteUid = null;
    if (engine == null && pipController == null) return;

    if (engine != null && handler != null) {
      try {
        engine.unregisterEventHandler(handler);
      } catch (error, stack) {
        AppLog.e(LogTag.voice, () => 'voice event handler cleanup failed',
            error: error, stackTrace: stack);
      }
    }
    final cleanup =
        _disposeNativeResources(engine, pipController, initializing);
    _pendingEngineRelease = cleanup;
    unawaited(cleanup.then<void>((_) {
      if (identical(_pendingEngineRelease, cleanup)) {
        _pendingEngineRelease = null;
      }
    }, onError: (Object error, StackTrace stack) {
      // Keep the failed barrier: creating another native singleton after a
      // failed release is unsafe. A subsequent call reports that failure.
      AppLog.e(LogTag.voice, () => 'voice engine release failed',
          error: error, stackTrace: stack);
    }));
  }

  Future<void> _disposeNativeResources(
    RtcEngine? engine,
    AgoraPipController? pipController,
    Future<void>? initializing,
  ) async {
    final pendingNativeCalls = <Future<void>>[];
    var initializationFinished = initializing == null;
    if (initializing != null) {
      pendingNativeCalls.add(initializing.then<void>(
        (_) => initializationFinished = true,
        onError: (Object _, StackTrace __) => initializationFinished = true,
      ));
    }
    Future<void> attempt(
        String operation, Future<void> Function() action) async {
      final pending = Future<void>.sync(action);
      // A timeout only stops our wait, not the native call. Keep the barrier
      // until late native calls settle so they cannot affect a new engine.
      pendingNativeCalls.add(
          pending.then<void>((_) {}, onError: (Object _, StackTrace __) {}));
      try {
        await pending.timeout(_cleanupTimeout);
      } catch (error, stack) {
        AppLog.e(LogTag.voice, () => '$operation during voice cleanup failed',
            error: error, stackTrace: stack);
      }
    }

    if (initializing != null) {
      await attempt('finishing engine initialization', () => initializing);
    }
    if (pipController != null) {
      await attempt('finishing PiP operations', () => _pipOperations);
      await attempt('disposing PiP', pipController.dispose);
    }
    if (engine != null) {
      await attempt('leaving channel', engine.leaveChannel);
      // Always reach release even if PiP/leave throws or never responds. The
      // UI does not await it. New calls use a bounded wait on this *actual*
      // release future, so a hung release cannot race a replacement engine.
      final releaseBeforeInitialized = !initializationFinished;
      await engine.release();
      await Future.wait(pendingNativeCalls);
      if (releaseBeforeInitialized) {
        // initialize completed after the first release attempt. Release again
        // before permitting a new engine, rather than leaking the late engine.
        await engine.release();
      }
    }
  }

  Future<RtcEngine> _ensureEngine(String appId) {
    final active = _engineSetup;
    if (active != null) return active;
    final setup = _createEngine(appId);
    _engineSetup = setup;
    return setup.whenComplete(() {
      if (identical(_engineSetup, setup)) _engineSetup = null;
    });
  }

  Future<RtcEngine> _createEngine(String appId) async {
    if (_disposed) throw StateError('Voice controller has been disposed');
    final existing = _engine;
    if (existing != null) return existing;

    await _pendingEngineRelease?.timeout(_cleanupTimeout * 4);
    if (_disposed) throw StateError('Voice controller has been disposed');
    final engine = ref.read(agoraRtcEngineFactoryProvider)();
    // Own an initializing engine too, so recovery can release it even before
    // the platform's initialize response has arrived.
    _engine = engine;
    try {
      final initializing = engine.initialize(RtcEngineContext(appId: appId));
      _engineInitialization = initializing;
      await initializing;
      _engineInitialization = null;
      if (_disposed) throw StateError('Voice controller has been disposed');
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        _pipController = ref.read(agoraPipControllerFactoryProvider)(engine);
      }
      await engine.enableAudioVolumeIndication(
        interval: 150,
        smooth: 3,
        reportVad: false,
      );
      if (_disposed) throw StateError('Voice controller has been disposed');

      final handler = RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          if (!_isCurrentConnection(connection)) return;
          AppLog.d(
              LogTag.voice, () => '🎙️ joined channel=${connection.channelId}');
          final current = state!;
          _upsertMember(_localUid!, const VoicingMemberInfo());
          state = current.copyWith(
            joining: false,
            connectionState: VoiceConnectionState.connected,
          );
          _syncPictureInPictureEligibility();
          unawaited(ref
              .read(avoInteractionControllerProvider.notifier)
              .joinRoom(current.context));
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          if (!_isCurrentConnection(connection)) return;
          AppLog.d(
              LogTag.voice,
              () =>
                  'remote joined channel=${connection.channelId} uid=$remoteUid');
          _upsertMember(remoteUid, const VoicingMemberInfo());
        },
        onUserOffline: (connection, remoteUid, reason) {
          if (!_isCurrentConnection(connection)) return;
          if (reason == UserOfflineReasonType.userOfflineQuit ||
              reason == UserOfflineReasonType.userOfflineDropped) {
            _removeMember(remoteUid);
          }
        },
        onUserMuteAudio: (connection, remoteUid, muted) {
          if (!_isCurrentConnection(connection)) return;
          _patchMember(remoteUid, (m) => m.copyWith(muted: muted));
        },
        onUserMuteVideo: (connection, remoteUid, muted) {
          if (!_isCurrentConnection(connection)) return;
          _patchMember(
            remoteUid,
            (m) => m.copyWith(
                video: !muted, shareScreen: muted ? false : m.shareScreen),
          );
        },
        onRemoteVideoStateChanged:
            (connection, remoteUid, videoState, reason, elapsed) {
          if (!_isCurrentConnection(connection)) return;
          final bool? videoEnabled = switch (reason) {
            RemoteVideoStateReason.remoteVideoStateReasonRemoteMuted ||
            RemoteVideoStateReason.remoteVideoStateReasonRemoteOffline =>
              false,
            RemoteVideoStateReason.remoteVideoStateReasonRemoteUnmuted => true,
            _ when videoState == RemoteVideoState.remoteVideoStateDecoding =>
              true,
            _ => null,
          };
          if (videoEnabled != null) {
            _patchMember(
              remoteUid,
              (m) => m.copyWith(
                video: videoEnabled,
                shareScreen: videoEnabled ? m.shareScreen : false,
              ),
            );
          }
        },
        onAudioVolumeIndication:
            (connection, speakers, speakerNumber, totalVolume) {
          if (!_isCurrentConnection(connection)) return;
          for (final s in speakers) {
            final uid = s.uid;
            final volume = s.volume;
            if (uid == null || volume == null) continue;
            // uid 0 in this callback means "the local user" — reflect it onto
            // our own VoicingInfo isn't needed (we don't render our own
            // speaking ring), so only track remotes here.
            if (uid == 0) {
              final current = state;
              if (current != null) {
                state = current.copyWith(speakingVolume: volume);
              }
              continue;
            }
            _patchMember(uid, (m) => m.copyWith(speakingVolume: volume));
          }
        },
        onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
          if (!_isCurrentConnection(connection)) return;
          if (remoteUid != 0) return;
          state = state?.copyWith(downlinkNetworkQuality: rxQuality.value());
        },
        onConnectionStateChanged: (connection, connectionState, reason) {
          if (!_isCurrentConnection(connection)) return;
          AppLog.d(
              LogTag.voice,
              () =>
                  'channel=${connection.channelId} state=$connectionState reason=$reason');
          state = state?.copyWith(
            connectionState: _mapConnectionState(connectionState),
            joining:
                connectionState == ConnectionStateType.connectionStateFailed ||
                        connectionState ==
                            ConnectionStateType.connectionStateDisconnected
                    ? false
                    : state!.joining,
          );
          _syncPictureInPictureEligibility();
        },
        onLocalVideoStateChanged: (source, videoState, reason) {
          if (_disposed || !_isScreenSource(source)) return;
          AppLog.d(
            LogTag.voice,
            () => 'screen capture state=$videoState reason=$reason',
          );
          if (videoState == LocalVideoStreamState.localVideoStreamStateFailed ||
              videoState ==
                  LocalVideoStreamState.localVideoStreamStateStopped) {
            final current = state;
            if (current != null && current.shareScreen) {
              state = current.copyWith(shareScreen: false);
            }
          }
        },
        onPermissionError: (permissionType) {
          AppLog.w(
            LogTag.voice,
            () => 'Agora permission denied: $permissionType',
          );
        },
        onError: (code, message) {
          AppLog.e(
              LogTag.voice,
              () =>
                  'Agora error channel=$_channelName code=$code message=$message');
        },
      );
      _eventHandler = handler;
      engine.registerEventHandler(handler);

      return engine;
    } catch (_) {
      if (!_disposed) _beginNativeDisposal();
      rethrow;
    }
  }

  bool _isCurrentConnection(RtcConnection connection) =>
      !_disposed &&
      state != null &&
      _channelName != null &&
      connection.channelId == _channelName &&
      connection.localUid == _localUid;

  VoiceConnectionState _mapConnectionState(ConnectionStateType s) {
    switch (s) {
      case ConnectionStateType.connectionStateConnecting:
        return VoiceConnectionState.connecting;
      case ConnectionStateType.connectionStateConnected:
        return VoiceConnectionState.connected;
      case ConnectionStateType.connectionStateReconnecting:
        return VoiceConnectionState.reconnecting;
      case ConnectionStateType.connectionStateFailed:
        return VoiceConnectionState.failed;
      case ConnectionStateType.connectionStateDisconnected:
        return VoiceConnectionState.disconnected;
    }
  }

  void _syncPictureInPictureEligibility() {
    if (_disposed) return;
    final remoteUid = remoteVideoUidForPictureInPicture(
      call: state,
      members: members.value,
      localUid: _localUid,
    );
    if (_desiredPipRemoteUid == remoteUid) return;

    _desiredPipRemoteUid = remoteUid;
    if (remoteUid == null) {
      pictureInPictureRemoteUid.value = null;
    }
    _queuePipOperation(_applyPictureInPictureConfiguration);
  }

  void _queuePipOperation(Future<void> Function() operation) {
    if (_disposed) return;
    _pipOperations = _pipOperations.then<void>((_) async {
      if (_disposed) return;
      await operation();
    }).onError(
      (error, stackTrace) {
        AppLog.e(
          LogTag.voice,
          () => 'picture-in-picture operation failed',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  Future<void> _applyPictureInPictureConfiguration() async {
    if (_disposed) return;
    final pipController = _pipController;
    final remoteUid = _desiredPipRemoteUid;
    final channelName = _channelName;
    final localUid = _localUid;
    if (pipController == null) return;

    if (remoteUid == null || channelName == null || localUid == null) {
      if (_configuredPipRemoteUid != null) {
        await pipController.pipDispose();
        _configuredPipRemoteUid = null;
      }
      return;
    }
    if (_configuredPipRemoteUid == remoteUid) {
      if (_appLifecycleState != AppLifecycleState.resumed) {
        await _enterPictureInPictureIfEligible();
      }
      return;
    }

    if (_configuredPipRemoteUid != null) {
      await pipController.pipDispose();
      if (_disposed) return;
      _configuredPipRemoteUid = null;
    }
    if (!await pipController.pipIsSupported() || _disposed) return;

    final autoEnterSupported = await pipController.pipIsAutoEnterSupported();
    if (_disposed) return;
    // Android is started explicitly after the final Dart-side eligibility
    // check. Native auto-enter can race a remote camera-off/member-join event.
    _pipAutoEnterEnabled =
        defaultTargetPlatform == TargetPlatform.iOS && autoEnterSupported;
    final options = defaultTargetPlatform == TargetPlatform.android
        ? AgoraPipOptions(
            autoEnterEnabled: false,
            aspectRatioX: 16,
            aspectRatioY: 9,
            seamlessResizeEnabled: true,
            useExternalStateMonitor: false,
          )
        : AgoraPipOptions(
            autoEnterEnabled: _pipAutoEnterEnabled,
            sourceContentView: 0,
            contentView: 0,
            preferredContentWidth: 480,
            preferredContentHeight: 270,
            contentViewLayout: const AgoraPipContentViewLayout(
              padding: 0,
              spacing: 0,
              row: 1,
              column: 1,
            ),
            videoStreams: [
              AgoraPipVideoStream(
                connection: RtcConnection(
                  channelId: channelName,
                  localUid: localUid,
                ),
                canvas: VideoCanvas(
                  uid: remoteUid,
                  sourceType: VideoSourceType.videoSourceRemote,
                  setupMode: VideoViewSetupMode.videoViewSetupAdd,
                  renderMode: RenderModeType.renderModeHidden,
                ),
              ),
            ],
            controlStyle: 2,
          );
    if (!await pipController.pipSetup(options) || _disposed) return;

    _configuredPipRemoteUid = remoteUid;
    if (_desiredPipRemoteUid != remoteUid) {
      await _applyPictureInPictureConfiguration();
    } else if (_appLifecycleState != AppLifecycleState.resumed) {
      await _enterPictureInPictureIfEligible();
    }
  }

  Future<void> _enterPictureInPictureIfEligible() async {
    if (_disposed) return;
    final pipController = _pipController;
    final remoteUid = _desiredPipRemoteUid;
    if (pipController == null ||
        remoteUid == null ||
        _configuredPipRemoteUid != remoteUid ||
        _appLifecycleState == AppLifecycleState.resumed) {
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      pictureInPictureRemoteUid.value = remoteUid;
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed) return;
      if (_desiredPipRemoteUid != remoteUid ||
          _appLifecycleState == AppLifecycleState.resumed) {
        pictureInPictureRemoteUid.value = null;
        return;
      }
    }

    if (!_pipAutoEnterEnabled && !await pipController.isPipActivated()) {
      if (_disposed) return;
      await pipController.pipStart();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    _appLifecycleState = state;
    switch (state) {
      case AppLifecycleState.resumed:
        pictureInPictureRemoteUid.value = null;
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            _configuredPipRemoteUid != null) {
          _queuePipOperation(() => _pipController!.pipStop());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_desiredPipRemoteUid != null) {
          _queuePipOperation(_applyPictureInPictureConfiguration);
        }
      case AppLifecycleState.detached:
        pictureInPictureRemoteUid.value = null;
    }
  }

  void _upsertMember(int uid, VoicingMemberInfo info) {
    if (_disposed) return;
    final current = members.value;
    if (current.ids.contains(uid)) return;
    members.value = current.copyWith(
      ids: [...current.ids, uid],
      byId: {...current.byId, uid: info},
    );
  }

  void _removeMember(int uid) {
    if (_disposed) return;
    final current = members.value;
    if (!current.ids.contains(uid)) return;
    final nextById = Map<int, VoicingMemberInfo>.from(current.byId)
      ..remove(uid);
    members.value = current.copyWith(
      ids: current.ids.where((id) => id != uid).toList(),
      byId: nextById,
      pin: current.pin == uid ? null : current.pin,
    );
  }

  void _patchMember(
    int uid,
    VoicingMemberInfo Function(VoicingMemberInfo) patch,
  ) {
    if (_disposed) return;
    final current = members.value;
    if (!current.ids.contains(uid)) return;
    final existing = current.byId[uid] ?? const VoicingMemberInfo();
    members.value = current.copyWith(
      byId: {...current.byId, uid: patch(existing)},
    );
  }

  // ---------------------------------------------------------------------------
  // Join / leave
  // ---------------------------------------------------------------------------

  /// Requests a token, joins the channel, and publishes the local microphone
  /// track. [context] is the DM peer or channel to call.
  /// When answering a DM, [dmChannelOwnerUid] is the invite's callee (`toUid`),
  /// while [context] still points to the caller for chat navigation and Avo.
  /// Both participants must request a token for the callee's RTC channel.
  Future<void> join(MessageTarget context, {int? dmChannelOwnerUid}) async {
    if (_disposed) return;
    if (state != null || _channelName != null) {
      await leave();
    }
    if (_disposed) return;
    final generation = ++_callGeneration;
    members.value = const VoicingMembers();
    state = VoicingInfo(
      context: context,
      joining: true,
      connectionState: VoiceConnectionState.connecting,
    );
    try {
      final api = ref.read(agoraApiProvider);
      final token = await context.map(
        user: (t) => api.generateToken(uid: dmChannelOwnerUid ?? t.uid),
        group: (t) => api.generateToken(gid: t.gid),
      );
      if (_disposed || generation != _callGeneration) return;

      final engine = await _ensureEngine(token.appId);
      if (_disposed || generation != _callGeneration) return;
      // Native joinChannel completes when the request is accepted. Only
      // onJoinChannelSuccess confirms membership (unlike Web client.join).
      _channelName = token.channelName;
      _localUid = token.uid;
      AppLog.d(
          LogTag.voice,
          () =>
              'joining channel=${token.channelName} uid=${token.uid} peer=$context');
      await engine.joinChannel(
        token: token.agoraToken,
        channelId: token.channelName,
        uid: token.uid,
        options: const ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishMicrophoneTrack: true,
          publishCameraTrack: false,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (e, st) {
      if (_disposed || generation != _callGeneration) return;
      AppLog.e(LogTag.voice, () => 'join failed', error: e, stackTrace: st);
      _channelName = null;
      _localUid = null;
      state = null;
      members.value = const VoicingMembers();
      _syncPictureInPictureEligibility();
      rethrow;
    }
  }

  Future<void> leave() async {
    if (_disposed) return;
    _callGeneration++;
    final engine = _engine;
    final hadChannel = _channelName != null;
    final current = state;
    unawaited(ref.read(avoInteractionControllerProvider.notifier).leaveRoom());
    _channelName = null;
    _localUid = null;
    state = null;
    members.value = const VoicingMembers();
    _syncPictureInPictureEligibility();
    await _pipOperations;
    if (_disposed) return;

    // A second join can cancel the first while its shared engine is still
    // initializing. There is no native channel to leave in that case.
    if (engine != null && hadChannel) {
      if (current?.shareScreen ?? false) {
        await engine.stopScreenCapture();
        if (_disposed) return;
      }
      await engine.leaveChannel();
      if (_disposed) return;
      await engine.stopPreview();
    }
  }

  // ---------------------------------------------------------------------------
  // Mute / deafen
  // ---------------------------------------------------------------------------

  Future<void> setMuted(bool muted) async {
    if (_disposed) return;
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    await engine.muteLocalAudioStream(muted);
    if (_disposed) return;
    // Web parity: unmuting clears deafen (you can't hear others while
    // deafened, so re-enabling your mic implies you want audio back too).
    state = current.copyWith(
      muted: muted,
      deafen: muted ? current.deafen : false,
    );
    if (!muted && current.deafen) {
      await engine.muteAllRemoteAudioStreams(false);
    }
  }

  Future<void> setDeafen(bool deafen) async {
    if (_disposed) return;
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    await engine.muteLocalAudioStream(deafen);
    if (_disposed) return;
    await engine.muteAllRemoteAudioStreams(deafen);
    if (_disposed) return;
    state = current.copyWith(deafen: deafen, muted: deafen);
  }

  // ---------------------------------------------------------------------------
  // Camera / screen share (mutually exclusive local video sources)
  // ---------------------------------------------------------------------------

  Future<void> openCamera() async {
    if (_disposed) return;
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    final generation = _callGeneration;
    if (current.shareScreen) await _stopShareScreenInternal(engine);
    if (!_isCurrentCameraCall(engine, generation)) return;
    await engine.enableLocalVideo(true);
    if (!_isCurrentCameraCall(engine, generation)) return;
    await engine.muteLocalVideoStream(false);
    if (!_isCurrentCameraCall(engine, generation)) return;
    await engine.startPreview();
    if (!_isCurrentCameraCall(engine, generation)) return;
    await engine.updateChannelMediaOptions(
      const ChannelMediaOptions(
        publishCameraTrack: true,
        publishScreenTrack: false,
      ),
    );
    if (!_isCurrentCameraCall(engine, generation)) return;
    state = state!.copyWith(video: true, shareScreen: false);
  }

  Future<void> closeCamera() async {
    if (_disposed) return;
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    final generation = _callGeneration;
    await engine.muteLocalVideoStream(true);
    if (!_isCurrentCameraCall(engine, generation)) return;
    await engine.updateChannelMediaOptions(
      const ChannelMediaOptions(publishCameraTrack: false),
    );
    if (!_isCurrentCameraCall(engine, generation)) return;
    await engine.stopPreview();
    if (!_isCurrentCameraCall(engine, generation)) return;
    state = state!.copyWith(video: false);
  }

  Future<void> switchCamera() async {
    if (!isVoiceCameraFlipSupported || _disposed) return;
    final engine = _engine;
    if (engine == null || !_canChangeCamera(engine, _callGeneration)) return;
    await engine.switchCamera();
  }

  Future<VoiceCameraDevices?> getCameraDevices() async {
    if (!isVoiceCameraSelectionSupported || _disposed) return null;
    final engine = _engine;
    final generation = _callGeneration;
    if (engine == null || !_canChangeCamera(engine, generation)) return null;

    final manager = engine.getVideoDeviceManager();
    final available = await manager.enumerateVideoDevices();
    if (!_canChangeCamera(engine, generation)) return null;
    final devices = available
        .where((device) => device.deviceId?.trim().isNotEmpty ?? false)
        .map((device) => VoiceCameraDevice(
              id: device.deviceId!,
              name: device.deviceName?.trim() ?? '',
            ))
        .toList(growable: false);
    if (devices.isEmpty) return const VoiceCameraDevices(devices: []);

    final selectedDeviceId = await manager.getDevice();
    if (!_canChangeCamera(engine, generation)) return null;
    return VoiceCameraDevices(
      devices: List.unmodifiable(devices),
      selectedDeviceId: selectedDeviceId,
    );
  }

  Future<void> selectCamera(String deviceId) async {
    if (!isVoiceCameraSelectionSupported ||
        _disposed ||
        deviceId.trim().isEmpty) {
      return;
    }
    final engine = _engine;
    if (engine == null || !_canChangeCamera(engine, _callGeneration)) return;
    await engine.getVideoDeviceManager().setDevice(deviceId);
  }

  bool _canChangeCamera(RtcEngine engine, int generation) {
    return _isCurrentCameraCall(engine, generation) &&
        state?.video == true &&
        state?.shareScreen == false;
  }

  bool _isCurrentCameraCall(RtcEngine engine, int generation) {
    return !_disposed &&
        identical(engine, _engine) &&
        generation == _callGeneration &&
        state != null;
  }

  Future<void> startShareScreen() async {
    if (_disposed) return;
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    if (current.video) await closeCamera();
    if (_disposed) return;

    final desktop = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS;
    var captureStarted = false;
    try {
      if (desktop) {
        // Display id 0 is not a portable primary-display id (on macOS it is
        // normally invalid). Ask Agora for the actual shareable display list
        // and prefer the primary monitor instead.
        final sources = await engine.getScreenCaptureSources(
          thumbSize: const SIZE(width: 1, height: 1),
          iconSize: const SIZE(width: 1, height: 1),
          includeScreen: true,
        );
        if (_disposed) return;
        final screens = sources
            .where(
              (source) =>
                  source.type ==
                      ScreenCaptureSourceType.screencapturesourcetypeScreen &&
                  source.sourceId != null,
            )
            .toList();
        if (screens.isEmpty) {
          throw StateError('Agora did not find a shareable display');
        }
        final primary = screens.firstWhere(
          (source) => source.primaryMonitor == true,
          orElse: () => screens.first,
        );
        AppLog.d(
          LogTag.voice,
          () => 'sharing display id=${primary.sourceId}',
        );
        await engine.startScreenCaptureByDisplayId(
          displayId: primary.sourceId!,
          regionRect: const Rectangle(),
          captureParams: const ScreenCaptureParameters(
            captureMouseCursor: true,
            frameRate: 15,
          ),
        );
        if (_disposed) return;
        captureStarted = true;
        await engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishScreenTrack: true,
            publishCameraTrack: false,
          ),
        );
      } else {
        // Android/iOS: the SDK requests the platform's screen-capture consent
        // (MediaProjection on Android, ReplayKit on iOS). Be explicit about
        // the video flag; omitting it leaves the native SDK default-dependent.
        await engine.startScreenCapture(
          const ScreenCaptureParameters2(
            captureAudio: false,
            captureVideo: true,
          ),
        );
        if (_disposed) return;
        captureStarted = true;
        await engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishScreenCaptureVideo: true,
            publishCameraTrack: false,
          ),
        );
      }
      if (_disposed) return;
      state = (state ?? current).copyWith(shareScreen: true, video: false);
    } catch (error, stackTrace) {
      if (_disposed) return;
      if (captureStarted) {
        try {
          await engine.stopScreenCapture();
        } catch (stopError, stopStackTrace) {
          AppLog.w(
            LogTag.voice,
            () => 'failed to clean up screen capture after start failure',
            error: stopError,
            stackTrace: stopStackTrace,
          );
        }
      }
      AppLog.e(
        LogTag.voice,
        () => 'screen sharing failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> stopShareScreen() async {
    if (_disposed) return;
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    await _stopShareScreenInternal(engine);
    if (_disposed) return;
    state = current.copyWith(shareScreen: false);
  }

  Future<void> _stopShareScreenInternal(RtcEngine engine) async {
    await engine.stopScreenCapture();
    if (_disposed) return;
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(publishScreenTrack: false),
      );
    } else {
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(publishScreenCaptureVideo: false),
      );
    }
  }

  bool _isScreenSource(VideoSourceType source) =>
      source == VideoSourceType.videoSourceScreen ||
      source == VideoSourceType.videoSourceScreenPrimary ||
      source == VideoSourceType.videoSourceScreenSecondary;

  // ---------------------------------------------------------------------------
  // Pin (fullscreen spotlight)
  // ---------------------------------------------------------------------------

  void pin(int uid) {
    if (_disposed) return;
    members.value = members.value.copyWith(pin: uid);
  }

  void unpin() {
    if (_disposed) return;
    members.value = members.value.copyWith(pin: null);
  }
}
