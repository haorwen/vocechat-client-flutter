class VideoStreamCache {
  VideoStreamCache._();

  static Future<void> initialize() async {}

  static Future<bool> ensureReady() async => false;

  static Uri playbackUri(String url) => Uri.parse(url);

  static Map<String, String> playbackHeaders(
    Map<String, String> originHeaders, {
    required String cacheKey,
  }) =>
      Map<String, String>.from(originHeaders);

  static Future<String?> exportForDownload(
    String url,
    Map<String, String> originHeaders, {
    required String cacheKey,
  }) async =>
      null;

  static Future<void> clear() async {}

  static Future<int> diskUsageBytes() async => 0;
}
