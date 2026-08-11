import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/core/storage/media_cache.dart';
import 'package:vocechat_client/core/storage/video_stream_cache.dart';

void main() {
  const mediaUrl =
      'https://chat.example/api/resource/file?file_path=2026/video.mp4';

  test('media cache keys are isolated by account', () {
    final aliceKey = MediaCache.scopedKey('server/alice', mediaUrl);
    final bobKey = MediaCache.scopedKey('server/bob', mediaUrl);

    expect(aliceKey, isNot(bobKey));
    expect(aliceKey, MediaCache.scopedKey('server/alice', mediaUrl));
  });

  test('video cache uses an opaque account-scoped ID', () {
    const originHeaders = <String, String>{
      'Referer': 'https://chat.example/',
      'X-API-Key': 'secret',
    };
    final accountKey = MediaCache.scopedKey('server/alice', mediaUrl);

    final playbackHeaders = VideoStreamCache.playbackHeaders(
      originHeaders,
      cacheKey: accountKey,
    );
    final otherAccountHeaders = VideoStreamCache.playbackHeaders(
      originHeaders,
      cacheKey: MediaCache.scopedKey('server/bob', mediaUrl),
    );

    expect(playbackHeaders['Referer'], originHeaders['Referer']);
    expect(playbackHeaders['X-API-Key'], originHeaders['X-API-Key']);
    expect(playbackHeaders['Custom-Cache-ID'], hasLength(64));
    expect(playbackHeaders['Custom-Cache-ID'], isNot(contains('alice')));
    expect(
      playbackHeaders['Custom-Cache-ID'],
      isNot(otherAccountHeaders['Custom-Cache-ID']),
    );
    expect(originHeaders.containsKey('Custom-Cache-ID'), isFalse);
  });

  test('audio cache serializes writers and clears failed leases', () async {
    const path = '__voce_media_cache_single_flight_test__';
    final reader = MediaCache.claimAudioCacheReader(path);
    final firstWriter = MediaCache.claimAudioCacheWriter(path);

    expect(reader, isNotNull);
    expect(firstWriter, isNotNull);
    expect(MediaCache.claimAudioCacheWriter(path), isNull);

    await MediaCache.failAudioCacheWriter(path, firstWriter!);
    expect(MediaCache.claimAudioCacheWriter(path), isNull);
    await MediaCache.releaseAudioCacheReader(path, reader!);

    final nextReader = MediaCache.claimAudioCacheReader(path);
    final nextWriter = MediaCache.claimAudioCacheWriter(path);
    expect(nextReader, isNotNull);
    expect(nextWriter, isNotNull);

    await MediaCache.failAudioCacheWriter(path, nextWriter!);
    await MediaCache.releaseAudioCacheReader(path, nextReader!);
  });
}
