import 'app_exception.dart';

/// Lightweight Result type so repositories can communicate failure
/// without throwing across layer boundaries.
///
/// Consumers can pattern-match with `switch`:
///
///   switch (result) {
///     case Success(:final value): ...
///     case Failure(:final error): ...
///   }
sealed class Result<T> {
  const Result();

  /// Convenience: fold into a single value.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(AppException error) onFailure,
  }) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        Failure<T>(:final error) => onFailure(error),
      };

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Failure<T> extends Result<T> {
  const Failure(this.error);
  final AppException error;
}
