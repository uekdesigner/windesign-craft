import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/license_model.dart';
import '../services/license_service.dart';
import '../services/license_cache_service.dart';

/// Sunucuya ulaşılamadığında (ağ yok) VE kullanılabilir bir cache de
/// yoksa/süresi dolmuşsa fırlatılır. AuthGate bu durumda hata ekranı
/// (artık gerçek "Tekrar Dene" butonuyla) gösterir.
class LicenseUnreachableException implements Exception {
  final Object originalError;
  LicenseUnreachableException(this.originalError);

  @override
  String toString() => 'Lisans sunucusuna ulaşılamadı: $originalError';
}

/// Lisanslı (active) kullanıcılar için: son başarılı kontrolden itibaren bu
/// süre içinde ağ yoksa cache'teki duruma güvenilir. Trial/locked durumlar
/// zaten sunucu tarafında kontrol edildiği için bu tolerans onlara
/// uygulanmaz (bkz. aşağıdaki isLicensed kontrolü).
const licenseOfflineGraceWindow = Duration(days: 5);

/// LicenseService örneğini sağlar.
final licenseServiceProvider = Provider<LicenseService>((ref) {
  return LicenseService();
});

/// LicenseCacheService örneğini sağlar.
final licenseCacheServiceProvider = Provider<LicenseCacheService>((ref) {
  return LicenseCacheService();
});

/// Lisans durumunu tutar. Giriş sonrası ensureLicense çağrılınca dolar.
/// Uygulamanın her yerinden ref.watch(licenseProvider) ile okunur.
///
/// Sunucu çağrısı başarısız olursa (ör. internet yok): cache'te "active"
/// durumda ve licenseOfflineGraceWindow içinde bir kayıt varsa o veriyle
/// sessizce devam edilir. Yoksa (trial/locked/cache-yok/süre-dolmuş)
/// LicenseUnreachableException fırlatılır.
final licenseProvider = FutureProvider<LicenseModel>((ref) async {
  final service = ref.watch(licenseServiceProvider);
  final cacheService = ref.watch(licenseCacheServiceProvider);

  try {
    final license = await service.ensureLicense();
    // Başarılı sonucu cache'e yaz — bir sonraki offline açılışta kullanılır.
    await cacheService.save(license);
    return license;
  } catch (e) {
    final cached = await cacheService.load();

    if (cached != null &&
        cached.license.isLicensed &&
        DateTime.now().difference(cached.cachedAt) <=
            licenseOfflineGraceWindow) {
      return cached.license;
    }

    throw LicenseUnreachableException(e);
  }
});
