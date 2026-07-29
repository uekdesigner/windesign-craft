// lib/models/app_version_config.dart
//
// Firestore'daki app_config/latest dokümanının karşılığı.
// Bu doküman herkese açık (okuma) — hiçbir gizli/kişisel veri içermez,
// sadece "en güncel sürüm hangisi" bilgisi.

class AppVersionConfig {
  final int latestBuildNumber;
  final int minSupportedBuildNumber;
  final String changelogTr;
  final String playStoreUrl;
  final String manualApkUrl;

  const AppVersionConfig({
    required this.latestBuildNumber,
    required this.minSupportedBuildNumber,
    this.changelogTr = '',
    this.playStoreUrl = '',
    this.manualApkUrl = '',
  });

  factory AppVersionConfig.fromMap(Map<String, dynamic> map) {
    return AppVersionConfig(
      latestBuildNumber: (map['latestBuildNumber'] as num?)?.toInt() ?? 0,
      minSupportedBuildNumber:
          (map['minSupportedBuildNumber'] as num?)?.toInt() ?? 0,
      changelogTr: map['changelogTr'] as String? ?? '',
      playStoreUrl: map['playStoreUrl'] as String? ?? '',
      manualApkUrl: map['manualApkUrl'] as String? ?? '',
    );
  }
}
