import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/background/background_preferences.dart';
import '../../../l10n/generated/app_localizations.dart';

class BackgroundSettingsCard extends ConsumerStatefulWidget {
  const BackgroundSettingsCard({super.key});
  @override
  ConsumerState<BackgroundSettingsCard> createState() =>
      _BackgroundSettingsCardState();
}

class _BackgroundSettingsCardState extends ConsumerState<BackgroundSettingsCard>
    with WidgetsBindingObserver {
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isAndroidBackgroundSupported) {
      ref.read(backgroundPreferencesProvider.notifier).refresh();
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppL10n.of(context).backgroundActionFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool value) => _action(() async {
        final status = ref.read(backgroundPreferencesProvider).valueOrNull;
        if (value &&
            (status?.notifications != true ||
                status?.batterySetupComplete != true)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppL10n.of(context).backgroundSetupRequired)));
          return;
        }
        await ref
            .read(backgroundPreferencesProvider.notifier)
            .setEnabled(value);
      });

  @override
  Widget build(BuildContext context) {
    if (!isAndroidBackgroundSupported) return const SizedBox.shrink();
    final l = AppL10n.of(context);
    final state = ref.watch(backgroundPreferencesProvider);
    final status = state.valueOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        key: const Key('background-enabled'),
        title: Text(l.backgroundTitle),
        subtitle: Text(l.backgroundDescription),
        value: status?.enabled == true,
        onChanged: _busy || status == null ? null : _toggle,
      ),
      if (state.hasError) Text(l.backgroundActionFailed),
      if (state.isLoading) const LinearProgressIndicator(),
      if (status != null) ...[
        Text(status.enabled
            ? (status.running ? l.backgroundRunning : l.backgroundNotRunning)
            : l.backgroundDisabled),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(status.notifications
                ? Icons.check_circle_outline
                : Icons.notifications_outlined),
            title: Text(l.backgroundNotificationPermission),
            subtitle: Text(status.notifications
                ? l.backgroundGranted
                : l.backgroundSetupRequired),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy
                ? null
                : () => _action(() =>
                    backgroundChannel.invokeMethod('notificationSettings'))),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(status.batteryExempt
                ? Icons.check_circle_outline
                : Icons.battery_saver_outlined),
            title: Text(l.backgroundBattery),
            subtitle: Text(status.batteryExempt
                ? l.backgroundGranted
                : status.batterySettingsVisited
                    ? l.backgroundBatteryVisited
                    : l.backgroundBatteryDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy
                ? null
                : () => _action(() => ref
                    .read(backgroundPreferencesProvider.notifier)
                    .openBatterySettings())),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_suggest_outlined),
            title: Text(l.backgroundManufacturer),
            subtitle: Text(l.backgroundManufacturerDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy
                ? null
                : () => _action(
                    () => backgroundChannel.invokeMethod('appSettings'))),
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(l.backgroundLimitations)),
      ],
    ]);
  }
}
