import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/firebase_token_provider.dart';
import '../../features/auth/presentation/auth_state_provider.dart';
import 'app_check_token_source.dart';
import 'dio_client.dart';
import 'token_provider.dart';

/// Fuente del token de App Check para la app (tarea 1.11/1.12).
///
/// Por defecto usa la implementación real respaldada por `firebase_app_check`.
/// Los tests la sobreescriben con un fake (p. ej. [NoopAppCheckTokenSource])
/// para no tocar Firebase.
final Provider<AppCheckTokenSource> appCheckTokenSourceProvider =
    Provider<AppCheckTokenSource>(
  (Ref ref) => FirebaseAppCheckTokenSource(),
);

/// [TokenProvider] real de la app: deriva el `idToken` de Firebase a través del
/// [AuthUserService] (tarea 1.12). Reemplaza al `StaticTokenProvider`/en-memoria
/// de fases previas.
final Provider<TokenProvider> firebaseTokenProvider = Provider<TokenProvider>(
  (Ref ref) => FirebaseTokenProvider(ref.read(authUserServiceProvider)),
);

/// Provider del cliente [Dio] configurado para la app (tarea 1.12).
///
/// Construye `DioClient.create` con:
/// - el [TokenProvider] respaldado por Firebase (cabecera `Authorization`),
/// - la fuente de App Check,
/// - y la política "401 persistente → logout": al mapear un 401, el
///   `UnauthorizedInterceptor` invoca `authStateProvider.notifier.logout()`
///   (Firebase signOut + limpieza de storage), tras lo cual el router redirige
///   a `/login`. Se intenta UN refresco del token antes de cerrar sesión.
final Provider<Dio> dioProvider = Provider<Dio>((Ref ref) {
  final tokenProvider = ref.watch(firebaseTokenProvider);
  final appCheck = ref.watch(appCheckTokenSourceProvider);
  final authUserService = ref.watch(authUserServiceProvider);

  return DioClient.create(
    tokenProvider: tokenProvider,
    appCheckTokenSource: appCheck,
    // Intento único de refresco forzado antes de aplicar la política de logout.
    refreshToken: () => authUserService.getIdToken(forceRefresh: true),
    onUnauthorized: () => ref.read(authStateProvider.notifier).logout(),
  );
});
