library;

import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Keeps flutter_video_caching on Dio's portable transport.
///
/// The cache only needs HTTP Range support. Delegating to Dio avoids raising
/// this app's Android, iOS, and macOS deployment targets for native transports.
class NativeAdapter implements HttpClientAdapter {
  NativeAdapter() : _delegate = HttpClientAdapter();

  final HttpClientAdapter _delegate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      _delegate.fetch(options, requestStream, cancelFuture);

  @override
  void close({bool force = false}) => _delegate.close(force: force);
}
