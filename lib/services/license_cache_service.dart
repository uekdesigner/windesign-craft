// lib/services/license_cache_service.dart
//
// Sunucudan (ensureLicense) alınan SON BAŞARILI lisans durumunu cihaza
// yazar. Amaç: internet yokken uygulamanın açılabilmesi — o an sunucuya
// ulaşamıyorsak, en son bilinen duruma (belirli bir tolerans süresi
// içinde) güveniriz. Sadece "active" (lisanslı) durumlar için anlamlı;
// trial/locked durumları sunucu tarafında da kontrol edildiğinden bu
// cache offline modda onlara ekstra hak tanımaz (bkz. license_provider.dart).

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/license_model.dart';

class CachedLicense {
  final LicenseModel license;
  final DateTime cachedAt;

  const CachedLicense({required this.license, required this.cachedAt});
}

class LicenseCacheService {
  static const _keyData = 'cached_license_data';
  static const _keyCachedAt = 'cached_license_at';

  Future<void> save(LicenseModel license) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyData, jsonEncode(license.toMap()));
    await prefs.setInt(_keyCachedAt, DateTime.now().millisecondsSinceEpoch);
  }

  Future<CachedLicense?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyData);
    final cachedAtMs = prefs.getInt(_keyCachedAt);
    if (raw == null || cachedAtMs == null) return null;

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return CachedLicense(
        license: LicenseModel.fromMap(map),
        cachedAt: DateTime.fromMillisecondsSinceEpoch(cachedAtMs),
      );
    } catch (_) {
      // Bozuk/eski format cache — yok say.
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyData);
    await prefs.remove(_keyCachedAt);
  }
}
