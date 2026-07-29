// lib/shared/widgets/update_required_screen.dart
//
// minSupportedBuildNumber'ın altındaki sürümlerde gösterilir.
// KAPATILAMAZ — geri tuşu, dışarı tıklama vb. hiçbir yolla atlanamaz.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_version_config.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final AppVersionConfig config;

  const UpdateRequiredScreen({super.key, required this.config});

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // geri tuşuyla kapatılamaz
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.system_update_rounded,
                    size: 80,
                    color: Colors.red.shade600,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Güncelleme Gerekli',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kullandığınız sürüm artık desteklenmiyor. Devam etmek '
                    'için uygulamayı güncellemeniz gerekiyor.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  if (config.changelogTr.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        config.changelogTr,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (config.playStoreUrl.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openUrl(config.playStoreUrl),
                        icon: const Icon(Icons.shop),
                        label: const Text("Play Store'dan Güncelle"),
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
                  if (config.manualApkUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openUrl(config.manualApkUrl),
                        icon: const Icon(Icons.download),
                        label: const Text('APK Dosyasını İndir'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
