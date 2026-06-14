import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/license_provider.dart';
import '../../screens/login_screen.dart';
import '../../home/home_page.dart';
import '../../screens/locked_screen.dart';
import '../../screens/phone_verification_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      // Giriş durumu belli değil → kısa yüklenme
      loading: () => const _LoadingScaffold(message: 'Yükleniyor...'),
      error: (e, _) => _ErrorScaffold(message: 'Giriş hatası: $e'),
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }
        // Telefon doğrulanmamışsa → doğrulama ekranı
        if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
          return PhoneVerificationScreen();
        }
        // Telefon doğrulanmış → lisans kontrolüne geç
        return const _LicenseGate();
      },
    );
  }
}

/// Giriş yapılmış kullanıcı için lisansı yükler ve sonucuna göre yönlendirir.
class _LicenseGate extends ConsumerWidget {
  const _LicenseGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final license = ref.watch(licenseProvider);

    return license.when(
      loading: () =>
          const _LoadingScaffold(message: 'Lisans kontrol ediliyor...'),
      error: (e, _) => _ErrorScaffold(
        message:
            'Lisans bilgisi alınamadı.\nİnternet bağlantını kontrol et.\n\n$e',
        onRetry: () => ref.invalidate(licenseProvider),
      ),
      data: (lic) {
        // 12 gün dolmuş ve lisanssız → kilitli ekran
        if (lic.isLocked || (lic.isTrial && (lic.trialDaysLeft ?? 0) < 0)) {
          return LockedScreen(daysOverdue: lic.trialDaysLeft?.abs());
        }
        // Deneme devam ediyor veya lisanslı → ana ekran
        return const HomePage();
      },
    );
  }
}

/// Ortak yüklenme ekranı.
class _LoadingScaffold extends StatelessWidget {
  final String message;
  const _LoadingScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

/// Ortak hata ekranı (opsiyonel tekrar dene butonu ile).
class _ErrorScaffold extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorScaffold({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
