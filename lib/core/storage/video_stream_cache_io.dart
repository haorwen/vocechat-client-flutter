import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_video_caching/ext/file_ext.dart';
import 'package:flutter_video_caching/flutter_video_caching.dart';

class VideoStreamCache {
  VideoStreamCache._();

  static bool _ready = false;
  static Future<void>? _initializing;
  static Future<void> _exportBarrier = Future<void>.value();
  static int _exportSequence = 0;
  static int _cacheGeneration = 0;

  static Future<void> initialize() {
    final active = _initializing;
    if (active != null) return active;
    final future = _initialize();
    _initializing = future;
    return future.whenComplete(() {
      if (identical(_initializing, future)) _initializing = null;
    });
  }

  static Future<void> _initialize() async {
    if (_ready) return;
    try {
      await VideoProxy.init(
        maxMemoryCacheSize: 32,
        maxStorageCacheSize: 1024,
        segmentSize: 2,
        maxConcurrentDownloads: 4,
        urlMatcher: _VoceVideoUrlMatcher(),
      );
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<bool> ensureReady() async {
    await initialize();
    if (!_ready) return false;
    if (await VideoProxy.isRunning()) return true;
    try {
      await VideoProxy.restart();
      if (await VideoProxy.isRunning()) return true;
      _ready = false;
      return false;
    } catch (_) {
      _ready = false;
      return false;
    }
  }

  static Uri playbackUri(String url) => url.toLocalUri();

  static Map<String, String> playbackHeaders(
    Map<String, String> originHeaders, {
    required String cacheKey,
  }) {
    return {
      ...originHeaders,
      'Custom-Cache-ID': sha256.convert(utf8.encode(cacheKey)).toString(),
    };
  }

  /// Reassembles cached MP4 ranges and downloads only missing segments.
  static Future<String?> exportForDownload(
    String url,
    Map<String, String> originHeaders, {
    required String cacheKey,
  }) async {
    if (!await ensureReady()) return null;
    final generation = _cacheGeneration;
    return _serializeExport(() async {
      if (generation != _cacheGeneration) return null;
      final uri = url.toSafeUri();
      final urlHash = md5.convert(utf8.encode(uri.toString())).toString();
      final cacheDir = await FileExt.createCachePath(urlHash);
      final sharedExport = File('$cacheDir/$urlHash.export.mp4');
      final partialExport = File('${sharedExport.path}.tmp');
      try {
        // The package's export name is URL-only. Remove any interrupted export
        // before assembling account-scoped segments, then rename the result to
        // a one-shot private path before another account can export this URL.
        if (await sharedExport.exists()) await sharedExport.delete();
        if (await partialExport.exists()) await partialExport.delete();
        final file = await VideoCaching.exportCachedMp4(
          url,
          headers: playbackHeaders(originHeaders, cacheKey: cacheKey),
          timeout: const Duration(minutes: 10),
          downloadMissingSegments: true,
        );
        if (file == null || !await file.exists() || await file.length() == 0) {
          return null;
        }
        if (generation != _cacheGeneration) return null;
        final privateName = sha256
            .convert(utf8.encode(
              '$cacheKey:${DateTime.now().microsecondsSinceEpoch}:'
              '${_exportSequence++}',
            ))
            .toString();
        final privateFile = await file.rename(
          '$cacheDir/$privateName.export-download',
        );
        return privateFile.path;
      } catch (_) {
        return null;
      } finally {
        try {
          if (await sharedExport.exists()) await sharedExport.delete();
          if (await partialExport.exists()) await partialExport.delete();
        } catch (_) {
          // A concurrent clear may already have removed the export directory.
        }
      }
    });
  }

  static Future<T> _serializeExport<T>(Future<T> Function() operation) async {
    final previous = _exportBarrier;
    final release = Completer<void>();
    _exportBarrier = release.future;
    try {
      await previous;
      return await operation();
    } finally {
      release.complete();
    }
  }

  static Future<void> clear() async {
    final generation = ++_cacheGeneration;
    await _serializeExport(() async {
      // A newer clear queued behind this one will perform the final cleanup.
      if (generation != _cacheGeneration) return;
      if (_ready) {
        try {
          // Replacing the manager cancels in-flight playback segment writes.
          await VideoProxy.restart();
        } catch (_) {
          _ready = false;
        }
      }
      await LruCacheSingleton().memoryClear();
      await LruCacheSingleton().storageClear();
    });
  }

  static Future<int> diskUsageBytes() async {
    try {
      return await LruCacheSingleton().storageSizeInBytes();
    } catch (_) {
      return 0;
    }
  }
}

class _VoceVideoUrlMatcher extends UrlMatcherDefault {
  String _resourcePath(Uri uri) =>
      (uri.queryParameters['file_path'] ?? uri.path).toLowerCase();

  @override
  bool matchM3u8(Uri uri) => _resourcePath(uri).endsWith('.m3u8');

  @override
  bool matchM3u8Key(Uri uri) => _resourcePath(uri).endsWith('.key');

  @override
  bool matchM3u8Segment(Uri uri) => _resourcePath(uri).endsWith('.ts');

  @override
  bool matchMp4(Uri uri) {
    final path = _resourcePath(uri);
    return path.endsWith('.mp4') ||
        path.endsWith('.m4v') ||
        path.endsWith('.mov');
  }

  @override
  Uri matchCacheKey(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters)
      ..remove('download')
      ..remove('thumbnail');
    return uri.replace(queryParameters: params.isEmpty ? null : params);
  }
}
