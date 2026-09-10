import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// Re-fetch when the active server changes or the About pane is reopened.
final serverVersionProvider = FutureProvider.autoDispose<String>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get<String>(
    '/api/admin/system/version',
    options: Options(
      responseType: ResponseType.plain,
      headers: {'accept': 'text/plain'},
    ),
  );
  final version = response.data?.trim();
  if (version == null || version.isEmpty) {
    throw const FormatException('Missing server version');
  }
  return version;
});
