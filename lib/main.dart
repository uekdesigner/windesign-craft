// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'app_theme.dart';
import 'features/home/home_page.dart';
import 'services/error_handler.dart';

void main() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // 🚨 GLOBAL ERROR HANDLING
      _setupGlobalErrorHandling();

      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stackTrace) {
      ErrorHandlerService().handleError(
        error: error,
        context: 'ZONE_ERROR',
        stackTrace: stackTrace,
        showUserMessage: false,
      );
    },
  );
}

void _setupGlobalErrorHandling() {
  // Flutter framework hataları
  FlutterError.onError = (details) {
    ErrorHandlerService().handleError(
      error: details.exception,
      context: 'FLUTTER_ERROR',
      stackTrace: details.stack,
      showUserMessage: false,
    );
  };

  // Platform hataları
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    ErrorHandlerService().handleError(
      error: error,
      context: 'PLATFORM_ERROR',
      stackTrace: stackTrace,
      showUserMessage: false,
    );
    return true;
  };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WinDesign_Craft Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      home: const HomePage(),
    );
  }
}
