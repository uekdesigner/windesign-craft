import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/license_model.dart';
import '../services/license_service.dart';

/// LicenseService örneğini sağlar.
final licenseServiceProvider = Provider<LicenseService>((ref) {
  return LicenseService();
});

/// Lisans durumunu tutar. Giriş sonrası ensureLicense çağrılınca dolar.
/// Uygulamanın her yerinden ref.watch(licenseProvider) ile okunur.
final licenseProvider = FutureProvider<LicenseModel>((ref) async {
  final service = ref.watch(licenseServiceProvider);
  return service.ensureLicense();
});
