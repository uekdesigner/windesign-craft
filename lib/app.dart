import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/app_theme.dart';

import 'shared/widgets/version_gate.dart';

class WinDesignApp extends StatelessWidget {
  const WinDesignApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Edge-to-edge modunu aktif et (Android 15+ zorunlu davranışıyla uyumlu)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Status bar ve nav bar İKİSİ DE transparent olmalı (Android 15+ deprecated API uyarısı için)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor:
            Colors.transparent, // ⬅️ değişti: opak renk kaldırıldı
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced:
            false, // ⬅️ eklendi: Android'in otomatik scrim eklemesini engeller
      ),
    );

    return MaterialApp(
      title: 'WinDesign_Craft Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const VersionGate(),
    );
  }
}
