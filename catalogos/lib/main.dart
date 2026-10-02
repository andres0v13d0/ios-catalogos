import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/env/environment.dart';
import 'core/storage/storage.dart';
import 'firebase_options.dart';

/// Bootstrap de la app de Revendedores.
///
/// Fase 0:
/// - 0.1: pantalla placeholder.
/// - 0.2: resuelve el entorno (flavor) desde `--dart-define-from-file` y
///   registra en logs la `apiBaseUrl` activa para que dev vs prod sea visible.
/// - 0.5: envuelve la app en un [ProviderScope] (Riverpod) para alimentar el
///   router (go_router) y el estado de auth placeholder.
/// - 0.6: inicializa la caché local (Hive) para lectura offline. La caché de
///   catálogos (stale-while-revalidate) se construye en la tarea 1.18.
/// - 0.7: inicializa `firebase_core` con las opciones generadas por FlutterFire
///   (`firebase_options.dart`), para android/web. En entornos donde la
///   configuración nativa de Firebase no está disponible (p. ej. el escritorio
///   Linux —no soportado por `firebase_options.dart`, lanza `UnsupportedError`—,
///   o un flavor distinto de `dev` sin `google-services.json`) la inicialización
///   se protege con try/catch para que Fase 0 siga arrancando "sin Firebase
///   configurado", tal como fue diseñado.
///
/// IMPORTANTE: a partir de la Fase 1 (autenticación OTP) una inicialización
/// EXITOSA de Firebase es OBLIGATORIA; el catch tolerante de abajo es solo un
/// andamiaje de Fase 0 para desarrollo/placeholder y deberá dejar de ser
/// opcional cuando se integre `firebase_auth`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log del entorno activo al arrancar (CA tarea 0.2).
  Environment.current.logStartup();

  // Inicializa Firebase antes de runApp (tarea 0.7). Tolerante a fallos solo
  // durante Fase 0: en Linux desktop `DefaultFirebaseOptions.currentPlatform`
  // lanza UnsupportedError, y en flavors sin `google-services.json` la init
  // nativa puede fallar. En ambos casos la app continúa sin Firebase.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    // Fase 1 (auth) requerirá que esta init tenga éxito; aquí solo avisamos.
    debugPrint(
      '[bootstrap] Firebase no se pudo inicializar; la app continúa sin '
      'Firebase (esto es esperado fuera de android/web en Fase 0). '
      'Detalle: $error',
    );
    debugPrintStack(stackTrace: stackTrace);
  }

  // Inicializa la capa de caché local (tarea 0.6). Deja una caja abierta y
  // lista; las features la obtienen vía sus propios providers más adelante.
  await initLocalCache();

  runApp(const ProviderScope(child: RevendedoresApp()));
}
