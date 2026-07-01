// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config/app_theme.dart';

import 'shared/widgets/root_gate.dart';

class WinDesignApp extends StatelessWidget {
  const WinDesignApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Status bar stilini ayarla (Win11 tarzı: dark iconlar, light arka plan)
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFFF9F9F9),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'WinDesign_Craft Pro',
      debugShowCheckedModeBanner: false,

      // Sadece Light tema - Dark kaldırıldı
      theme: AppTheme.light,
      // darkTheme: AppTheme.dark,  // 🗑️ SİLİNDİ

      // Zaten light mode kullanıyordunuz
      themeMode: ThemeMode.light,

      home: const RootGate(),
    );
  }
}
