/// Public update metadata. Unknown fields are deliberately ignored so the
/// service can add optional fields without breaking installed clients.
class AndroidRelease {
  const AndroidRelease({
    required this.version,
    required this.versionCode,
    required this.timestamp,
    required this.forceUpdate,
    required this.updateUrl,
    this.lastForceVersionCode = 0,
    this.announcement,
    this.localizedAnnouncements = const {},
  });

  final String version;
  final int versionCode;

  /// Server response time, Unix milliseconds (UTC), not the publication time.
  final int timestamp;
  final bool forceUpdate;

  /// Latest forced build, including this release if it is forced. Zero means
  /// no forced release has ever been published.
  final int lastForceVersionCode;
  final Uri updateUrl;
  final String? announcement;
  final Map<String, String> localizedAnnouncements;

  String? announcementFor(String languageCode) {
    final preferred = languageCode == 'zh' ? 'zh' : 'en';
    for (final text in [
      localizedAnnouncements[preferred],
      localizedAnnouncements['en'],
      localizedAnnouncements['zh'],
      announcement
    ]) {
      if (text != null && text.trim().isNotEmpty) return text.trim();
    }
    return null;
  }

  factory AndroidRelease.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final versionCode = json['version_code'];
    final timestamp = json['timestamp'];
    final forceUpdate = json['force_update'];
    // Missing on the original protocol; force_update still applies there.
    final lastForceVersionCode = json['last_force_version_code'] ?? 0;
    final url = json['update_url'];
    final announcement = json['announcement'];
    final uri = url is String ? Uri.tryParse(url) : null;
    if (version is! String ||
        version.trim().isEmpty ||
        versionCode is! int ||
        versionCode <= 0 ||
        versionCode > 2100000000 ||
        timestamp is! int ||
        timestamp <= 0 ||
        forceUpdate is! bool ||
        lastForceVersionCode is! int ||
        lastForceVersionCode < 0 ||
        lastForceVersionCode > versionCode ||
        uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (announcement != null &&
            announcement is! String &&
            (announcement is! Map<String, dynamic> ||
                announcement.values.any((value) => value is! String)))) {
      throw const FormatException('Invalid Android update metadata');
    }
    return AndroidRelease(
      version: version,
      versionCode: versionCode,
      timestamp: timestamp,
      forceUpdate: forceUpdate,
      lastForceVersionCode: lastForceVersionCode,
      updateUrl: uri,
      announcement: announcement is String ? announcement : null,
      localizedAnnouncements: announcement is Map<String, dynamic>
          ? Map<String, String>.unmodifiable(
              announcement.cast<String, String>())
          : const {},
    );
  }

  bool isNewerThan(int installedVersionCode) =>
      versionCode > installedVersionCode;

  int get requiredVersionCode =>
      forceUpdate ? versionCode : lastForceVersionCode;

  bool isRequiredFor(int installedVersionCode) =>
      installedVersionCode < requiredVersionCode;

  Map<String, dynamic> toJson() => {
        'version': version,
        'version_code': versionCode,
        'timestamp': timestamp,
        'force_update': forceUpdate,
        'last_force_version_code': lastForceVersionCode,
        'update_url': updateUrl.toString(),
        if (localizedAnnouncements.isNotEmpty)
          'announcement': localizedAnnouncements
        else if (announcement != null)
          'announcement': announcement,
      };
}
