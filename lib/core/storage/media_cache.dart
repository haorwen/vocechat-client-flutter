import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'video_stream_cache.dart';

/// Shared persistent cache facade for chat images, video, and streamed audio.
///
/// Images live in [DefaultCacheManager], video uses a byte-bounded Range cache,
/// and audio streamed through `LockCachingAudioSource` uses just_audio's cache.
class MediaCache {
  MediaCache._();

  static const int _maxAudioCacheBytes = 512 * 1024 * 1024;
  static const Duration _audioWriterMonitorLimit = Duration(minutes: 10);
  static final BaseCacheManager _fileCache = DefaultCacheManager();
  static final Map<String, ({int token, int generation})> _activeAudioWriters =
      {};
  static final Map<String, Set<int>> _activeAudioReaders = {};
  static final Set<String> _stalledAudioWriters = {};
  static final Set<String> _audioMaintenancePaths = {};
  static final Set<String> _deleteAudioWhenIdle = {};
  static int _nextAudioWriterToken = 0;
  static int _nextAudioReaderToken = 0;
  static int _audioCacheGeneration = 0;

  /// Cache key scoped to one signed-in account so protected attachments from
  /// two users on the same server can never share a local cache entry.
  static String scopedKey(String accountId, String url) => '$accountId::$url';

  /// Stable destination used by `LockCachingAudioSource`.
  static Future<io.File> audioFileForKey(String key) async {
    final directory = await _audioCacheDirectory();
    final separator = io.Platform.pathSeparator;
    final digest = sha256.convert(utf8.encode(key));
    final file = io.File('${directory.path}$separator$digest');
    try {
      if (await file.exists()) {
        final length = await file.length();
        if (length == 0 && !_isAudioPathActive(file.path)) {
          if (_audioMaintenancePaths.add(file.path)) {
            try {
              if (!_isAudioPathActive(file.path)) {
                await _deleteAudioCacheFiles(file.path);
              }
            } finally {
              _audioMaintenancePaths.remove(file.path);
            }
          }
          return file;
        }
        if (length > 0) {
          final lease = _activeAudioWriters[file.path];
          if (lease != null && _stalledAudioWriters.remove(file.path)) {
            if (lease.generation != _audioCacheGeneration) {
              _deleteAudioWhenIdle.add(file.path);
              _activeAudioWriters.remove(file.path);
              await _deleteAudioCacheIfIdle(file.path);
              return file;
            }
            _activeAudioWriters.remove(file.path);
          }
          await file.setLastModified(DateTime.now());
        }
      }
    } on io.FileSystemException {
      // A concurrent clear turns this into a normal cache miss.
    }
    return file;
  }

  /// Reserves one cache path for a single LockCachingAudioSource writer.
  /// Other players can still stream the URL directly while this writer fills
  /// the shared file, but they must not truncate the same `.part` file.
  static int? claimAudioCacheWriter(String filePath) {
    if (_activeAudioWriters.containsKey(filePath) ||
        _audioMaintenancePaths.contains(filePath) ||
        _deleteAudioWhenIdle.contains(filePath)) {
      return null;
    }
    final token = ++_nextAudioWriterToken;
    _activeAudioWriters[filePath] = (
      token: token,
      generation: _audioCacheGeneration,
    );
    return token;
  }

  /// Protects a completed cache file from LRU/clear while a player uses it.
  static int? claimAudioCacheReader(String filePath) {
    if (_audioMaintenancePaths.contains(filePath) ||
        _deleteAudioWhenIdle.contains(filePath)) {
      return null;
    }
    final token = ++_nextAudioReaderToken;
    (_activeAudioReaders[filePath] ??= <int>{}).add(token);
    return token;
  }

  static Future<void> releaseAudioCacheReader(
    String filePath,
    int token,
  ) async {
    final readers = _activeAudioReaders[filePath];
    readers?.remove(token);
    if (readers != null && readers.isEmpty) {
      _activeAudioReaders.remove(filePath);
    }
    await _deleteAudioCacheIfIdle(filePath);
  }

  /// Holds an audio-writer reservation until the cache completes or fails.
  /// A clear requested in the meantime removes the completed file afterwards,
  /// preventing an in-flight stream from silently repopulating the cache.
  static Future<void> monitorAudioCacheWriter(
    String filePath,
    int token,
  ) async {
    final lease = _activeAudioWriters[filePath];
    if (lease == null || lease.token != token) return;
    final file = io.File(filePath);
    final partial = io.File('$filePath.part');
    final deadline = DateTime.now().add(_audioWriterMonitorLimit);
    var sawPartial = false;
    var retainLease = false;
    try {
      while (true) {
        final current = _activeAudioWriters[filePath];
        if (current == null || current.token != token) return;
        if (await file.exists() && await file.length() > 0) break;
        final partialExists = await partial.exists();
        sawPartial = sawPartial || partialExists;
        if (sawPartial && !partialExists) break;
        if (DateTime.now().isAfter(deadline)) {
          // The source exposes no cancellation hook. Retain the reservation so
          // a late response can never collide with a replacement writer, but
          // stop the polling loop and let other instances stream directly.
          _stalledAudioWriters.add(filePath);
          retainLease = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } catch (_) {
      // File removal during cache maintenance is treated as a failed writer.
    } finally {
      final current = _activeAudioWriters[filePath];
      if (!retainLease && current != null && current.token == token) {
        try {
          if (await file.exists() && await file.length() == 0) {
            await _deleteAudioCacheFiles(filePath);
          }
        } on io.FileSystemException {
          // The source may be completing its atomic rename concurrently.
        }
        if (lease.generation != _audioCacheGeneration) {
          _deleteAudioWhenIdle.add(filePath);
        } else {
          await trimAudioCache();
        }
        final latest = _activeAudioWriters[filePath];
        if (latest != null && latest.token == token) {
          _activeAudioWriters.remove(filePath);
          _stalledAudioWriters.remove(filePath);
        }
        await _deleteAudioCacheIfIdle(filePath);
      }
    }
  }

  /// Invalidates a failed writer without racing a still-closing `.part` file.
  static Future<void> failAudioCacheWriter(
    String filePath,
    int token,
  ) async {
    _deleteAudioWhenIdle.add(filePath);
    final current = _activeAudioWriters[filePath];
    if (current == null || current.token != token) {
      await _deleteAudioCacheIfIdle(filePath);
      return;
    }
    try {
      if (await io.File('$filePath.part').exists()) {
        return;
      }
    } on io.FileSystemException {
      // An unreadable partial is left to the monitor/next startup cleanup.
      return;
    }
    final latest = _activeAudioWriters[filePath];
    if (latest != null && latest.token == token) {
      _activeAudioWriters.remove(filePath);
      _stalledAudioWriters.remove(filePath);
    }
    await _deleteAudioCacheIfIdle(filePath);
  }

  /// Waits for any in-flight LockCachingAudioSource before a save operation so
  /// the download action does not start a second request for the same audio.
  static Future<io.File?> completedAudioFile(
    String key, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (kIsWeb) return null;
    try {
      final file = await audioFileForKey(key);
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (await file.exists() && await file.length() > 0) return file;
        final active = _activeAudioWriters.containsKey(file.path);
        if (!active || _stalledAudioWriters.contains(file.path)) {
          return null;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } catch (_) {
      // A failed/expired stream falls back to the ordinary download path.
    }
    return null;
  }

  /// Returns a temporary complete file assembled from the video Range cache.
  static Future<io.File?> exportVideoForDownload(
    String url,
    Map<String, String> originHeaders, {
    required String cacheKey,
  }) async {
    if (kIsWeb) return null;
    final path = await VideoStreamCache.exportForDownload(
      url,
      originHeaders,
      cacheKey: cacheKey,
    );
    if (path == null) return null;
    final file = io.File(path);
    try {
      if (await file.exists() && await file.length() > 0) return file;
    } on io.FileSystemException {
      // Treat an export removed by a concurrent cache clear as a miss.
    }
    return null;
  }

  /// Evicts least-recently-used complete audio files above the size limit.
  /// Fresh `.part` downloads count toward the limit but are never evicted;
  /// abandoned partial files from an interrupted process are removed.
  static Future<void> trimAudioCache() async {
    if (kIsWeb) return;
    try {
      final directory = await _audioCacheDirectory();
      if (!await directory.exists()) return;

      final entries = <({io.File file, int size, DateTime modified})>[];
      var total = 0;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! io.File) continue;
        try {
          if (entity.path.endsWith('.mime')) {
            final basePath = entity.path.substring(
              0,
              entity.path.length - '.mime'.length,
            );
            if (!_isAudioPathActive(basePath) &&
                !await io.File(basePath).exists() &&
                !await io.File('$basePath.part').exists()) {
              await entity.delete();
            }
            continue;
          }
          final stat = await entity.stat();
          if (entity.path.endsWith('.part')) {
            final basePath = entity.path.substring(
              0,
              entity.path.length - '.part'.length,
            );
            if (!_isAudioPathActive(basePath) &&
                _audioMaintenancePaths.add(basePath)) {
              try {
                if (!_isAudioPathActive(basePath)) {
                  await entity.delete();
                  final mimeFile = io.File('$basePath.mime');
                  if (await mimeFile.exists()) await mimeFile.delete();
                }
              } finally {
                _audioMaintenancePaths.remove(basePath);
              }
            } else {
              total += stat.size;
            }
            continue;
          }
          total += stat.size;
          if (!_isAudioPathActive(entity.path)) {
            entries
                .add((file: entity, size: stat.size, modified: stat.modified));
          }
        } on io.FileSystemException {
          // Skip files removed while the cache is being inspected.
        }
      }
      if (total <= _maxAudioCacheBytes) return;

      entries.sort((a, b) => a.modified.compareTo(b.modified));
      for (final entry in entries) {
        if (total <= _maxAudioCacheBytes) break;
        if (!_audioMaintenancePaths.add(entry.file.path)) continue;
        try {
          if (_isAudioPathActive(entry.file.path)) continue;
          await entry.file.delete();
          final mimeFile = io.File('${entry.file.path}.mime');
          if (await mimeFile.exists()) await mimeFile.delete();
          total -= entry.size;
        } on io.FileSystemException {
          // A playing file may be locked on Windows; try another candidate.
        } finally {
          _audioMaintenancePaths.remove(entry.file.path);
        }
      }
    } catch (_) {
      // Cache maintenance must never prevent playback.
    }
  }

  /// Returns a completed cached file, including stale entries, when present.
  ///
  /// A stale media file is still useful for immediate/offline playback. It is
  /// eventually evicted by flutter_cache_manager's normal LRU cleanup.
  static Future<io.File?> fileForKey(String key) async {
    if (kIsWeb) return null;
    FileInfo? info;
    try {
      info = await _fileCache.getFileFromCache(key);
    } catch (_) {
      return null;
    }
    if (info == null) return null;

    final file = io.File(info.file.path);
    try {
      if (await file.exists() && await file.length() > 0) return file;
    } on io.FileSystemException {
      // Treat an unreadable cache entry as a miss.
    }
    await _fileCache.removeFile(key);
    return null;
  }

  /// Clears image files, video segments, and just_audio's streamed cache.
  static Future<void> clear() async {
    try {
      await _fileCache.emptyCache();
    } catch (_) {
      // The directory fallback below still removes the actual image bytes.
    }
    if (!kIsWeb) {
      try {
        final temp = await getTemporaryDirectory();
        // flutter_cache_manager 3.4.1 removes relative paths from the process
        // working directory. 3.4.2 fixes it but requires Dart 3.8, so explicitly
        // remove the real cache directory while this project remains on 3.6.
        final imageDir = io.Directory(
          '${temp.path}${io.Platform.pathSeparator}libCachedImageData',
        );
        try {
          if (await imageDir.exists()) await imageDir.delete(recursive: true);
        } catch (_) {
          // Decoded images may still hold a file briefly.
        }
        _audioCacheGeneration++;
        final audioDir = await _audioCacheDirectory();
        await _clearInactiveAudioFiles(audioDir);
      } catch (_) {
        // Cache clearing is best-effort; video cleanup should still run.
      }
    }
    try {
      await VideoStreamCache.clear();
    } catch (_) {
      // A player closing concurrently must not block the rest of cache clear.
    }
  }

  /// Total bytes occupied by cached images, video segments, and streamed audio.
  static Future<int> diskUsageBytes() async {
    final videoBytes = await VideoStreamCache.diskUsageBytes();
    if (kIsWeb) return videoBytes;
    try {
      final temp = await getTemporaryDirectory();
      final separator = io.Platform.pathSeparator;
      final directories = [
        io.Directory('${temp.path}${separator}libCachedImageData'),
        await _audioCacheDirectory(),
      ];
      var total = 0;
      for (final directory in directories) {
        total += await _directorySize(directory);
      }
      return total + videoBytes;
    } catch (_) {
      return videoBytes;
    }
  }

  static Future<int> _directorySize(io.Directory directory) async {
    var total = 0;
    try {
      if (!await directory.exists()) return 0;
      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is io.File) {
          try {
            total += await entity.length();
          } on io.FileSystemException {
            // Skip files removed while the directory is being measured.
          }
        }
      }
    } on io.FileSystemException {
      // Cache accounting is best-effort.
    }
    return total;
  }

  static Future<void> _clearInactiveAudioFiles(io.Directory directory) async {
    try {
      if (!await directory.exists()) return;
      final basePaths = <String>{};
      await for (final entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is! io.File) continue;
        var basePath = entity.path;
        if (basePath.endsWith('.part')) {
          basePath = basePath.substring(0, basePath.length - '.part'.length);
        } else if (basePath.endsWith('.mime')) {
          basePath = basePath.substring(0, basePath.length - '.mime'.length);
        }
        basePaths.add(basePath);
      }
      for (final basePath in basePaths) {
        if (!_audioMaintenancePaths.add(basePath)) continue;
        try {
          if (_isAudioPathActive(basePath)) {
            _deleteAudioWhenIdle.add(basePath);
            continue;
          }
          final deleted = await _deleteAudioCacheFiles(basePath);
          if (deleted) {
            _deleteAudioWhenIdle.remove(basePath);
          } else {
            _deleteAudioWhenIdle.add(basePath);
          }
        } finally {
          _audioMaintenancePaths.remove(basePath);
        }
      }
    } on io.FileSystemException {
      // Cache clearing is best-effort.
    }
  }

  static Future<bool> _deleteAudioCacheFiles(String filePath) async {
    var deletedAll = true;
    for (final path in [filePath, '$filePath.part', '$filePath.mime']) {
      try {
        final file = io.File(path);
        if (await file.exists()) await file.delete();
      } on io.FileSystemException {
        // The stream may still be closing its file handle on Windows.
        deletedAll = false;
      }
    }
    return deletedAll;
  }

  static bool _isAudioPathActive(String filePath) =>
      _activeAudioWriters.containsKey(filePath) ||
      (_activeAudioReaders[filePath]?.isNotEmpty ?? false);

  static Future<void> _deleteAudioCacheIfIdle(String filePath) async {
    if (!_deleteAudioWhenIdle.contains(filePath) ||
        _isAudioPathActive(filePath) ||
        !_audioMaintenancePaths.add(filePath)) {
      return;
    }
    try {
      if (_isAudioPathActive(filePath)) return;
      final deleted = await _deleteAudioCacheFiles(filePath);
      if (deleted) {
        _deleteAudioWhenIdle.remove(filePath);
      }
    } finally {
      _audioMaintenancePaths.remove(filePath);
    }
  }

  static Future<io.Directory> _audioCacheDirectory() async {
    final root = await getApplicationCacheDirectory();
    final separator = io.Platform.pathSeparator;
    final directory = io.Directory(
      '${root.path}${separator}voce_media${separator}audio',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }
}
