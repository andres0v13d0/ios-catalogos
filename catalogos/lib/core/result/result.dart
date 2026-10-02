import 'failure.dart';

/// Tipo `Result<T>` (estilo Either) para la capa de datos.
///
/// Ver diseño §2.4 y §2.6: los repos devuelven `Result<T>` en lugar de lanzar
/// excepciones; la UI (vía Riverpod `AsyncValue`) consume el éxito [Ok] o el
/// fallo [Err].
///
/// Es `sealed`, por lo que un `switch` sobre un [Result] obliga a manejar
/// ambos casos de forma exhaustiva.
sealed class Result<T> {
  const Result();

  /// Crea un resultado exitoso.
  const factory Result.ok(T value) = Ok<T>;

  /// Crea un resultado fallido.
  const factory Result.err(Failure failure) = Err<T>;

  /// `true` si el resultado es [Ok].
  bool get isOk => this is Ok<T>;

  /// `true` si el resultado es [Err].
  bool get isErr => this is Err<T>;

  /// Valor en caso de éxito o `null` si es un fallo.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// Fallo en caso de error o `null` si es un éxito.
  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  /// Transforma el valor de éxito preservando el fallo.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final value) => Ok<R>(transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };

  /// Colapsa el resultado a un único valor manejando ambos casos.
  R fold<R>(
    R Function(T value) onOk,
    R Function(Failure failure) onErr,
  ) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };
}

/// Rama de éxito de un [Result].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  String toString() => 'Ok($value)';
}

/// Rama de fallo de un [Result].
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  String toString() => 'Err($failure)';
}
