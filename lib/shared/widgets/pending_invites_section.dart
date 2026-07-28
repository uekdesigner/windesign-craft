// lib/shared/widgets/pending_invites_section.dart
//
// Kullanıcının kendi e-postasına gelen bekleyen kurumsal davetlerini
// gösterir ve "Katıl" ile kabul etmesini sağlar.
//
// Hem Ayarlar > Lisans sekmesinde hem de LockedScreen'de kullanılır.
// LockedScreen'de kullanılması özellikle önemli: bir çalışan ekipten
// çıkarılıp kilitlendiğinde, tekrar davet edilirse bu daveti görüp kabul
// edebileceği TEK yer burasıdır (kilitli ekrandan Ayarlar'a gidiş yolu yoktur).

import 'package:flutter/material.dart';
import '../../services/license_service.dart';

class PendingInvitesSection extends StatefulWidget {
  final VoidCallback onJoined;

  const PendingInvitesSection({super.key, required this.onJoined});

  @override
  State<PendingInvitesSection> createState() => _PendingInvitesSectionState();
}

class _PendingInvitesSectionState extends State<PendingInvitesSection> {
  late Future<List<Map<String, dynamic>>> _invitesFuture;
  String? _joiningOrgId;

  @override
  void initState() {
    super.initState();
    _invitesFuture = LicenseService().findMyInvites();
  }

  Future<void> _join(String orgId) async {
    setState(() => _joiningOrgId = orgId);
    try {
      await LicenseService().acceptInvite(orgId: orgId);
      if (!mounted) return;
      widget.onJoined();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ekibe katıldınız! 🎉')));
      // Bu widget Ayarlar gibi Navigator.push ile açılmış bir sayfanın
      // içindeyse, kök route'a dönmezsek kullanıcı ana ekrana geçtiğini
      // görmez (LockedScreen'de zaten kök route olduğu için bu no-op'tur).
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on LicenseDeniedException catch (e) {
      if (!mounted) return;
      final message = switch (e.reason) {
        'seats_full' => 'Koltuk sınırına ulaşıldı, firma sahibine ulaşın.',
        'no_pending_invite' => 'Bu davet artık geçerli değil.',
        _ => 'Katılınamadı: ${e.reason}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _joiningOrgId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _invitesFuture,
      builder: (context, snapshot) {
        final invites = snapshot.data;
        if (invites == null || invites.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: invites.map((invite) {
              final orgId = invite['orgId'] as String;
              final orgName = invite['orgName'] as String? ?? 'Bir firma';
              final isJoining = _joiningOrgId == orgId;

              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline, color: Colors.indigo.shade600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$orgName sizi kurumsal lisansa davet etti.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: isJoining ? null : () => _join(orgId),
                      child: isJoining
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Katıl'),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
