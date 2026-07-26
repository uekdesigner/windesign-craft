import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/license_service.dart';

class TeamManagementScreen extends StatefulWidget {
  final String orgId;

  const TeamManagementScreen({super.key, required this.orgId});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  final _emailController = TextEditingController();
  bool _isInviting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir e-posta girin.')),
      );
      return;
    }

    setState(() => _isInviting = true);
    try {
      await LicenseService().inviteEmployee(
        orgId: widget.orgId,
        employeeEmail: email,
      );
      if (!mounted) return;
      _emailController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$email davet edildi.')));
    } on LicenseDeniedException catch (e) {
      if (!mounted) return;
      final message = switch (e.reason) {
        'seats_full' =>
          'Koltuk sınırına ulaşıldı. Daha fazla çalışan eklemek için lisansınızı yükseltin.',
        'already_invited' => 'Bu kişi zaten davet edilmiş.',
        'not_org_owner' => 'Bu işlemi yalnızca firma sahibi yapabilir.',
        _ => 'Davet gönderilemedi: ${e.reason}',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bir hata oluştu. Tekrar deneyin.')),
      );
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _removeMember(String uid, String email) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Çalışanı Çıkar'),
        content: Text(
          '$email adresli kullanıcıyı ekipten çıkarmak istediğinize emin misiniz? '
          'Bu kullanıcı anında uygulamadan çıkarılacak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await LicenseService().removeEmployee(
        orgId: widget.orgId,
        employeeUid: uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$email ekipten çıkarıldı.')));
    } on LicenseDeniedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Çıkarılamadı: ${e.reason}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Ekibim')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('organizations')
            .doc(widget.orgId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Organizasyon bulunamadı.'));
          }

          final data = snapshot.data!.data()!;
          final orgName = data['name'] as String? ?? '';
          final seats = (data['seats'] as num?)?.toInt() ?? 0;
          final seatsUsed = (data['seatsUsed'] as num?)?.toInt() ?? 0;
          final members = Map<String, dynamic>.from(
            data['members'] as Map? ?? {},
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.apartment,
                      color: Colors.indigo.shade600,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            orgName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$seatsUsed / $seats koltuk kullanılıyor',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ÇALIŞAN DAVET ET',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: 'calisan@ornek.com',
                        prefixIcon: const Icon(Icons.mail_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: (_isInviting || seatsUsed >= seats)
                        ? null
                        : _invite,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    child: _isInviting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
              if (seatsUsed >= seats) ...[
                const SizedBox(height: 8),
                Text(
                  'Koltuk sınırına ulaşıldı.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'EKİP ÜYELERİ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              ...members.entries.map((entry) {
                final uid = entry.key;
                final member = Map<String, dynamic>.from(entry.value as Map);
                final email = member['email'] as String? ?? '';
                final role = member['role'] as String? ?? 'member';
                final isOwner = role == 'owner';
                final isMe = uid == myUid;

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isOwner
                          ? Colors.indigo.shade100
                          : Colors.grey.shade200,
                      child: Icon(
                        isOwner ? Icons.star : Icons.person,
                        color: isOwner
                            ? Colors.indigo.shade600
                            : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                    title: Text(email + (isMe ? ' (Siz)' : '')),
                    subtitle: Text(isOwner ? 'Firma Sahibi' : 'Çalışan'),
                    trailing: (isOwner || isMe)
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: Colors.red.shade400,
                            ),
                            onPressed: () => _removeMember(uid, email),
                          ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
