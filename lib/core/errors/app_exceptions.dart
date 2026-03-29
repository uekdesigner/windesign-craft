// lib/core/errors/app_exceptions.dart

abstract class AppException implements Exception {
  final String message;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  AppException(this.message, [this.stackTrace]) : timestamp = DateTime.now();

  @override
  String toString() => '[$runtimeType] $message';
}

// Veritabanı Hataları
class DatabaseException extends AppException {
  DatabaseException(super.message, [super.stackTrace]);
}

class DatabaseNotFoundException extends DatabaseException {
  DatabaseNotFoundException(super.message, [super.stackTrace]);
}

class DatabaseConstraintException extends DatabaseException {
  DatabaseConstraintException(super.message, [super.stackTrace]);
}

// Ağ Hataları
class NetworkException extends AppException {
  NetworkException(super.message, [super.stackTrace]);
}

// Validation Hataları
class ValidationException extends AppException {
  ValidationException(super.message, [super.stackTrace]);
}

// Serialization Hataları
class SerializationException extends AppException {
  SerializationException(super.message, [super.stackTrace]);
}

// UI Hataları
class UIException extends AppException {
  UIException(super.message, [super.stackTrace]);
}
