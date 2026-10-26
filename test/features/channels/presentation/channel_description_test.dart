import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/storage/server_store.dart';
import 'package:vocechat_client/features/auth/application/auth_controller.dart';
import 'package:vocechat_client/features/auth/domain/auth_models.dart';
import 'package:vocechat_client/features/channels/data/group_api.dart';
import 'package:vocechat_client/features/channels/presentation/channel_settings_screen.dart';
import 'package:vocechat_client/features/contacts/application/user_directory_provider.dart';
import 'package:vocechat_client/l10n/generated/app_localizations.dart';

const _description = 'First paragraph of the group introduction.\n\n'
    'Another paragraph that must survive renaming the group.';

class _Auth extends AuthController {
  @override
  Future<AuthState> build() async =>
      const AuthState.authenticated(user: VoceUser(uid: 7, name: 'Owner'));
}

class _Servers extends ServerStore {
  @override
  Future<ServerState> build() async => const ServerState();
}

class _Users extends UserDirectory {
  @override
  Future<Map<int, UserSummary>> build() async => const {};
}

class _Groups extends GroupDirectory {
  @override
  Future<Map<int, GroupSummary>> build() async => const {
        42: GroupSummary(
            gid: 42, name: 'Community', owner: 7, description: _description),
      };
  @override
  Future<void> refresh() async {}
}

class _Api extends GroupApi {
  _Api() : super(Dio());
  String? savedName;
  String? savedDescription;
  @override
  Future<void> updateChannel(int gid,
      {String? name, String? description, int? autoDeleteAfter}) async {
    savedName = name;
    savedDescription = description;
  }
}

void main() {
  testWidgets('renaming a group preserves its loaded full introduction',
      (tester) async {
    final api = _Api();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        serverStoreProvider.overrideWith(_Servers.new),
        userDirectoryProvider.overrideWith(_Users.new),
        groupDirectoryProvider.overrideWith(_Groups.new),
        groupApiProvider.overrideWith((ref) => api),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: const ChannelSettingsScreen(gid: 42),
      ),
    ));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    final description = tester.widget<TextField>(fields.at(1));
    expect(description.controller!.text, _description);
    expect(description.maxLines, isNull);
    await tester.enterText(fields.first, 'Renamed community');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(api.savedName, 'Renamed community');
    expect(api.savedDescription, _description);
    expect(tester.takeException(), isNull);
  });
}
