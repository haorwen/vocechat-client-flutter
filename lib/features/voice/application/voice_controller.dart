import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_log.dart';
import '../../auth/application/auth_controller.dart';
import '../data/agora_api.dart';
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

@Riverpod(keepAlive: true)
class VoiceController extends _$VoiceController with WidgetsBindingObserver {
  RtcEngine? _engine;
  AgoraPipController? _pipController;
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
    WidgetsBinding.instance.addObserver(this);
    members.addListener(_syncPictureInPictureEligibility);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      members.removeListener(_syncPictureInPictureEligibility);
      pictureInPictureRemoteUid.dispose();
      members.dispose();
      unawaited(_disposeNativeResources());
    });
    return null;
  }

  final ValueNotifier<VoicingMembers> members =
      ValueNotifier(const VoicingMembers());

  Future<void> _disposeNativeResources() async {
    final pipController = _pipController;
    final engine = _engine;
    if (pipController != null) {
      await pipController.dispose();
    }
    if (engine != null) {
      await engine.leaveChannel();
      await engine.release();
    }
  }

  Future<RtcEngine> _ensureEngine(String appId) async {
    final existing = _engine;
    if (existing != null) return existing;

    final engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(appId: appId));
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      _pipController = engine.createPipController();
    }
    await engine.enableAudioVolumeIndication(
      interval: 2000,
      smooth: 3,
      reportVad: false,
    );

    final handler = RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        AppLog.d(
            LogTag.voice, () => '🎙️ joined channel=${connection.channelId}');
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        _upsertMember(remoteUid, const VoicingMemberInfo());
      },
      onUserOffline: (connection, remoteUid, reason) {
        if (reason == UserOfflineReasonType.userOfflineQuit ||
            reason == UserOfflineReasonType.userOfflineDropped) {
          _removeMember(remoteUid);
        }
      },
      onUserMuteAudio: (connection, remoteUid, muted) {
        _patchMember(remoteUid, (m) => m.copyWith(muted: muted));
      },
      onUserMuteVideo: (connection, remoteUid, muted) {
        _patchMember(
          remoteUid,
          (m) => m.copyWith(
              video: !muted, shareScreen: muted ? false : m.shareScreen),
        );
      },
      onRemoteVideoStateChanged:
          (connection, remoteUid, videoState, reason, elapsed) {
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
        for (final s in speakers) {
          final uid = s.uid;
          final volume = s.volume;
          if (uid == null || volume == null) continue;
          // uid 0 in this callback means "the local user" — reflect it onto
          // our own VoicingInfo isn't needed (we don't render our own
          // speaking ring), so only track remotes here.
          if (uid == 0) continue;
          _patchMember(uid, (m) => m.copyWith(speakingVolume: volume));
        }
      },
      onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
        if (remoteUid != 0) return;
        state = state?.copyWith(downlinkNetworkQuality: rxQuality.value());
      },
      onConnectionStateChanged: (connection, connectionState, reason) {
        state = state?.copyWith(
          connectionState: _mapConnectionState(connectionState),
        );
        _syncPictureInPictureEligibility();
      },
      onLocalVideoStateChanged: (source, videoState, reason) {
        if (!_isScreenSource(source)) return;
        AppLog.d(
          LogTag.voice,
          () => 'screen capture state=$videoState reason=$reason',
        );
        if (videoState == LocalVideoStreamState.localVideoStreamStateFailed ||
            videoState == LocalVideoStreamState.localVideoStreamStateStopped) {
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
      onLeaveChannel: (connection, stats) {
        members.value = const VoicingMembers();
      },
    );
    engine.registerEventHandler(handler);

    _engine = engine;
    return engine;
  }

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
    _pipOperations = _pipOperations.then((_) => operation()).onError(
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
      _configuredPipRemoteUid = null;
    }
    if (!await pipController.pipIsSupported()) return;

    final autoEnterSupported = await pipController.pipIsAutoEnterSupported();
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
    if (!await pipController.pipSetup(options)) return;

    _configuredPipRemoteUid = remoteUid;
    if (_desiredPipRemoteUid != remoteUid) {
      await _applyPictureInPictureConfiguration();
    } else if (_appLifecycleState != AppLifecycleState.resumed) {
      await _enterPictureInPictureIfEligible();
    }
  }

  Future<void> _enterPictureInPictureIfEligible() async {
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
      if (_desiredPipRemoteUid != remoteUid ||
          _appLifecycleState == AppLifecycleState.resumed) {
        pictureInPictureRemoteUid.value = null;
        return;
      }
    }

    if (!_pipAutoEnterEnabled && !await pipController.isPipActivated()) {
      await pipController.pipStart();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    final current = members.value;
    if (current.ids.contains(uid)) return;
    members.value = current.copyWith(
      ids: [...current.ids, uid],
      byId: {...current.byId, uid: info},
    );
  }

  void _removeMember(int uid) {
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
    final current = members.value;
    if (!current.ids.contains(uid)) return;
    final existing = current.byId[uid] ?? const VoicingMemberInfo();
    members.value = current.copyWith(
      byId: {...current.byId, uid: patch(existing)},
    );
  }

  int? _currentUid() {
    final authState = ref.read(authControllerProvider).valueOrNull;
    if (authState is AuthStateAuthenticated) return authState.user.uid;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Join / leave
  // ---------------------------------------------------------------------------

  /// Requests a token, joins the channel, and publishes the local microphone
  /// track. [context] is the DM peer or channel to call.
  Future<void> join(MessageTarget context) async {
    if (state != null || _channelName != null) {
      await leave();
    }
    members.value = const VoicingMembers();
    state = VoicingInfo(context: context, joining: true);
    try {
      final api = ref.read(agoraApiProvider);
      final token = await context.map(
        user: (t) => api.generateToken(uid: t.uid),
        group: (t) => api.generateToken(gid: t.gid),
      );

      final engine = await _ensureEngine(token.appId);
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

      _channelName = token.channelName;
      _localUid = token.uid;
      final selfUid = _currentUid() ?? token.uid;
      _upsertMember(selfUid, const VoicingMemberInfo());

      state = VoicingInfo(
        context: context,
        joining: false,
        connectionState: VoiceConnectionState.connected,
        muted: false,
        deafen: false,
      );
      _syncPictureInPictureEligibility();
    } catch (e, st) {
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
    final engine = _engine;
    final current = state;
    _channelName = null;
    _localUid = null;
    state = null;
    members.value = const VoicingMembers();
    _syncPictureInPictureEligibility();
    await _pipOperations;

    if (engine != null) {
      if (current?.shareScreen ?? false) {
        await engine.stopScreenCapture();
      }
      await engine.leaveChannel();
      await engine.stopPreview();
    }
  }

  // ---------------------------------------------------------------------------
  // Mute / deafen
  // ---------------------------------------------------------------------------

  Future<void> setMuted(bool muted) async {
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    await engine.muteLocalAudioStream(muted);
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
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    await engine.muteLocalAudioStream(deafen);
    await engine.muteAllRemoteAudioStreams(deafen);
    state = current.copyWith(deafen: deafen, muted: deafen);
  }

  // ---------------------------------------------------------------------------
  // Camera / screen share (mutually exclusive local video sources)
  // ---------------------------------------------------------------------------

  Future<void> openCamera() async {
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    if (current.shareScreen) await _stopShareScreenInternal(engine);
    await engine.enableLocalVideo(true);
    await engine.muteLocalVideoStream(false);
    await engine.startPreview();
    await engine.updateChannelMediaOptions(
      const ChannelMediaOptions(
        publishCameraTrack: true,
        publishScreenTrack: false,
      ),
    );
    state = (state ?? current).copyWith(video: true, shareScreen: false);
  }

  Future<void> closeCamera() async {
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    await engine.muteLocalVideoStream(true);
    await engine.updateChannelMediaOptions(
      const ChannelMediaOptions(publishCameraTrack: false),
    );
    await engine.stopPreview();
    state = current.copyWith(video: false);
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> startShareScreen() async {
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    if (current.video) await closeCamera();

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
        captureStarted = true;
        await engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishScreenCaptureVideo: true,
            publishCameraTrack: false,
          ),
        );
      }
      state = (state ?? current).copyWith(shareScreen: true, video: false);
    } catch (error, stackTrace) {
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
    final engine = _engine;
    final current = state;
    if (engine == null || current == null) return;
    await _stopShareScreenInternal(engine);
    state = current.copyWith(shareScreen: false);
  }

  Future<void> _stopShareScreenInternal(RtcEngine engine) async {
    await engine.stopScreenCapture();
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
    members.value = members.value.copyWith(pin: uid);
  }

  void unpin() {
    members.value = members.value.copyWith(pin: null);
  }
}
