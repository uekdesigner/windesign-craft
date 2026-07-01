// lib/shared/widgets/auth_gate.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/license_provider.dart';
import '../../screens/login_screen.dart';
import '../../home/home_page.dart';
import '../../screens/locked_screen.dart';
import '../../screens/phone_verification_screen.dart';
import '../../screens/splash_screen.dart';

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
          return const PhoneVerificationScreen();
        }
        // Telefon doğrulanmış → lisans kontrolüne geç
        return const _LicenseGate();
      },
    );
  }
}

/// Giriş yapılmış kullanıcı için lisansı yükler ve sonucuna göre yönlendirir.
class _LicenseGate extends ConsumerStatefulWidget {
  const _LicenseGate();

  @override
  ConsumerState<_LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends ConsumerState<_LicenseGate> {
  bool _animationDone = false;
  bool _licenseReady = false;
  Object? _licenseData; // LicenseModel türünde tut

  @override
  Widget build(BuildContext context) {
    final license = ref.watch(licenseProvider);

    license.whenData((lic) {
      if (!_licenseReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            setState(() {
              _licenseReady = true;
              _licenseData = lic;
            });
        });
      }
    });

    // İkisi de hazırsa geçiş yap
    if (_animationDone && _licenseReady) {
      return _buildDestination(_licenseData);
    }

    // Henüz geçiş yok — splash oynasın
    return SplashScreen(
      key: const ValueKey('license_splash'),
      onComplete: () {
        if (mounted) setState(() => _animationDone = true);
      },
    );
  }

  Widget _buildDestination(dynamic lic) {
    if (lic.isLocked || (lic.isTrial && (lic.trialDaysLeft ?? 0) < 0)) {
      return LockedScreen(daysOverdue: lic.trialDaysLeft?.abs());
    }
    return const HomePage();
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
