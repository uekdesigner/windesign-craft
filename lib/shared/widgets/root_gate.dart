// lib/shared/widgets/root_gate.dart
//
// Uygulamanın ilk karar noktası: onboarding gösterildi mi?
// app.dart içinde:  home: const RootGate(),
//
// - onboarding_completed == true  -> AuthGate (oturum + lisans + logo splash)
// - aksi halde                    -> OnboardingScreen
//
// Pref okunması neredeyse anlıktır; o kısa an için animasyonsuz marka mavisi
// gösterilir (beyaz flaş ve gereksiz animasyon yeniden başlamasını önler).

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/onboarding_screen.dart';
import '../../screens/splash_screen.dart';
import 'auth_gate.dart';

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  late final Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _onboardingDone();
  }

  Future<bool> _onboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future, // sabit, bir kez oluşturuldu
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const ColoredBox(color: SplashScreen.brandBlue);
        }
        return snapshot.data! ? const AuthGate() : const OnboardingScreen();
      },
    );
  }
}
