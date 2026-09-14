import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/android_update_installer.dart';
import '../domain/android_release.dart';

class ApkDownloadPanel extends ConsumerStatefulWidget {
  const ApkDownloadPanel({super.key, required this.release});
  final AndroidRelease release;

  @override
  ConsumerState<ApkDownloadPanel> createState() => _ApkDownloadPanelState();
}

class _ApkDownloadPanelState extends ConsumerState<ApkDownloadPanel>
    with WidgetsBindingObserver {
  ApkDownload _download = const ApkDownload('idle');
  Timer? _timer;
  bool _busy = true;
  bool _polling = false;
  bool _foreground = true;
  bool _autoInstall = false;
  bool _waitingPermission = false;
  String? _message;
  int _generation = 0;
  bool _installInFlight = false;

  AndroidUpdateInstaller get _installer =>
      ref.read(androidUpdateInstallerProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _timer?.cancel();
    } else if (_waitingPermission) {
      _waitingPermission = false;
      _install();
    } else {
      _refresh();
    }
  }

  void _accept(ApkDownload value) {
    _download = value;
    if (value.state == 'downloading') _autoInstall = true;
    if (value.state == 'failed') _message = 'download_failed';
    _timer?.cancel();
    if (value.state == 'downloading' && _foreground) {
      _timer = Timer(const Duration(seconds: 1), _refresh);
    }
  }

  Future<void> _refresh() async {
    if (_polling) return;
    _polling = true;
    final generation = _generation;
    try {
      final value = await _installer.status(widget.release);
      if (!mounted || generation != _generation) return;
      setState(() {
        _accept(value);
        _busy = false;
      });
      if (value.state == 'ready' && _autoInstall && _foreground) {
        _autoInstall = false;
        await _install();
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
          _message = 'download_failed';
        });
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _start() async {
    _generation++;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final value = await _installer.start(widget.release);
      if (!mounted) return;
      setState(() => _accept(value));
      if (value.state == 'ready') await _install();
    } catch (_) {
      if (mounted) setState(() => _message = 'download_failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    if (!mounted || !_foreground || _installInFlight) return;
    _installInFlight = true;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await _installer.install(widget.release);
      if (!mounted) return;
      setState(() {
        _message = result;
        if (result == 'invalid_apk') _download = const ApkDownload('idle');
      });
    } catch (_) {
      if (mounted) setState(() => _message = 'install_failed');
    } finally {
      _installInFlight = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _permission() async {
    setState(() => _busy = true);
    try {
      _waitingPermission = true;
      await _installer.requestPermission(widget.release);
    } catch (_) {
      _waitingPermission = false;
      if (mounted) setState(() => _message = 'install_failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    _generation++;
    _timer?.cancel();
    setState(() => _busy = true);
    try {
      await _installer.cancel(widget.release);
      if (mounted) {
        setState(() {
          _download = const ApkDownload('idle');
          _message = null;
          _autoInstall = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'download_failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final active = _download.state == 'downloading';
    final ready = _download.state == 'ready';
    final permission = _message == 'permission_required';
    final message = switch (_message) {
      'permission_required' => l.appUpdateInstallPermission,
      'invalid_apk' => l.appUpdateInvalidApk,
      'opened' => l.appUpdateInstallerOpened,
      'download_failed' => l.appUpdateDownloadFailed,
      null => null,
      _ => l.appUpdateInstallFailed,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (active) ...[
        LinearProgressIndicator(value: _download.progress),
        const SizedBox(height: 8),
        Text(_download.progress == null
            ? l.appUpdateDownloadingUnknown(
                (_download.received / 1048576).toStringAsFixed(1))
            : l.appUpdateDownloading((_download.progress! * 100).floor())),
        const SizedBox(height: 8),
      ],
      if (message != null) ...[Text(message), const SizedBox(height: 12)],
      FilledButton(
        onPressed: _busy
            ? null
            : active
                ? _cancel
                : permission
                    ? _permission
                    : ready
                        ? _install
                        : _start,
        child: Text(active
            ? l.appUpdateCancelDownload
            : permission
                ? l.appUpdateAllowInstall
                : ready
                    ? l.appUpdateInstall
                    : l.appUpdateDownload),
      ),
    ]);
  }
}
