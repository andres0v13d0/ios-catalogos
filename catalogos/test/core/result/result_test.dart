// Tests de los tipos Result<T>/Failure (tarea 0.4, diseño §2.4/§2.6).

import 'package:catalogos/core/result/failure.dart';
import 'package:catalogos/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Ok expone el valor y marca isOk', () {
      const Result<int> r = Ok(42);
      expect(r.isOk, isTrue);
      expect(r.isErr, isFalse);
      expect(r.valueOrNull, 42);
      expect(r.failureOrNull, isNull);
    });

    test('Err expone el fallo y marca isErr', () {
      const failure = UnauthorizedFailure();
      const Result<int> r = Err(failure);
      expect(r.isErr, isTrue);
      expect(r.isOk, isFalse);
      expect(r.valueOrNull, isNull);
      expect(r.failureOrNull, same(failure));
    });

    test('map transforma el Ok y preserva el Err', () {
      const Result<int> ok = Ok(2);
      expect(ok.map((v) => v * 10).valueOrNull, 20);

      const Result<int> err = Err(NetworkFailure());
      final mapped = err.map((v) => v * 10);
      expect(mapped.isErr, isTrue);
    });

    test('fold colapsa ambos casos', () {
      const Result<int> ok = Ok(5);
      expect(ok.fold((v) => 'v=$v', (f) => 'err'), 'v=5');

      const Result<int> err = Err(ServerFailure(statusCode: 500));
      expect(err.fold((v) => 'v', (f) => 'err=${f.statusCode}'), 'err=500');
    });
  });

  group('Failure', () {
    test('UnauthorizedFailure fija statusCode 401', () {
      expect(const UnauthorizedFailure().statusCode, 401);
    });

    test('RateLimitFailure fija statusCode 429', () {
      expect(const RateLimitFailure().statusCode, 429);
    });
  });
}
