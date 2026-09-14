import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/features/app_update/application/app_update_provider.dart';
import 'package:vocechat_client/features/app_update/data/android_update_api.dart';
import 'package:vocechat_client/features/app_update/domain/android_release.dart';

Map<String, dynamic> metadata({int code = 23}) => {
      'version': '0.3.23',
      'version_code': code,
      'timestamp': 1789056000000,
      'force_update': false,
      'update_url': 'https://update.voce.chat/downloads/app.apk',
    };

void main() {
  test('round trips optional announcement and accepts unknown fields', () {
    final json = {...metadata(), 'announcement': '更新公告\n修复问题'};
    final release = AndroidRelease.fromJson({
      ...json,
      'future_field': {'enabled': true},
    });
    expect(jsonDecode(jsonEncode(release.toJson())),
        {...json, 'last_force_version_code': 0});
    expect(AndroidRelease.fromJson(metadata()).announcement, isNull);
    expect(
        AndroidRelease.fromJson({...metadata(), 'announcement': null})
            .announcement,
        isNull);
  });

  test('historical forced build survives an optional release', () {
    final release = AndroidRelease.fromJson(
        {...metadata(code: 24), 'last_force_version_code': 23});
    expect(release.forceUpdate, isFalse);
    expect(release.isRequiredFor(22), isTrue);
    expect(release.isRequiredFor(23), isFalse);
    expect(release.isRequiredFor(24), isFalse);
    final legacy =
        AndroidRelease.fromJson({...metadata(), 'force_update': true});
    expect(legacy.isRequiredFor(22), isTrue);
  });

  test('selects localized announcements with legacy and missing-text fallback',
      () {
    final json = {
      ...metadata(),
      'announcement': {'zh': '中文公告', 'en': 'English notes'}
    };
    final release = AndroidRelease.fromJson(json);
    expect(release.announcementFor('zh'), '中文公告');
    expect(release.announcementFor('en'), 'English notes');
    expect(release.announcementFor('ja'), 'English notes');
    expect(release.toJson()['announcement'], json['announcement']);
    expect(
        AndroidRelease.fromJson({...metadata(), 'announcement': '旧公告'})
            .announcementFor('en'),
        '旧公告');
    expect(
        AndroidRelease.fromJson({
          ...metadata(),
          'announcement': {'zh': '', 'en': 'Fallback'}
        }).announcementFor('zh'),
        'Fallback');
    expect(
        AndroidRelease.fromJson({
          ...metadata(),
          'announcement': {'zh': '', 'en': ''}
        }).announcementFor('zh'),
        isNull);
  });

  test('compares numeric build codes and never downgrades, even if forced', () {
    final release = AndroidRelease.fromJson({
      ...metadata(),
      'version': '0.3.9',
      'force_update': true,
    });
    expect(release.isNewerThan(22), isTrue);
    expect(release.isNewerThan(23), isFalse);
    expect(release.isNewerThan(24), isFalse);
  });

  test('rejects missing/wrong required fields and unsafe URLs', () {
    for (final key in metadata().keys) {
      expect(() => AndroidRelease.fromJson({...metadata()}..remove(key)),
          throwsFormatException);
    }
    for (final changes in [
      {'version_code': '23'},
      {'version_code': 0},
      {'force_update': 'false'},
      {'timestamp': '1789056000000'},
      {'announcement': <String>[]},
      {
        'announcement': {'zh': 42}
      },
      {'last_force_version_code': '23'},
      {'last_force_version_code': -1},
      {'last_force_version_code': 24},
      {'update_url': 'javascript:alert(1)'},
      {'update_url': 'http://example.com/app.apk'},
      {'update_url': 'https://user:pass@example.com/app.apk'},
    ]) {
      expect(() => AndroidRelease.fromJson({...metadata(), ...changes}),
          throwsFormatException);
    }
  });

  test('uses the fixed public URL with no chat credentials or auth renewal',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dio = container.read(dioClientProvider).dio;
    final adapter = _Adapter();
    dio.httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final api = AndroidUpdateApi(dio);
    expect((await api.check()).versionCode, 23);
    final request = adapter.requests.single;
    expect(request.uri.toString(), AndroidUpdateApi.endpoint);
    expect(request.headers['X-API-Key'], isNull);
    expect(request.headers['Referer'], 'https://update.voce.chat/');
    expect(request.followRedirects, isFalse);
    expect(request.extra[kSkipRefreshOn401], isTrue);

    adapter.status = 401;
    await expectLater(api.check(), throwsA(isA<DioException>()));
    expect(adapter.requests.length, 2);
    adapter.status = 200;
    adapter.body = 'not a JSON object';
    await expectLater(api.check(), throwsA(isA<FormatException>()));
  });

  test('checks only once in a process and ignores newly published metadata',
      () async {
    final api = _FakeApi();
    final container = ProviderContainer(overrides: [
      androidUpdateSupportedProvider.overrideWithValue(true),
      installedAndroidVersionCodeProvider.overrideWith((ref) async => 22),
      androidUpdateApiProvider.overrideWithValue(api),
    ]);
    addTearDown(container.dispose);
    expect(
        (await container.read(startupAndroidUpdateProvider.future))
            ?.versionCode,
        23);
    api.code = 24;
    expect(
        (await container.read(startupAndroidUpdateProvider.future))
            ?.versionCode,
        23);
    expect(api.checks, 1);
  });

  test('other platforms never read package metadata or access update API',
      () async {
    final container = ProviderContainer(overrides: [
      androidUpdateSupportedProvider.overrideWithValue(false),
      installedAndroidVersionCodeProvider
          .overrideWith((ref) => throw StateError('must not read')),
      androidUpdateApiProvider
          .overrideWith((ref) => throw StateError('must not read')),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(startupAndroidUpdateProvider.future), isNull);
  });

  test('current/newer installations are not prompted even for forced releases',
      () async {
    for (final installed in [23, 24]) {
      final container = ProviderContainer(overrides: [
        androidUpdateSupportedProvider.overrideWithValue(true),
        installedAndroidVersionCodeProvider
            .overrideWith((ref) async => installed),
        androidUpdateApiProvider.overrideWithValue(_FakeApi()),
      ]);
      expect(await container.read(startupAndroidUpdateProvider.future), isNull);
      container.dispose();
    }
  });
}

class _FakeApi extends AndroidUpdateApi {
  _FakeApi() : super(Dio());
  int checks = 0;
  int code = 23;

  @override
  Future<AndroidRelease> check() async {
    checks++;
    return AndroidRelease.fromJson(
        {...metadata(code: code), 'force_update': true});
  }
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  Object body = metadata();

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}
