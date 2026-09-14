import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/android_release.dart';

final androidUpdateInstallerProvider =
    Provider((ref) => AndroidUpdateInstaller());

class ApkDownload {
  const ApkDownload(this.state, {this.received = 0, this.total = -1});
  final String state;
  final int received;
  final int total;
  double? get progress => total > 0 ? (received / total).clamp(0, 1) : null;
}

/// Android owns the download and persists its identity across process restarts.
class AndroidUpdateInstaller {
  static const _channel = MethodChannel('vocechat/android_update');

  Future<ApkDownload> _download(String method, AndroidRelease release) async {
    final data = await _channel.invokeMapMethod<String, dynamic>(method, {
      'version_code': release.versionCode,
      if (method == 'start') 'url': release.updateUrl.toString(),
    });
    if (data == null) throw const FormatException('Missing download state');
    return ApkDownload(data['state'] as String,
        received: (data['received'] as num?)?.toInt() ?? 0,
        total: (data['total'] as num?)?.toInt() ?? -1);
  }

  Future<ApkDownload> status(AndroidRelease release) =>
      _download('status', release);
  Future<ApkDownload> start(AndroidRelease release) =>
      _download('start', release);
  Future<void> cancel(AndroidRelease release) => _channel
      .invokeMethod<void>('cancel', {'version_code': release.versionCode});
  Future<String> install(AndroidRelease release) async =>
      await _channel.invokeMethod<String>(
          'install', {'version_code': release.versionCode}) ??
      'failed';
  Future<void> requestPermission(AndroidRelease release) => _channel
      .invokeMethod<void>('permission', {'version_code': release.versionCode});
}
