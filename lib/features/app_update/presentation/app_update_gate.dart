import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/app_update_controller.dart';
import 'apk_download_panel.dart';

/// Mounted above the router, so navigation cannot dismiss a mandatory update.
/// Network/metadata failures leave the app usable; the next process start retries.
class AppUpdateGate extends ConsumerStatefulWidget {
  const AppUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends ConsumerState<AppUpdateGate> {
  bool _savingSkip = false;
  bool _skipFailed = false;

  Future<void> _skip({required bool emergency}) async {
    if (_savingSkip) return;
    setState(() {
      _savingSkip = true;
      _skipFailed = false;
    });
    try {
      final controller = ref.read(appUpdateControllerProvider.notifier);
      if (emergency) {
        await controller.emergencySkip();
      } else {
        await controller.skipVersion();
      }
    } catch (_) {
      if (mounted) setState(() => _skipFailed = true);
    } finally {
      if (mounted) setState(() => _savingSkip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prompt = ref.watch(appUpdateControllerProvider).valueOrNull;
    final release = prompt?.release;
    final showing = prompt != null;
    final l = AppL10n.of(context);
    final announcement =
        release?.announcementFor(Localizations.localeOf(context).languageCode);
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: showing,
          child: ExcludeFocus(
            excluding: showing,
            child: AbsorbPointer(absorbing: showing, child: widget.child),
          ),
        ),
        if (release != null && prompt != null) ...[
          const ModalBarrier(dismissible: false, color: Colors.black54),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 440,
                  child: Material(
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.appUpdateTitle(release.version),
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          Text(prompt.isRequired
                              ? l.appUpdateRequired
                              : l.appUpdateAvailable),
                          if (prompt.isRequired &&
                              prompt.emergencySkipsRemaining > 0) ...[
                            const SizedBox(height: 12),
                            Text(l.appUpdateEmergencyHint),
                          ],
                          if (announcement != null &&
                              announcement.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(announcement),
                          ],
                          if (_skipFailed || !prompt.preferencesAvailable) ...[
                            const SizedBox(height: 16),
                            Text(l.appUpdateSkipFailed,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                          ],
                          const SizedBox(height: 24),
                          ApkDownloadPanel(
                              key: ValueKey(release.versionCode),
                              release: release),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              if (!prompt.isRequired) ...[
                                TextButton(
                                  onPressed: _savingSkip
                                      ? null
                                      : () => ref
                                          .read(appUpdateControllerProvider
                                              .notifier)
                                          .postpone(),
                                  child: Text(l.appUpdateLater),
                                ),
                                TextButton(
                                  onPressed: _savingSkip ||
                                          !prompt.preferencesAvailable
                                      ? null
                                      : () => _skip(emergency: false),
                                  child: Text(l.appUpdateSkipVersion),
                                ),
                              ],
                              if (prompt.isRequired &&
                                  prompt.emergencySkipsRemaining > 0)
                                TextButton(
                                  onPressed: _savingSkip
                                      ? null
                                      : () => _skip(emergency: true),
                                  child: Text(l.appUpdateEmergencySkip(
                                      prompt.emergencySkipsRemaining)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
