import 'package:dio/dio.dart';

/// Interceptor de App Check de Firebase.
///
/// STUB temporal (tarea 0.4): por ahora adjunta una cabecera placeholder y
/// no integra Firebase App Check real.
///
/// TODO(tarea 1.11): reemplazar por la obtención del token de App Check real
/// (Play Integrity en Android / DeviceCheck · App Attest en iOS) vía
/// `firebase_app_check`, y adjuntarlo solo en los endpoints protegidos
/// (ver diseño §2.4 "AppCheckInterceptor" y §7 "App Check").
class AppCheckInterceptor extends Interceptor {
  AppCheckInterceptor();

  /// Nombre de la cabecera de App Check usada por el backend.
  static const String appCheckHeader = 'X-Firebase-AppCheck';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // STUB: no se adjunta un token real todavía. Se deja la cabecera marcada
    // para que sea evidente en logs/depuración que App Check aún no está
    // integrado. No bloquea ninguna petición.
    options.headers[appCheckHeader] = 'stub';
    handler.next(options);
  }
}
