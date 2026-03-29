// lib/core/utils/result.dart
import 'package:opnwndw/core/errors/app_exceptions.dart';

sealed class Result<T, E extends AppException> {
  const Result();

  factory Result.success(T value) = Success<T, E>;
  factory Result.failure(E error) = Failure<T, E>;

  bool get isSuccess => this is Success<T, E>;
  bool get isFailure => this is Failure<T, E>;

  T get dataOrThrow {
    return switch (this) {
      Success(value: final value) => value,
      Failure(error: final error) => throw error,
    };
  }

  E? get errorOrNull {
    return switch (this) {
      Success() => null,
      Failure(error: final error) => error,
    };
  }

  Result<U, E> map<U>(U Function(T) transform) {
    return switch (this) {
      Success(value: final value) => Result<U, E>.success(transform(value)),
      Failure(error: final error) => Result<U, E>.failure(error),
    };
  }

  Result<T, E> onSuccess(void Function(T) action) {
    if (this case Success(value: final value)) {
      action(value);
    }
    return this;
  }

  Result<T, E> onFailure(void Function(E) action) {
    if (this case Failure(error: final error)) {
      action(error);
    }
    return this;
  }

  // 🚨 YENİ: Fold metodu eklendi
  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(E) onFailure,
  }) {
    return switch (this) {
      Success(value: final value) => onSuccess(value),
      Failure(error: final error) => onFailure(error),
    };
  }
}

class Success<T, E extends AppException> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

class Failure<T, E extends AppException> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}

// result.dart - en alta ekle:

// 🚨 YENİ: Result sınıfına fold metodu ekleyelim
extension ResultExtensions<T, E extends AppException> on Result<T, E> {
  R fold<R>({
    required R Function(T) onSuccess,
    required R Function(E) onFailure,
  }) {
    return switch (this) {
      Success(value: final value) => onSuccess(value),
      Failure(error: final error) => onFailure(error),
    };
  }
}
