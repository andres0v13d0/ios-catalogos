import 'package:flutter/foundation.dart';

/// Entornos (flavors) soportados por la app.
///
/// Se corresponden con los product flavors de Android y los schemes/xcconfig
/// de iOS, así como con los archivos `env/dev.json`, `env/staging.json` y
/// `env/prod.json` consumidos vía `--dart-define-from-file`.
enum Flavor { dev, staging, prod }

/// Configuración por entorno de la app de Revendedores.
///
/// Los valores se inyectan en tiempo de compilación mediante
/// `--dart-define-from-file=env/<flavor>.json`. Nunca se commitean secretos:
/// los archivos `env/*.json` contienen solo configuración no sensible
/// (p. ej. `apiBaseUrl`, nombre, flags). Las credenciales reales (Firebase,
/// etc.) se referencian por flavor y se gestionan fuera del repositorio.
///
/// Ver diseño §2.7 "Configuración por entornos".
class Environment {
  const Environment._({
    required this.flavor,
    required this.appName,
    required this.apiBaseUrl,
    required this.firebaseOptions,
    required this.enableLogging,
  });

  /// Flavor activo resuelto desde el dart-define `flavor`.
  final Flavor flavor;

  /// Nombre visible de la app para este entorno.
  final String appName;

  /// URL base del backend para este entorno.
  final String apiBaseUrl;

  /// Referencia al conjunto de `firebase_options` por flavor (no es un secreto;
  /// solo un identificador que se resuelve al archivo generado por FlutterFire).
  final String firebaseOptions;

  /// Si se habilitan logs verbosos (true en dev/staging, false en prod).
  final bool enableLogging;

  /// Valores inyectados por `--dart-define-from-file`.
  static const String _flavorRaw =
      String.fromEnvironment('flavor', defaultValue: 'dev');
  static const String _appName =
      String.fromEnvironment('appName', defaultValue: 'Revendedores Dev');
  // Fallback LOCAL para desarrollo: `10.0.2.2` es el alias del emulador de
  // Android hacia el `localhost` de la máquina anfitriona (el PC donde corre
  // el backend en el puerto 3000). No apuntamos a `dev-api.minymol.com` porque
  // ese host puede no existir y el objetivo es desarrollar contra el backend
  // local.
  //
  // Overrides:
  // - `--dart-define-from-file=env/dev.json` (fuente preferida; ver env/*.json).
  // - `--dart-define=apiBaseUrl=...` (puntual).
  // En un DISPOSITIVO físico el emulador no aplica: usar la IP LAN del PC, p.
  // ej. `--dart-define=apiBaseUrl=http://192.168.1.50:3000` (reemplazar por la
  // IP real del PC en la red local, <PC_LAN_IP>).
  //
  // staging/prod NO cambian: sus URLs se inyectan vía env/staging.json y
  // env/prod.json y nunca dependen de este fallback.
  static const String _apiBaseUrl = String.fromEnvironment(
    'apiBaseUrl',
    defaultValue: 'http://10.0.2.2:3000',
  );
  static const String _firebaseOptions =
      String.fromEnvironment('firebaseOptions', defaultValue: 'dev');
  static const bool _enableLogging =
      bool.fromEnvironment('enableLogging', defaultValue: true);

  /// Instancia única del entorno actual, construida a partir de los
  /// dart-define disponibles en tiempo de compilación.
  static final Environment current = Environment._(
    flavor: _parseFlavor(_flavorRaw),
    appName: _appName,
    apiBaseUrl: _apiBaseUrl,
    firebaseOptions: _firebaseOptions,
    enableLogging: _enableLogging,
  );

  bool get isDev => flavor == Flavor.dev;
  bool get isStaging => flavor == Flavor.staging;
  bool get isProd => flavor == Flavor.prod;

  static Flavor _parseFlavor(String value) {
    switch (value.toLowerCase()) {
      case 'prod':
      case 'production':
        return Flavor.prod;
      case 'staging':
        return Flavor.staging;
      case 'dev':
      case 'development':
      default:
        return Flavor.dev;
    }
  }

  /// Imprime en logs el entorno activo al arrancar la app, de modo que dev vs
  /// prod sea visible (criterio de aceptación de la tarea 0.2).
  void logStartup() {
    debugPrint(
      '[Environment] flavor=${flavor.name} '
      'apiBaseUrl=$apiBaseUrl '
      'appName=$appName '
      'firebaseOptions=$firebaseOptions',
    );
  }

  @override
  String toString() =>
      'Environment(flavor: ${flavor.name}, apiBaseUrl: $apiBaseUrl)';
}
