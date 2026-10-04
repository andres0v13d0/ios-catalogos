/// Rutas base de la app (diseño §2.3).
///
/// Centraliza los paths para evitar strings mágicos repartidos por la UI.
/// En Fase 0.5 definimos las dos rutas mínimas que exige el CA:
/// `/login` (no autenticado) y `/home` (autenticado). Fases posteriores
/// añadirán rutas de pedidos, clientes, catálogos generales, etc.
abstract final class AppRoutes {
  const AppRoutes._();

  /// Ruta de inicio de sesión / ingreso de teléfono (destino del redirect del
  /// guard).
  static const String login = '/login';

  /// Ruta de verificación del código WhatsApp (tarea 1.10). Se navega a ella
  /// tras `codeSent`; el estado del flujo (teléfono) vive en el controlador.
  static const String otp = '/login/otp';

  /// Ruta para completar el perfil tras el primer login (tarea 1.13). El guard
  /// redirige aquí mientras el reseller no tenga `nombre`.
  static const String completeProfile = '/complete-profile';

  /// Ruta principal (autenticada).
  static const String home = '/home';

  /// Ruta del detalle de catálogo (tareas 1.16/1.17/1.18). Recibe el id del
  /// catálogo como parámetro de path (`/catalog/:id`) y, opcionalmente, el
  /// nombre conocido vía `extra` para mostrarlo en el AppBar mientras carga.
  static const String catalogDetail = '/catalog/:id';

  /// Construye el path concreto del detalle para un [catalogId].
  static String catalogDetailPath(String catalogId) => '/catalog/$catalogId';
}
