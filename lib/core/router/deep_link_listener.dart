import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/server/domain/invite_link.dart';
import '../storage/account_store.dart';
import '../storage/server_store.dart';
import '../utils/app_log.dart';
import 'app_router.dart';

part 'deep_link_listener.g.dart';

/// Extracts an invitation link's target server + magic token from an
/// incoming `vocechat://` deep link.
///
/// A custom scheme has no server address of its own (unlike an
/// `https://<server-host>/...` link), so it can't be fed to
/// [parseInviteLink] directly. Two shapes are supported:
///
///  - `vocechat://open?link=<url-encoded https://host/...>` (or `?i=...`) —
///    an envelope carrying the real invite link, matching the old reference
///    client's `magic_link=`/`i=` wrapper params.
///  - `vocechat://<host>/?magic_token=...` — a scheme swap of the same
///    shape a server-generated https link uses, in case some future
///    integration emits `vocechat://` links directly instead of https ones.
InviteLinkParseResult _resolveDeepLink(Uri uri) {
  final envelope = uri.queryParameters['link'] ?? uri.queryParameters['i'];
  if (envelope != null && envelope.isNotEmpty) {
    // queryParameters has already decoded the envelope once.
    return parseInviteLink(envelope);
  }
  return parseInviteLink(
      (uri.scheme == 'vocechat' ? uri.replace(scheme: 'https') : uri)
          .toString());
}

/// Subscribes to incoming `vocechat://` deep links (Android/iOS custom URL
/// scheme — see AndroidManifest.xml / Info.plist) for the lifetime of the
/// app, and lands any valid invitation link the same way the server-picker's
/// "use invitation link" sheet does: create+select a [ServerConfig] for the
/// link's target server, clear the current account pointer, then navigate
/// to `/register` with the magic token.
///
/// Kept alive so it isn't torn down when nothing is `ref.watch`ing it —
/// mount it once via `ref.watch(deepLinkListenerProvider)` in `main.dart`.
@Riverpod(keepAlive: true)
class DeepLinkListener extends _$DeepLinkListener {
  StreamSubscription<Uri>? _sub;
  Future<void> _queue = Future.value();
  final _queued = <Uri>{};
  bool _disposed = false;

  @override
  void build() {
    final appLinks = AppLinks();
    _disposed = false;
    // app_links emits the initial link on this stream too. Reading it again
    // via getInitialLink used to select/create the same server concurrently.
    _sub = appLinks.uriLinkStream.listen(_enqueueUri, onError: (Object error) {
      AppLog.w(LogTag.general, () => 'Deep link stream unavailable: $error');
    });
    ref.onDispose(() {
      _disposed = true;
      _sub?.cancel();
    });
  }

  void _enqueueUri(Uri uri) {
    if (_disposed ||
        !const {'vocechat', 'https', 'http'}.contains(uri.scheme) ||
        !_queued.add(uri)) {
      return;
    }
    _queue = _queue.then((_) async {
      try {
        if (!_disposed) await _handleUri(uri);
      } catch (error, stackTrace) {
        AppLog.e(LogTag.general, () => 'Could not open invitation link',
            error: error, stackTrace: stackTrace);
      } finally {
        _queued.remove(uri);
      }
    });
  }

  Future<void> _handleUri(Uri uri) async {
    final parsed = _resolveDeepLink(uri);
    if (parsed is! InviteLinkParseValid) return;

    final servers = await ref.read(serverStoreProvider.future);
    if (_disposed) return;
    await ref.read(accountStoreProvider.future);
    if (_disposed) return;

    final name =
        Uri.tryParse(parsed.serverBaseUrl)?.host ?? parsed.serverBaseUrl;
    final existing = servers.servers
        .where((server) =>
            server.baseUrl.replaceAll(RegExp(r'/+$'), '') ==
            parsed.serverBaseUrl)
        .firstOrNull;
    final config = existing ??
        ServerConfig(
          id: '${Uri.parse(parsed.serverBaseUrl).host.replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}',
          baseUrl: parsed.serverBaseUrl,
          name: name,
        );

    final serverNotifier = ref.read(serverStoreProvider.notifier);
    if (existing == null) await serverNotifier.addServer(config);
    if (_disposed) return;
    await serverNotifier.selectServer(config.id);
    if (_disposed) return;
    await ref.read(accountStoreProvider.notifier).clearCurrentAccount();
    if (_disposed) return;
    // Wait for auth controller to re-bootstrap with the new server.
    await ref.read(authControllerProvider.future);
    if (_disposed) return;

    ref.read(goRouterProvider).go('/register', extra: parsed.magicToken);
  }
}
