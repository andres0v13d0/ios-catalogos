import 'package:firebase_app_check/firebase_app_check.dart';

/// Fuente del token de App Check para la capa de red (tarea 1.11).
///
/// El [AppCheckInterceptor] depende de esta interfaz (no de Firebase
/// directamente) para poder:
/// - usar la implementación real respaldada por `firebase_app_check`
///   ([FirebaseAppCheckTokenSource]) en la app, y
/// - inyectar un fake en tests (sin tocar Firebase).
///
/// Contrato: [getToken] devuelve el token actual, `null` si no hay token
/// disponible, o LANZA si falla la obtención. El interceptor es resiliente a
/// ambos casos (continúa sin la cabecera y registra una advertencia).
abstract interface class AppCheckTokenSource {
  Future<String?> getToken();
}

/// Fuente de token inerte: siempre devuelve `null`.
///
/// Útil como valor por defecto cuando App Check no está activado (p. ej. en
/// tests o en bootstrap antes de resolver la fuente real), de modo que el
/// interceptor simplemente omita la cabecera.
class NoopAppCheckTokenSource implements AppCheckTokenSource {
  const NoopAppCheckTokenSource();

  @override
  Future<String?> getToken() async => null;
}

/// Implementación de [AppCheckTokenSource] respaldada por `firebase_app_check`.
class FirebaseAppCheckTokenSource implements AppCheckTokenSource {
  FirebaseAppCheckTokenSource({FirebaseAppCheck? appCheck})
      : _appCheck = appCheck ?? FirebaseAppCheck.instance;

  final FirebaseAppCheck _appCheck;

  @override
  Future<String?> getToken() => _appCheck.getToken();
}
