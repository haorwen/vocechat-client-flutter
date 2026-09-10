import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/network/dio_client.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/settings/application/server_version_provider.dart';

void main() {
  test('fetches plain-text version again when the active server changes',
      () async {
    final requests = <RequestOptions>[];
    final container = ProviderContainer(overrides: [
      serverStoreProvider.overrideWith(_TestServerStore.new),
      dioProvider.overrideWith((ref) {
        final dio = ref.watch(dioClientProvider).dio;
        dio.interceptors.insert(
          0,
          InterceptorsWrapper(onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(Response<String>(
              requestOptions: options,
              statusCode: 200,
              data: options.baseUrl == 'https://first.example.com'
                  ? '0.5.22\n'
                  : '0.6.0',
            ));
          }),
        );
        return dio;
      }),
    ]);
    addTearDown(container.dispose);
    await container.read(serverStoreProvider.future);
    final subscription = container.listen(serverVersionProvider, (_, __) {});
    addTearDown(subscription.close);

    expect(await container.read(serverVersionProvider.future), '0.5.22');
    (container.read(serverStoreProvider.notifier) as _TestServerStore)
        .switchServer();
    expect(await container.read(serverVersionProvider.future), '0.6.0');
    expect(requests.map((r) => r.baseUrl), [
      'https://first.example.com',
      'https://second.example.com',
    ]);
    for (final request in requests) {
      expect(request.path, '/api/admin/system/version');
      expect(request.responseType, ResponseType.plain);
    }
  });
}

class _TestServerStore extends ServerStore {
  @override
  Future<ServerState> build() async => const ServerState(
        servers: [
          ServerConfig(
            id: 'first',
            baseUrl: 'https://first.example.com',
            name: 'First server',
          ),
          ServerConfig(
            id: 'second',
            baseUrl: 'https://second.example.com',
            name: 'Second server',
          ),
        ],
        currentServerId: 'first',
      );

  void switchServer() {
    state = AsyncData(state.requireValue.copyWith(currentServerId: 'second'));
  }
}
