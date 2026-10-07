import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/features/messages/domain/message_models.dart';
import 'package:vocechat_client/features/voice/application/voice_controller.dart';
import 'package:vocechat_client/features/voice/domain/voice_models.dart';
import 'package:vocechat_client/features/voice/presentation/voice_operations_bar.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

const _videoCall = VoicingInfo(
  context: MessageTarget.user(uid: 42),
  connectionState: VoiceConnectionState.connected,
  video: true,
);

const _cameraDevices = VoiceCameraDevices(
  devices: [
    VoiceCameraDevice(id: 'integrated-camera', name: 'Integrated webcam'),
    VoiceCameraDevice(id: 'usb-camera-42', name: 'External USB camera'),
  ],
  selectedDeviceId: 'integrated-camera',
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('${platform.name} switches the active camera', (tester) async {
      final controller = _CameraController();
      await _pumpBar(tester, controller, platform: platform);

      expect(find.byTooltip('Switch camera'), findsOneWidget);
      expect(find.byIcon(Icons.flip_camera_ios), findsOneWidget);
      expect(find.byTooltip('Select camera'), findsNothing);

      await tester.tap(_cameraChangeButton());
      await tester.pumpAndSettle();

      expect(controller.switchCalls, 1);
      expect(controller.getDevicesCalls, 0);
      expect(controller.selectedDeviceIds, isEmpty);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
    testWidgets('${platform.name} lists and selects cameras by device id',
        (tester) async {
      final controller = _CameraController();
      await _pumpBar(tester, controller, platform: platform);

      expect(find.byTooltip('Select camera'), findsOneWidget);
      await tester.tap(_cameraChangeButton());
      await tester.pumpAndSettle();

      expect(controller.getDevicesCalls, 1);
      expect(find.text('Select camera'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(_deviceTile('Integrated webcam'), findsOneWidget);
      expect(_deviceTile('External USB camera'), findsOneWidget);
      expect(
        find.descendant(
          of: _deviceTile('Integrated webcam'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _deviceTile('External USB camera'),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );

      await tester.tap(_deviceTile('External USB camera'));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNothing);
      expect(controller.selectedDeviceIds, ['usb-camera-42']);
      expect(controller.switchCalls, 0);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('mobile camera switching has a Chinese tooltip', (tester) async {
    final controller = _CameraController();
    await _pumpBar(
      tester,
      controller,
      platform: TargetPlatform.iOS,
      locale: const Locale('zh'),
    );

    expect(find.byTooltip('切换摄像头'), findsOneWidget);
    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();

    expect(controller.switchCalls, 1);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('desktop camera selection has a Chinese tooltip and title',
      (tester) async {
    final controller = _CameraController();
    await _pumpBar(
      tester,
      controller,
      platform: TargetPlatform.windows,
      locale: const Locale('zh'),
    );

    expect(find.byTooltip('选择摄像头'), findsOneWidget);
    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();

    expect(find.text('选择摄像头'), findsOneWidget);
    expect(_deviceTile('External USB camera'), findsOneWidget);
    await tester.tap(_deviceTile('External USB camera'));
    await tester.pumpAndSettle();

    expect(controller.selectedDeviceIds, ['usb-camera-42']);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final sharing in [false, true]) {
      testWidgets(
          '${platform.name} hides camera switching when ${sharing ? 'sharing the screen' : 'the camera is off'}',
          (tester) async {
        final controller = _CameraController(
          initialInfo: _videoCall.copyWith(
            video: sharing,
            shareScreen: sharing,
          ),
        );
        await _pumpBar(tester, controller, platform: platform);

        expect(find.byIcon(Icons.flip_camera_ios), findsNothing);
        expect(find.byTooltip('Switch camera'), findsNothing);
        expect(find.byTooltip('Select camera'), findsNothing);
        expect(controller.switchCalls, 0);
        expect(controller.getDevicesCalls, 0);
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant({platform}));
    }
  }

  testWidgets('Linux does not expose unsupported camera controls',
      (tester) async {
    final controller = _CameraController();
    await _pumpBar(tester, controller, platform: TargetPlatform.linux);

    expect(find.byIcon(Icons.flip_camera_ios), findsNothing);
    expect(find.byTooltip('Turn off camera'), findsNothing);
    expect(find.byTooltip('Select camera'), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));

  testWidgets('an empty camera list shows a message without opening a picker',
      (tester) async {
    final controller = _CameraController()
      ..cameraDevices = const VoiceCameraDevices(devices: []);
    await _pumpBar(tester, controller, platform: TargetPlatform.windows);

    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();

    expect(controller.getDevicesCalls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('No cameras available'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
    expect(controller.selectedDeviceIds, isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('camera switch failures show the error and allow another attempt',
      (tester) async {
    final error = StateError('Camera switch failed');
    final controller = _CameraController()..switchError = error;
    await _pumpBar(tester, controller, platform: TargetPlatform.android);

    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();

    _expectCameraError(tester, error);
    expect(_button(tester, _cameraChangeButton()).onPressed, isNotNull);
    controller.switchError = null;
    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();

    expect(controller.switchCalls, 2);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('camera enumeration failures show the underlying error',
      (tester) async {
    final error = StateError('Camera discovery failed');
    final controller = _CameraController()..getDevicesError = error;
    await _pumpBar(tester, controller, platform: TargetPlatform.windows);

    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();

    _expectCameraError(tester, error);
    expect(find.byType(ListTile), findsNothing);
    expect(_button(tester, _cameraChangeButton()).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('camera selection failures close the picker and show the error',
      (tester) async {
    final error = StateError('Selected camera is unavailable');
    final controller = _CameraController()..selectError = error;
    await _pumpBar(tester, controller, platform: TargetPlatform.macOS);

    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();
    await tester.tap(_deviceTile('External USB camera'));
    await tester.pumpAndSettle();

    expect(controller.selectedDeviceIds, ['usb-camera-42']);
    expect(find.byType(ListTile), findsNothing);
    _expectCameraError(tester, error);
    expect(_button(tester, _cameraChangeButton()).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('dismissing the camera picker preserves the current device',
      (tester) async {
    final controller = _CameraController();
    await _pumpBar(tester, controller, platform: TargetPlatform.windows);

    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(controller.selectedDeviceIds, isEmpty);
    expect(_button(tester, _cameraChangeButton()).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('choosing the current camera does not change the device',
      (tester) async {
    final controller = _CameraController();
    await _pumpBar(tester, controller, platform: TargetPlatform.macOS);

    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();
    await tester.tap(_deviceTile('Integrated webcam'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(controller.selectedDeviceIds, isEmpty);
    expect(_button(tester, _cameraChangeButton()).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  for (final language in ['en', 'zh']) {
    testWidgets('$language gives unnamed cameras a readable fallback',
        (tester) async {
      final controller = _CameraController()
        ..cameraDevices = const VoiceCameraDevices(
          devices: [
            VoiceCameraDevice(id: 'unnamed-camera', name: ''),
            VoiceCameraDevice(id: 'usb-camera-42', name: 'External USB camera'),
          ],
          selectedDeviceId: 'usb-camera-42',
        );
      await _pumpBar(
        tester,
        controller,
        platform: TargetPlatform.windows,
        locale: Locale(language),
      );

      await tester.tap(_cameraChangeButton());
      await tester.pumpAndSettle();
      final label = language == 'en' ? 'Camera 1' : '摄像头 1';
      expect(_deviceTile(label), findsOneWidget);
      await tester.tap(_deviceTile(label));
      await tester.pumpAndSettle();

      expect(controller.selectedDeviceIds, ['unnamed-camera']);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.windows}));
  }

  testWidgets('ending a call during camera discovery does not open a picker',
      (tester) async {
    final gate = Completer<void>();
    final controller = _CameraController()..getDevicesWait = gate;
    await _pumpBar(tester, controller, platform: TargetPlatform.windows);

    await tester.tap(_cameraChangeButton());
    await tester.pump();
    expect(controller.getDevicesCalls, 1);
    controller.endCall();
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(controller.selectedDeviceIds, isEmpty);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  testWidgets('a camera picker from an ended call cannot apply its selection',
      (tester) async {
    final controller = _CameraController();
    await _pumpBar(tester, controller, platform: TargetPlatform.macOS);

    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();
    expect(_deviceTile('External USB camera'), findsOneWidget);
    controller.endCall();
    await tester.pump();
    await tester.tap(_deviceTile('External USB camera'));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(controller.selectedDeviceIds, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.macOS}));

  testWidgets('camera switching is disabled until the operation completes',
      (tester) async {
    final gate = Completer<void>();
    final controller = _CameraController()..switchWait = gate;
    await _pumpBar(tester, controller, platform: TargetPlatform.android);

    await tester.tap(_cameraChangeButton());
    await tester.pump();

    expect(controller.switchCalls, 1);
    expect(_button(tester, _cameraChangeButton()).onPressed, isNull);
    await tester.tap(_cameraChangeButton());
    await tester.pump();
    expect(controller.switchCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(_button(tester, _cameraChangeButton()).onPressed, isNotNull);
    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();
    expect(controller.switchCalls, 2);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('camera discovery cannot open duplicate pickers while pending',
      (tester) async {
    final gate = Completer<void>();
    final controller = _CameraController()..getDevicesWait = gate;
    await _pumpBar(tester, controller, platform: TargetPlatform.windows);

    await tester.tap(_cameraChangeButton());
    await tester.pump();

    expect(_button(tester, _cameraChangeButton()).onPressed, isNull);
    await tester.tap(_cameraChangeButton());
    await tester.pump();
    expect(controller.getDevicesCalls, 1);
    expect(find.byType(ListTile), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNWidgets(2));
    await tester.tap(_deviceTile('External USB camera'));
    await tester.pumpAndSettle();
    expect(controller.selectedDeviceIds, ['usb-camera-42']);
    expect(_button(tester, _cameraChangeButton()).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.windows}));

  for (final initiallyOpen in [false, true]) {
    testWidgets(
        '${initiallyOpen ? 'closing' : 'opening'} the camera disables repeated taps',
        (tester) async {
      final gate = Completer<void>();
      final controller = _CameraController(
        initialInfo: _videoCall.copyWith(video: initiallyOpen),
      )..cameraWait = gate;
      await _pumpBar(tester, controller, platform: TargetPlatform.android);
      final cameraButton = _iconButton(
        initiallyOpen ? Icons.videocam : Icons.videocam_off,
      );

      await tester.tap(cameraButton);
      await tester.pump();
      expect(_button(tester, cameraButton).onPressed, isNull);
      await tester.tap(cameraButton);
      await tester.pump();
      expect(controller.openCalls, initiallyOpen ? 0 : 1);
      expect(controller.closeCalls, initiallyOpen ? 1 : 0);

      gate.complete();
      await tester.pumpAndSettle();
      expect(
        _button(
          tester,
          _iconButton(initiallyOpen ? Icons.videocam_off : Icons.videocam),
        ).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({TargetPlatform.android}));
  }

  testWidgets('starting screen sharing disables repeated taps', (tester) async {
    final gate = Completer<void>();
    final controller = _CameraController()..shareWait = gate;
    await _pumpBar(tester, controller, platform: TargetPlatform.android);
    final screenShareButton = _iconButton(Icons.screen_share);

    await tester.tap(screenShareButton);
    await tester.pump();
    expect(_button(tester, screenShareButton).onPressed, isNull);
    await tester.tap(screenShareButton);
    await tester.pump();
    expect(controller.startShareCalls, 1);

    gate.complete();
    await tester.pumpAndSettle();
    expect(_button(tester, screenShareButton).onPressed, isNotNull);
    expect(find.byIcon(Icons.flip_camera_ios), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));

  testWidgets('fullscreen controls also switch the camera', (tester) async {
    final controller = _CameraController();
    await _pumpBar(
      tester,
      controller,
      platform: TargetPlatform.iOS,
      fullscreen: true,
    );

    expect(find.byTooltip('Switch camera'), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();

    expect(controller.switchCalls, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets('camera controls wrap on a narrow screen without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(240, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = _CameraController();
    await _pumpBar(tester, controller, platform: TargetPlatform.android);

    expect(find.byIcon(Icons.flip_camera_ios), findsOneWidget);
    expect(find.byIcon(Icons.call_end), findsOneWidget);
    expect(tester.takeException(), isNull);
    final controlArea = tester.getRect(find.byType(VoiceOperationsBar));
    for (final icon in [Icons.flip_camera_ios, Icons.call_end]) {
      final button = tester.getRect(_iconButton(icon));
      expect(controlArea.contains(button.topLeft), isTrue);
      expect(controlArea.contains(button.bottomRight), isTrue);
    }

    await tester.tap(_cameraChangeButton());
    await tester.pumpAndSettle();
    expect(controller.switchCalls, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
}

Future<void> _pumpBar(
  WidgetTester tester,
  _CameraController controller, {
  required TargetPlatform platform,
  Locale locale = const Locale('en'),
  bool fullscreen = false,
}) async {
  expect(
    defaultTargetPlatform,
    platform,
    reason: 'The test must configure its platform with TargetPlatformVariant',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [voiceControllerProvider.overrideWith(() => controller)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: VoiceOperationsBar(fullscreen: fullscreen),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _cameraChangeButton() => _iconButton(Icons.flip_camera_ios);

Finder _iconButton(IconData icon) => find.ancestor(
      of: find.byIcon(icon),
      matching: find.byType(IconButton),
    );

Finder _deviceTile(String name) => find.widgetWithText(ListTile, name);

IconButton _button(WidgetTester tester, Finder finder) =>
    tester.widget<IconButton>(finder);

void _expectCameraError(WidgetTester tester, Object error) {
  final localizations =
      AppL10n.of(tester.element(find.byType(VoiceOperationsBar)));
  expect(find.byType(SnackBar), findsOneWidget);
  expect(find.text(localizations.errorPrefix('$error')), findsOneWidget);
}

class _CameraController extends VoiceController {
  _CameraController({this.initialInfo = _videoCall});

  final VoicingInfo initialInfo;
  VoiceCameraDevices? cameraDevices = _cameraDevices;
  int switchCalls = 0;
  int getDevicesCalls = 0;
  int openCalls = 0;
  int closeCalls = 0;
  int startShareCalls = 0;
  final selectedDeviceIds = <String>[];
  Object? switchError;
  Object? getDevicesError;
  Object? selectError;
  Completer<void>? switchWait;
  Completer<void>? getDevicesWait;
  Completer<void>? cameraWait;
  Completer<void>? shareWait;

  void endCall() => state = null;

  @override
  VoicingInfo? build() {
    ref.onDispose(members.dispose);
    ref.onDispose(pictureInPictureRemoteUid.dispose);
    return initialInfo;
  }

  @override
  Future<void> switchCamera() async {
    switchCalls++;
    await switchWait?.future;
    if (switchError case final error?) throw error;
  }

  @override
  Future<VoiceCameraDevices?> getCameraDevices() async {
    getDevicesCalls++;
    await getDevicesWait?.future;
    if (getDevicesError case final error?) throw error;
    return cameraDevices;
  }

  @override
  Future<void> selectCamera(String deviceId) async {
    selectedDeviceIds.add(deviceId);
    if (selectError case final error?) throw error;
  }

  @override
  Future<void> openCamera() async {
    openCalls++;
    await cameraWait?.future;
    state = state?.copyWith(video: true);
  }

  @override
  Future<void> closeCamera() async {
    closeCalls++;
    await cameraWait?.future;
    state = state?.copyWith(video: false);
  }

  @override
  Future<void> startShareScreen() async {
    startShareCalls++;
    await shareWait?.future;
    state = state?.copyWith(shareScreen: true);
  }
}
