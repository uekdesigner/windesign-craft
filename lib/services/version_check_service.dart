// lib/services/version_check_service.dart
//
// Uygulama açılışında çalışan sürüm kontrolü. Play Store'un "In-App Update"
// API'sinden FARKLI olarak — hem Play Store'dan hem manuel APK'dan kurulmuş
// kullanıcılar için AYNI ŞEKİLDE çalışır, çünkü mağazadan bağımsızdır.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/app_version_config.dart';

enum UpdateUrgency {
  none, // güncel, hiçbir şey gösterme
  optional, // "yeni sürüm var" — kapatılabilir
  required, // eski sürüm artık desteklenmiyor — bloklayıcı ekran
}

class VersionCheckResult {
  final UpdateUrgency urgency;
  final AppVersionConfig? config;
  final int currentBuildNumber;

  const VersionCheckResult({
    required this.urgency,
    required this.currentBuildNumber,
    this.config,
  });
}

class VersionCheckService {
  Future<VersionCheckResult> check() async {
    final info = await PackageInfo.fromPlatform();
    final current = int.tryParse(info.buildNumber) ?? 0;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('latest')
          .get();

      // Doküman henüz oluşturulmamışsa (örn. ilk kurulum aşamasında)
      // kullanıcıyı ASLA bloklama — sessizce geç.
      if (!snap.exists || snap.data() == null) {
        return VersionCheckResult(
          urgency: UpdateUrgency.none,
          currentBuildNumber: current,
        );
      }

      final config = AppVersionConfig.fromMap(snap.data()!);

      if (config.minSupportedBuildNumber > 0 &&
          current < config.minSupportedBuildNumber) {
        return VersionCheckResult(
          urgency: UpdateUrgency.required,
          config: config,
          currentBuildNumber: current,
        );
      }

      if (config.latestBuildNumber > 0 && current < config.latestBuildNumber) {
        return VersionCheckResult(
          urgency: UpdateUrgency.optional,
          config: config,
          currentBuildNumber: current,
        );
      }

      return VersionCheckResult(
        urgency: UpdateUrgency.none,
        config: config,
        currentBuildNumber: current,
      );
    } catch (e) {
      // Ağ hatası, izin hatası vb. — kontrolü yapamıyorsak kullanıcıyı
      // ASLA dışarıda bırakmayız; sessizce devam ederiz.
      return VersionCheckResult(
        urgency: UpdateUrgency.none,
        currentBuildNumber: current,
      );
    }
  }
}
