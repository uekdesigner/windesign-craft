import 'package:cloud_functions/cloud_functions.dart';
import '../models/license_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'license_cache_service.dart';

class LicenseService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'us-central1',
  );

  // Uygulama ID'si — her uygulama için farklı olacak
  static const String appId = 'windesign_craft';

  /// Giriş sonrası bir kez çağrılır.
  /// İlk girişse 12 günlük denemeyi başlatır, değilse mevcut durumu döner.
  Future<LicenseModel> ensureLicense() async {
    final callable = _functions.httpsCallable('ensureLicense');
    final result = await callable.call({'appId': appId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return LicenseModel.fromMap(data);
  }

  /// Yeni proje oluşturmadan önce çağrılır.
  /// İzin verilirse normal döner; verilmezse hata fırlatır.
  /// Hata kodları: 'project_limit' | 'trial_expired'
  ///
  /// Ağ hatası (internet yok) durumunda: cache'te "active" (lisanslı) bir
  /// kayıt varsa sessizce izin verilir — sayaç zaten lisanslı kullanıcı
  /// için sunucuda anlamsız. Cache yoksa/trial ise LicenseOfflineException
  /// fırlatılır (ekranda "internet gerekiyor" mesajı için).
  Future<void> requestCreateProject() async {
    try {
      final callable = _functions.httpsCallable('createProject');
      await callable.call({'appId': appId});
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
    } catch (e) {
      final cached = await LicenseCacheService().load();
      if (cached != null && cached.license.isLicensed) return;
      throw LicenseOfflineException(e);
    }
  }

  /// PDF üretmeden önce çağrılır. İzin yoksa LicenseDeniedException fırlatır.
  /// Hata kodları: 'pdf_already_used' | 'trial_expired'
  ///
  /// Ağ hatası durumunda davranış requestCreateProject ile aynı: lisanslı
  /// kullanıcı için cache üzerinden sessizce izin verilir.
  Future<void> requestGeneratePdf(String projectId) async {
    try {
      final callable = _functions.httpsCallable('generatePdf');
      await callable.call({'appId': appId, 'projectId': projectId});
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
    } catch (e) {
      final cached = await LicenseCacheService().load();
      if (cached != null && cached.license.isLicensed) return;
      throw LicenseOfflineException(e);
    }
  }

  Future<LicenseModel> fetchStatus() => ensureLicense();

  /// Lisans anahtarını kullanır. Başarılıysa tier ve bitiş tarihi döner.
  Future<Map<String, dynamic>> redeemKey(String key) async {
    try {
      final callable = _functions.httpsCallable('redeemLicenseKey');
      final result = await callable.call({'appId': appId, 'key': key});
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
    }
  }

  /// Kurumsal anahtarı kullanır, organizasyonu oluşturur ve kullanıcıyı owner yapar.
  /// Başarılıysa orgId, seats ve bitiş tarihi döner.
  Future<Map<String, dynamic>> redeemCorporateKey({
    required String key,
    required String orgName,
  }) async {
    try {
      final callable = _functions.httpsCallable('redeemCorporateKey');
      final result = await callable.call({
        'appId': appId,
        'key': key,
        'orgName': orgName,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
    }
  }

  /// Sadece org owner çağırabilir. Koltuk doluysa hata fırlatır.
  /// Hata kodları: 'seats_full' | 'not_org_owner' | 'already_invited'
  Future<void> inviteEmployee({
    required String orgId,
    required String employeeEmail,
  }) async {
    try {
      final callable = _functions.httpsCallable('inviteEmployee');
      await callable.call({
        'appId': appId,
        'orgId': orgId,
        'employeeEmail': employeeEmail,
      });
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
    }
  }

  /// Kullanıcı kendi bekleyen davetini kabul eder.
  /// Hata kodları: 'no_pending_invite' | 'seats_full'
  Future<void> acceptInvite({required String orgId}) async {
    try {
      final callable = _functions.httpsCallable('acceptInvite');
      await callable.call({'appId': appId, 'orgId': orgId});
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
    }
  }

  /// Sadece org owner çağırabilir. Çalışanı çıkarır, o kullanıcı anında kilitlenir.
  Future<void> removeEmployee({
    required String orgId,
    required String employeeUid,
  }) async {
    try {
      final callable = _functions.httpsCallable('removeEmployee');
      await callable.call({
        'appId': appId,
        'orgId': orgId,
        'employeeUid': employeeUid,
      });
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
    }
  }

  /// Kullanıcının kendi e-postasına gelen bekleyen davetleri bulur.
  /// Dönen liste: [{orgId, orgName, invitedAt}, ...]
  Future<List<Map<String, dynamic>>> findMyInvites() async {
    try {
      final callable = _functions.httpsCallable('findMyInvites');
      final result = await callable.call({'appId': appId});
      final data = Map<String, dynamic>.from(result.data as Map);
      final invites = (data['invites'] ?? const []) as List;
      return invites.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
    }
  }

  /// Google Play satın almasını sunucuda doğrular ve lisansı aktive eder.
  /// Başarılıysa { active, tier, expiresAt } döner.
  Future<Map<String, dynamic>> verifyPurchase({
    required String productId,
    required String purchaseToken,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyPurchase');
      final result = await callable.call({
        'appId': appId,
        'productId': productId,
        'purchaseToken': purchaseToken,
      });
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
    }
  }
}

/// Lisans sınırı nedeniyle işlem reddedildiğinde fırlatılır (sunucu bilerek
/// reddetti — ör. proje limiti, deneme süresi doldu).
class LicenseDeniedException implements Exception {
  final String reason; // 'project_limit' | 'trial_expired' | ...
  LicenseDeniedException(this.reason);

  @override
  String toString() => 'LicenseDeniedException($reason)';
}

/// Sunucuya ulaşılamadığı (ağ yok vb.) VE kullanıcının offline-geçerli bir
/// lisansı da olmadığı durumda fırlatılır — trial kullanıcı bu duruma
/// düşerse "internet gerekiyor" mesajı göstermek için kullanılır.
class LicenseOfflineException implements Exception {
  final Object originalError;
  LicenseOfflineException(this.originalError);

  @override
  String toString() => 'Bu işlem için internet bağlantısı gerekiyor.';
}
