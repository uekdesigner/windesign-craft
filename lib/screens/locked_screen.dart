import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/license_provider.dart';
import '../services/auth_service.dart';
import '../shared/widgets/pending_invites_section.dart';
import 'redeem_key_screen.dart';

class LockedScreen extends ConsumerWidget {
  final int? daysOverdue; // süre kaç gün önce doldu (opsiyonel)

  const LockedScreen({super.key, this.daysOverdue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Deneme Süreniz Doldu',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'WinDesign Craft Pro\'yu kullanmaya devam etmek için lisans satın alın.',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RedeemKeyScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart),
                    label: const Text('Lisans Satın Al'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                // 🆕 Bir firma tarafından kurumsal lisansa (tekrar) davet
                // edilmiş olabilir — bu davet burada gösterilmezse, kilitli
                // bir kullanıcının daveti kabul edebileceği başka hiçbir
                // ekran yok.
                PendingInvitesSection(
                  onJoined: () => ref.invalidate(licenseProvider),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await AuthService().signOut();
                  },
                  child: const Text('Çıkış Yap'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
