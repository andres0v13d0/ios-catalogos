import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_state_provider.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/otp_page.dart';
import '../../features/profile/presentation/complete_profile_page.dart';
import '../../features/profile/presentation/profile_controller.dart';
import '../../features/shared_catalogs/presentation/catalog_detail_page.dart';
import '../../features/shared_catalogs/presentation/home_page.dart';
import '../../features/shared_catalogs/presentation/price_adjustment_controller.dart';
import '../../features/shared_catalogs/presentation/price_adjustment_page.dart';
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
      final String location = state.matchedLocation;
      // Las rutas públicas del flujo de login (ingreso de teléfono y OTP) son
      // accesibles sin sesión.
      final bool goingToAuthFlow =
          location == AppRoutes.login || location == AppRoutes.otp;

      // Sin sesión: forzar login (salvo que ya se dirija al flujo de auth).
      if (!signedIn) {
        return goingToAuthFlow ? null : AppRoutes.login;
      }

      // Con sesión: no permanecer en el flujo de auth; ir a home.
      if (goingToAuthFlow) {
        return AppRoutes.home;
      }

      // Guard de "perfil incompleto" (tarea 1.13), compuesto con el de auth:
      // mientras el reseller no tenga nombre, redirige a completar perfil.
      // Cuando el estado del perfil es `complete`, deja de redirigir; en
      // `unknown` (aún no consultado) no se fuerza nada para no bloquear la
      // navegación antes de resolver `/reseller/me`.
      final ProfileStatus profileStatus =
          ref.read(profileControllerProvider).status;
      final bool onCompleteProfile = location == AppRoutes.completeProfile;

      if (profileStatus == ProfileStatus.incomplete && !onCompleteProfile) {
        return AppRoutes.completeProfile;
      }

      // Perfil completo: no permanecer en la pantalla de completar perfil.
      if (profileStatus == ProfileStatus.complete && onCompleteProfile) {
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
        path: AppRoutes.otp,
        name: 'otp',
        builder: (BuildContext context, GoRouterState state) =>
            const OtpPage(),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        name: 'completeProfile',
        builder: (BuildContext context, GoRouterState state) =>
            const CompleteProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (BuildContext context, GoRouterState state) =>
            const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.catalogDetail,
        name: 'catalogDetail',
        builder: (BuildContext context, GoRouterState state) {
          final String id = state.pathParameters['id'] ?? '';
          final String? title = state.extra is String
              ? state.extra! as String
              : null;
          return CatalogDetailPage(catalogId: id, title: title);
        },
      ),
      GoRoute(
        path: AppRoutes.adjustPrices,
        name: 'adjustPrices',
        builder: (BuildContext context, GoRouterState state) {
          final PriceAdjustmentArgs args = state.extra! as PriceAdjustmentArgs;
          return PriceAdjustmentPage(args: args);
        },
      ),
    ],
  );
});

/// Puente entre Riverpod y go_router: notifica al router cuando cambia el
/// estado de autenticación para que vuelva a evaluar el `redirect`.
class _RouterRefreshListenable extends ChangeNotifier {
  _RouterRefreshListenable(Ref ref) {
    _authSub = ref.listen<AuthStatus>(
      authStateProvider,
      (AuthStatus? previous, AuthStatus next) => notifyListeners(),
    );
    // El guard de "perfil incompleto" (tarea 1.13) también debe re-evaluarse
    // cuando cambia el estado del perfil (p. ej. tras guardar el nombre).
    _profileSub = ref.listen<ProfileStatus>(
      profileControllerProvider.select((ProfileState s) => s.status),
      (ProfileStatus? previous, ProfileStatus next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthStatus> _authSub;
  late final ProviderSubscription<ProfileStatus> _profileSub;

  @override
  void dispose() {
    _authSub.close();
    _profileSub.close();
    super.dispose();
  }
}
