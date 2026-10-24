import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vocechat_client/core/theme/app_text_scale.dart';
import 'package:vocechat_client/core/theme/app_theme.dart';
import 'package:vocechat_client/core/theme/font_size_provider.dart';
import 'package:vocechat_client/features/settings/presentation/font_size_settings_card.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> mount(
    WidgetTester tester, {
    double width = 390,
    Locale locale = const Locale('en'),
    TextScaler systemScaler = TextScaler.noScaling,
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: systemScaler),
          child: AppTextScale(child: child!),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('Message outside settings',
                  key: Key('outside-text'), style: TextStyle(fontSize: 16)),
              const FontSizeSettingsCard(),
              const TextField(),
              Builder(
                  builder: (context) => TextButton(
                        key: const Key('open-dialog'),
                        onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => const AlertDialog(
                                content: Text('Dialog text'))),
                        child: const Text('Open dialog'),
                      )),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  double renderedSize(WidgetTester tester, Finder finder) {
    final paragraph = tester.renderObject<RenderParagraph>(finder);
    return paragraph.textScaler.scale(16);
  }

  testWidgets(
      'drag previews globally and saves only when released; reset persists',
      (tester) async {
    final container = await mount(tester);
    final prefs = await SharedPreferences.getInstance();
    final slider = find.byKey(const Key('font-size-slider'));
    final preview = find.byKey(const Key('font-size-preview'));
    final outside = find.byKey(const Key('outside-text'));
    expect(find.text('100% (Default)'), findsOneWidget);
    expect(renderedSize(tester, preview), 16);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveTo(tester.getTopRight(slider) + const Offset(-24, 24));
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(fontSizeProvider), 6);
    expect(renderedSize(tester, preview), closeTo(20.8, 0.001));
    expect(renderedSize(tester, outside), closeTo(20.8, 0.001));
    expect(prefs.containsKey('app.fontSize.step'), isFalse);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(prefs.getInt('app.fontSize.step'), 6);
    expect(find.text('130%'), findsOneWidget);

    await tester.tap(find.byKey(const Key('font-size-reset')));
    await tester.pumpAndSettle();
    expect(renderedSize(tester, preview), 16);
    expect(renderedSize(tester, outside), 16);
    expect(prefs.containsKey('app.fontSize.step'), isFalse);
    expect(find.text('100% (Default)'), findsOneWidget);
  });

  testWidgets('drag left reduces text size to the minimum', (tester) async {
    await mount(tester);
    final slider = find.byKey(const Key('font-size-slider'));
    await tester.drag(slider, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('85%'), findsOneWidget);
    expect(renderedSize(tester, find.byKey(const Key('font-size-preview'))),
        closeTo(13.6, 0.001));
    expect(
        (await SharedPreferences.getInstance()).getInt('app.fontSize.step'), 0);
  });

  testWidgets(
      'system nonlinear scaling is preserved for text fields and dialogs',
      (tester) async {
    SharedPreferences.setMockInitialValues({'app.fontSize.step': 6});
    await mount(tester, systemScaler: const _NonlinearTextScaler());
    final previewContext =
        tester.element(find.byKey(const Key('font-size-preview')));
    final scaler = MediaQuery.textScalerOf(previewContext);
    expect(scaler.scale(16), closeTo(31.2, 0.001));
    expect(scaler.scale(32), closeTo(52, 0.001));
    final input = tester.element(find.byType(EditableText));
    expect(MediaQuery.textScalerOf(input).scale(16), closeTo(31.2, 0.001));
    await tester.ensureVisible(find.byKey(const Key('open-dialog')));
    await tester.tap(find.byKey(const Key('open-dialog')));
    await tester.pumpAndSettle();
    expect(
        MediaQuery.textScalerOf(tester.element(find.text('Dialog text')))
            .scale(16),
        closeTo(31.2, 0.001));
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 1000.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('Chinese largest size fits at width $width in $brightness',
          (tester) async {
        SharedPreferences.setMockInitialValues({'app.fontSize.step': 6});
        await mount(tester,
            width: width, locale: const Locale('zh'), brightness: brightness);
        expect(find.text('字体大小'), findsOneWidget);
        expect(find.text('130%'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final slider = find.byKey(const Key('font-size-slider'));
        await tester.ensureVisible(slider);
        await tester.drag(slider, const Offset(-800, 0));
        await tester.pumpAndSettle();
        expect(find.text('85%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();
  @override
  double scale(double fontSize) => fontSize + 8;
  @override
  double get textScaleFactor => 1.5;
}
