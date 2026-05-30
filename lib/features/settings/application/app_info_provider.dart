import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_info_provider.g.dart';

/// App package metadata (version + build number) read once from the platform.
///
/// Used by the About pane so the displayed version tracks `pubspec.yaml`
/// instead of a hardcoded string. Kept alive: the values never change for the
/// lifetime of the process.
@Riverpod(keepAlive: true)
Future<PackageInfo> appPackageInfo(Ref ref) => PackageInfo.fromPlatform();
