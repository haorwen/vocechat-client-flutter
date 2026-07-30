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
    return parseInviteLink(Uri.decodeFull(envelope));
  }
  return parseInviteLink(uri.toString());
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

  @override
  void build() {
    final appLinks = AppLinks();
    _sub = appLinks.uriLinkStream.listen(_handleUri, onError: (e) {
      AppLog.w(LogTag.general, () => '🔗 deep link stream error: $e');
    });
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });
    ref.onDispose(() => _sub?.cancel());
  }

  Future<void> _handleUri(Uri uri) async {
    AppLog.d(LogTag.general, () => '🔗 received deep link: $uri');
    final parsed = _resolveDeepLink(uri);
    if (parsed is! InviteLinkParseValid) {
      AppLog.w(LogTag.general, () => '🔗 deep link is not a valid invite: $uri');
      return;
    }

    final name = Uri.tryParse(parsed.serverBaseUrl)?.host ?? parsed.serverBaseUrl;
    final config = ServerConfig(
      id: '${Uri.parse(parsed.serverBaseUrl).host.replaceAll('.', '_')}_${DateTime.now().millisecondsSinceEpoch}',
      baseUrl: parsed.serverBaseUrl,
      name: name,
    );

    final serverNotifier = ref.read(serverStoreProvider.notifier);
    await serverNotifier.addServer(config);
    await serverNotifier.selectServer(config.id);
    await ref.read(accountStoreProvider.notifier).clearCurrentAccount();
    // Wait for auth controller to re-bootstrap with the new server.
    await ref.read(authControllerProvider.future);

    ref.read(goRouterProvider).go('/register', extra: parsed.magicToken);
  }
}
