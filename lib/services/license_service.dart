import 'package:cloud_functions/cloud_functions.dart';
import '../models/license_model.dart';
import 'package:firebase_core/firebase_core.dart';

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
  Future<void> requestCreateProject() async {
    try {
      final callable = _functions.httpsCallable('createProject');
      await callable.call({'appId': appId});
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
    }
  }

  /// PDF üretmeden önce çağrılır. İzin yoksa LicenseDeniedException fırlatır.
  /// Hata kodları: 'pdf_already_used' | 'trial_expired'
  Future<void> requestGeneratePdf(String projectId) async {
    try {
      final callable = _functions.httpsCallable('generatePdf');
      await callable.call({'appId': appId, 'projectId': projectId});
    } on FirebaseFunctionsException catch (e) {
      throw LicenseDeniedException(e.message ?? 'unknown');
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
}

/// Lisans sınırı nedeniyle işlem reddedildiğinde fırlatılır.
class LicenseDeniedException implements Exception {
  final String reason; // 'project_limit' | 'trial_expired' | ...
  LicenseDeniedException(this.reason);

  @override
  String toString() => 'LicenseDeniedException($reason)';
}
