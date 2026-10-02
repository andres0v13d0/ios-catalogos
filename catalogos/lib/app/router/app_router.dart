import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_state_provider.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/shared_catalogs/presentation/home_page.dart';
import 'app_routes.dart';

/// Configuración de `go_router` con guard de autenticación (diseño §2.3).
///
/// El `redirect` lee el [authStateProvider] (placeholder de Fase 0.5):
/// - Si no hay sesión y la ruta destino no es `/login`, redirige a `/login`.
/// - Si hay sesión y el usuario está en `/login`, lo lleva a `/home`.
///
/// El router se expone como provider para que su `redirect` reaccione a los
/// cambios del estado de auth: envolvemos el `Ref` en un
/// [_RouterRefreshListenable] que notifica a go_router cuando cambia la sesión.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefreshListenable refresh = _RouterRefreshListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final bool signedIn = ref.read(isSignedInProvider);
      final bool goingToLogin = state.matchedLocation == AppRoutes.login;

      // Sin sesión: forzar login (salvo que ya se dirija a login).
      if (!signedIn) {
        return goingToLogin ? null : AppRoutes.login;
      }

      // Con sesión: no permanecer en login; ir a home.
      if (goingToLogin) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (BuildContext context, GoRouterState state) =>
            const HomePage(),
      ),
    ],
  );
});

/// Puente entre Riverpod y go_router: notifica al router cuando cambia el
/// estado de autenticación para que vuelva a evaluar el `redirect`.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(Ref ref) {
    _subscription = ref.listen<AuthStatus>(
      authStateProvider,
      (AuthStatus? previous, AuthStatus next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthStatus> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
