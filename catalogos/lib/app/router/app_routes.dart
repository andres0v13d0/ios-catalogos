/// Rutas base de la app (diseño §2.3).
///
/// Centraliza los paths para evitar strings mágicos repartidos por la UI.
/// En Fase 0.5 definimos las dos rutas mínimas que exige el CA:
/// `/login` (no autenticado) y `/home` (autenticado). Fases posteriores
/// añadirán rutas de pedidos, clientes, catálogos generales, etc.
abstract final class AppRoutes {
  const AppRoutes._();

  /// Ruta de inicio de sesión (destino del redirect del guard).
  static const String login = '/login';

  /// Ruta principal (autenticada).
  static const String home = '/home';
}
