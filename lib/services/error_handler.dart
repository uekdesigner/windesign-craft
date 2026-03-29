// lib/core/services/error_handler_service.dart
import 'dart:developer';
import '../core/errors/app_exceptions.dart';

class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;

  ErrorHandlerService._internal();

  // 🚨 ERROR SEVIYELERI
  static const _levelDebug = '🐛 DEBUG';
  static const _levelInfo = 'ℹ️ INFO';
  static const _levelWarning = '⚠️ WARNING';
  static const _levelError = '❌ ERROR';
  static const _levelCritical = '💥 CRITICAL';

  // 🚨 HATA YAKALAMA
  void handleError({
    required dynamic error,
    required String context,
    StackTrace? stackTrace,
    bool showUserMessage = true,
  }) {
    final errorLevel = _getErrorLevel(error);

    // Loglama
    _logError(error, stackTrace, context, errorLevel);

    // Kullanıcı mesajı (isteğe bağlı)
    if (showUserMessage) {
      _showUserMessage(error, context);
    }

    // Analytics/Reporting (gelecekte eklenebilir)
    _reportError(error, stackTrace, context, errorLevel);
  }

  String _getErrorLevel(dynamic error) {
    if (error is DatabaseConstraintException) return _levelWarning;
    if (error is ValidationException) return _levelWarning;
    if (error is DatabaseNotFoundException) return _levelInfo;
    if (error is NetworkException) return _levelError;
    if (error is SerializationException) return _levelError;
    if (error is DatabaseException) return _levelError;
    if (error is UIException) return _levelWarning;
    if (error is AppException) return _levelError;
    return _levelCritical; // Beklenmeyen hatalar
  }

  void _logError(
    dynamic error,
    StackTrace? stackTrace,
    String context,
    String level,
  ) {
    final timestamp = DateTime.now().toIso8601String();

    log(
      '''
🧨 HATA YAKALANDI
├─ Seviye: $level
├─ Zaman: $timestamp
├─ Context: $context
├─ Hata: $error
└─ StackTrace: ${stackTrace ?? 'Yok'}
''',
      name: 'ErrorHandler',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _showUserMessage(dynamic error, String context) {
    final userMessage = _getUserFriendlyMessage(error, context);

    // 🚨 Burada bir snackbar veya dialog servisi kullanılabilir
    // Şimdilik sadece logluyoruz
    print('👤 Kullanıcı Mesajı: $userMessage');
  }

  String _getUserFriendlyMessage(dynamic error, String context) {
    if (error is DatabaseNotFoundException) {
      return 'İstenilen veri bulunamadı.';
    }
    if (error is DatabaseConstraintException) {
      return 'Bu işlem şu anda gerçekleştirilemiyor.';
    }
    if (error is ValidationException) {
      return 'Lütfen girdiğiniz bilgileri kontrol edin.';
    }
    if (error is NetworkException) {
      return 'İnternet bağlantısıyla ilgili bir sorun oluştu.';
    }
    if (error is SerializationException) {
      return 'Veri işleme sırasında bir hata oluştu.';
    }

    // Genel mesaj
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }

  void _reportError(
    dynamic error,
    StackTrace? stackTrace,
    String context,
    String level,
  ) {
    // 🚨 Gelecekte: Firebase Crashlytics, Sentry vb. entegrasyonu
    // Şimdilik sadece advanced logging
    if (level == _levelCritical || level == _levelError) {
      _logToFile(error, stackTrace, context);
    }
  }

  void _logToFile(dynamic error, StackTrace? stackTrace, String context) {
    // 🚨 Dosyaya loglama implementasyonu
    print('📁 Hata dosyaya kaydedildi: $context');
  }

  // 🚨 YARDIMCI METODLAR
  static bool isCriticalError(dynamic error) {
    return error is! ValidationException && error is! DatabaseNotFoundException;
  }

  static String getErrorCode(dynamic error) {
    if (error is DatabaseException) return 'DB_001';
    if (error is NetworkException) return 'NET_001';
    if (error is ValidationException) return 'VAL_001';
    if (error is SerializationException) return 'SER_001';
    return 'UNK_001';
  }
}
