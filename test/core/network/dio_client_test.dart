import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/core/storage/account_store.dart';

class _Accounts extends AccountStore {
  @override
  Future<AccountState> build() async => const AccountState();
}

class _ResponseAdapter implements HttpClientAdapter {
  _ResponseAdapter(this.data);
  final Object data;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(jsonEncode(data), 400, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  @override
  void close({bool force = false}) {}
}

void main() {
  final clientProvider = Provider(
      (ref) => VoceDioClient(baseUrl: 'https://example.test', ref: ref).dio);

  for (final data in [
    {
      'error': {'message': 'nested'},
      'code': 42
    },
    {'msg': [], 'message': 'Readable error', 'code': []},
    {'error': true},
  ]) {
    test('malformed error JSON completes the request: $data', () async {
      final container = ProviderContainer(overrides: [
        accountStoreProvider.overrideWith(_Accounts.new),
      ]);
      addTearDown(container.dispose);
      await container.read(accountStoreProvider.future);
      final dio = container.read(clientProvider)
        ..httpClientAdapter = _ResponseAdapter(data);
      addTearDown(dio.close);
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
            dio.post('/error').timeout(const Duration(seconds: 1)),
            throwsA(isA<DioException>()
                .having((e) => e.response?.statusCode, 'status', 400)
                .having((e) => e.error, 'mapped error', isA<ApiException>())));
      }
    });
  }

  test(
      'a request with a disposed provider rejects rather than remaining pending',
      () async {
    final container = ProviderContainer(overrides: [
      accountStoreProvider.overrideWith(_Accounts.new),
    ]);
    await container.read(accountStoreProvider.future);
    final dio = container.read(clientProvider)
      ..httpClientAdapter = _ResponseAdapter({});
    addTearDown(dio.close);
    container.dispose();
    await expectLater(dio.get('/late').timeout(const Duration(seconds: 1)),
        throwsA(isA<DioException>()));
  });
}
