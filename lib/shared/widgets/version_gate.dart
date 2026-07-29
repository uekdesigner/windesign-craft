// lib/shared/widgets/version_gate.dart
//
// Uygulamanın EN DIŞ karar noktası — RootGate'ten (onboarding/auth/lisans)
// bile önce çalışır. app.dart içinde:  home: const VersionGate(),
//
// - Sürüm çok eskiyse (minSupportedBuildNumber altı) -> UpdateRequiredScreen
//   (bloklayıcı, oturum açma dahil hiçbir şeye erişilemez)
// - Daha yeni bir sürüm varsa (ama zorunlu değilse) -> normal akışa devam
//   eder, üstüne kapatılabilir "Yeni Sürüm Mevcut" diyaloğu açılır.
// - Kontrol başarısız olursa (ağ yok, doküman yok vb.) -> kullanıcı ASLA
//   bloklanmaz, normal akışa devam eder.

import 'package:flutter/material.dart';
import '../../services/version_check_service.dart';
import 'root_gate.dart';
import 'update_required_screen.dart';
import 'update_available_dialog.dart';

class VersionGate extends StatefulWidget {
  const VersionGate({super.key});

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  late final Future<VersionCheckResult> _future;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    _future = VersionCheckService().check();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VersionCheckResult>(
      future: _future,
      builder: (context, snapshot) {
        // Kontrol daha sonuçlanmadıysa RootGate zaten kendi splash'ini
        // gösterecek şekilde tasarlı değil, o yüzden burada da marka
        // rengiyle kısa bir bekleme ekranı gösteriyoruz.
        if (!snapshot.hasData) {
          return const ColoredBox(color: Color(0xFF1565C0));
        }

        final result = snapshot.data!;

        if (result.urgency == UpdateUrgency.required && result.config != null) {
          return UpdateRequiredScreen(config: result.config!);
        }

        if (result.urgency == UpdateUrgency.optional &&
            result.config != null &&
            !_dialogShown) {
          _dialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (_) => UpdateAvailableDialog(config: result.config!),
            );
          });
        }

        return const RootGate();
      },
    );
  }
}
