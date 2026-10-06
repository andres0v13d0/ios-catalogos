import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/env/environment.dart';
import 'app/error_app.dart';
import 'core/storage/storage.dart';
import 'features/auth/presentation/auth_state_provider.dart';
import 'features/profile/presentation/profile_controller.dart';

/// Bootstrap de la app de Revendedores.
///
/// Fase 0:
/// - 0.1: pantalla placeholder.
/// - 0.2: resuelve el entorno (flavor) desde `--dart-define-from-file` y
///   registra en logs la `apiBaseUrl` activa.
/// - 0.5: envuelve la app en un [ProviderScope] (Riverpod).
/// - 0.6: inicializa la caché local (Hive).
/// - 0.7: inicializa `firebase_core`.
///
/// Fase 1 (endurecimiento, tareas 1.9–1.11): la inicialización de Firebase +
/// App Check es OBLIGATORIA en plataformas soportadas (android/web). Si falla,
/// NO continuamos en silencio: mostramos una [ErrorApp] con el detalle del
/// error. En plataformas no soportadas (Linux/escritorio, que no se publican)
/// toleramos el fallo y arrancamos igualmente (ver [bootstrapFirebase]).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Caché de imágenes EN MEMORIA acotada (tarea de rendimiento): el default
  // de Flutter es 100MB / 1000 imágenes decodificadas, demasiado para los
  // celulares de gama baja que usan los revendedores (p. ej. el Xiaomi
  // Redmi 9 de prueba). Con las imágenes de producto ya decodificadas al
  // tamaño de pantalla (`memCacheWidth`/`memCacheHeight`, ver
  // `ProductGridCard`), 40MB / 200 imágenes alcanza de sobra para varias
  // pantallas de cuadrícula sin arriesgar un OOM en segundo plano.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 40 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 200;

  // Log del entorno activo al arrancar (CA tarea 0.2).
  Environment.current.logStartup();

  // Inicializa Firebase + App Check (tareas 0.7 y 1.11). En android/web un
  // fallo deja `ok=false`; en plataformas no soportadas devuelve `ok=true`.
  final BootstrapResult bootstrap = await bootstrapFirebase();

  if (!bootstrap.ok) {
    // Plataforma soportada con init fallida: mostrar pantalla de error clara.
    runApp(ErrorApp(error: bootstrap.error ?? 'Error desconocido'));
    return;
  }

  // Inicializa la capa de caché local (tarea 0.6). La instancia se inyecta en
  // Riverpod vía `localCacheProvider` para que la caché offline de catálogos
  // compartidos (tarea 1.15) la consuma.
  final LocalCache localCache = await initLocalCache();

  // Tarea 1.12 — restauración de sesión al arrancar:
  // creamos el contenedor de Riverpod y, si `firebase_auth` tiene un usuario
  // persistido, restauramos `AuthStatus.signedIn` ANTES de montar la UI, para
  // que el router no rebote a `/login` tras un reinicio.
  final ProviderContainer container = ProviderContainer(
    overrides: [
      localCacheProvider.overrideWithValue(localCache),
    ],
  );
  await container.read(authStateProvider.notifier).restoreSession();

  // Si hay sesión restaurada, carga el perfil (`GET /reseller/me`) para que el
  // guard de "perfil incompleto" (tarea 1.13) esté resuelto al montar la UI.
  // No bloqueamos el arranque: se dispara en segundo plano.
  if (container.read(authStateProvider) == AuthStatus.signedIn) {
    unawaited(
      container.read(profileControllerProvider.notifier).loadProfile(),
    );
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const RevendedoresApp(),
    ),
  );
}
