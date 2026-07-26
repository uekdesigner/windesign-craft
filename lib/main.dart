import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'services/error_handler.dart';
import 'services/auth_service.dart';
import 'app.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // await GoogleSignIn.instance.initialize(
      //   serverClientId:
      //       '744072834944-qmf68120ffqccopptrd1mpmt77rj9hs5.apps.googleusercontent.com',
      // );
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb
            ? '744072834944-qmf68120ffqccopptrd1mpmt77rj9hs5.apps.googleusercontent.com'
            : null,
        serverClientId: kIsWeb
            ? null
            : '744072834944-qmf68120ffqccopptrd1mpmt77rj9hs5.apps.googleusercontent.com',
      );
      //🚨 YENİ: giriş olaylarını dinlemeye başla
      AuthService().listenGoogleAuthEvents();

      _setupGlobalErrorHandling();
      runApp(const ProviderScope(child: WinDesignApp()));
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
  FlutterError.onError = (details) {
    ErrorHandlerService().handleError(
      error: details.exception,
      context: 'FLUTTER_ERROR',
      stackTrace: details.stack,
      showUserMessage: false,
    );
  };

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
