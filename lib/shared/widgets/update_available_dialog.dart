// lib/shared/widgets/update_available_dialog.dart
//
// latestBuildNumber'dan eski ama minSupportedBuildNumber'ın üstündeki
// sürümlerde gösterilir. "Daha Sonra" ile kapatılabilir, zorlama yok.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/app_version_config.dart';

class UpdateAvailableDialog extends StatelessWidget {
  final AppVersionConfig config;

  const UpdateAvailableDialog({super.key, required this.config});

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Yeni Sürüm Mevcut'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Daha iyi bir deneyim için uygulamayı güncellemenizi öneririz.',
            ),
            if (config.changelogTr.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(config.changelogTr, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Daha Sonra'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (config.playStoreUrl.isNotEmpty) {
              _openUrl(config.playStoreUrl);
            } else if (config.manualApkUrl.isNotEmpty) {
              _openUrl(config.manualApkUrl);
            }
          },
          child: const Text('Güncelle'),
        ),
      ],
    );
  }
}
