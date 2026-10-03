import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'env/environment.dart';

/// Resultado del arranque de Firebase (tarea 1.11 + endurecimiento de init).
///
/// [ok] indica si tanto `Firebase.initializeApp` como la activación de App
/// Check tuvieron éxito. Si falla, [error] contiene el detalle para mostrarlo
/// en la pantalla de error en plataformas soportadas (android/web).
class BootstrapResult {
  const BootstrapResult({required this.ok, this.error});

  final bool ok;
  final Object? error;

  static const BootstrapResult success = BootstrapResult(ok: true);
}

/// `true` si estamos en una plataforma donde Firebase es OBLIGATORIO
/// (android/web). En Linux/escritorio no soportado toleramos el fallo porque
/// esos targets no se publican.
bool get isFirebaseRequiredPlatform {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// Inicializa Firebase y activa App Check.
///
/// Devuelve [BootstrapResult.success] si todo salió bien. Si falla:
/// - en plataformas donde Firebase es obligatorio (android/web) devuelve un
///   resultado con `ok=false` y el error, para que `main` muestre una pantalla
///   de error clara en lugar de continuar en silencio;
/// - en plataformas no soportadas (Linux/escritorio) devuelve `ok=true` para
///   seguir arrancando (andamiaje de desarrollo), registrando una advertencia.
Future<BootstrapResult> bootstrapFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _activateAppCheck();
    return BootstrapResult.success;
  } catch (error, stackTrace) {
    if (isFirebaseRequiredPlatform) {
      // En android/web NO continuamos en silencio: el llamador mostrará la
      // pantalla de error.
      debugPrint('[bootstrap] Firebase/App Check falló en una plataforma '
          'soportada: $error');
      debugPrintStack(stackTrace: stackTrace);
      return BootstrapResult(ok: false, error: error);
    }
    // Plataforma no soportada (p. ej. Linux desktop): tolerar y continuar.
    debugPrint(
      '[bootstrap] Firebase no disponible en esta plataforma '
      '(${kIsWeb ? "web" : defaultTargetPlatform.name}); la app continúa sin '
      'Firebase. Detalle: $error',
    );
    return BootstrapResult.success;
  }
}

/// Activa App Check tras `Firebase.initializeApp` (tarea 1.11).
///
/// - En DEV usa proveedores DEBUG (Android `debug`, Apple `debug`, web
///   `ReCaptchaV3` no es necesario en dev → se usa `debug` en móvil y en web
///   solo se activa debug si procede).
/// - En STAGING/PROD usa Play Integrity (Android) y App Attest (iOS/macOS).
///
/// La activación se gatea por [Environment.flavor].
Future<void> _activateAppCheck() async {
  final bool isDev = Environment.current.isDev;

  if (kIsWeb) {
    // En web App Check usa reCAPTCHA; en dev se omite la activación para no
    // requerir una site key. En prod/staging se debe proveer la site key real
    // (pendiente de configuración del proyecto). Se deja sin activar aquí para
    // no romper el arranque web durante el desarrollo.
    if (isDev) return;
    // TODO(1.11): activar ReCaptchaV3 con la site key real en staging/prod web.
    return;
  }

  await FirebaseAppCheck.instance.activate(
    providerAndroid: isDev
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple:
        isDev ? const AppleDebugProvider() : const AppleAppAttestProvider(),
  );
}
