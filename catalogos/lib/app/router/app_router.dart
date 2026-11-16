import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_state_provider.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/otp_page.dart';
import '../../features/profile/presentation/account_settings_page.dart';
import '../../features/profile/presentation/complete_profile_page.dart';
import '../../features/profile/presentation/profile_controller.dart';
import '../../features/shared_catalogs/presentation/catalog_detail_page.dart';
import '../../features/shared_catalogs/presentation/price_adjustment_controller.dart';
import '../../features/shared_catalogs/presentation/price_adjustment_page.dart';
import '../../features/shared_catalogs/presentation/product_detail_page.dart';
import '../../features/shared_catalogs/domain/reseller_banner.dart';
import '../../features/shared_catalogs/presentation/reseller_banner_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/buy/buy_page.dart';
import '../../features/account/account_tab.dart';
import '../../features/chat/chat_tab.dart';
import '../../features/visitor/share_link_page.dart';
import '../../features/visitor/visitor_catalog_page.dart';
import '../../features/chat/conversation_page.dart';
import 'app_routes.dart';
import 'main_shell.dart';

/// Configuración de `go_router` con guard de autenticación (diseño §2.3).
///
/// El `redirect` lee el [authStateProvider] (placeholder de Fase 0.5):
/// - Si no hay sesión y la ruta destino no es `/login`, redirige a `/login`.
/// - Si hay sesión y el usuario está en `/login`, lo lleva a `/comprar`.
///
/// El router se expone como provider para que su `redirect` reaccione a los
/// cambios del estado de auth: envolvemos el `Ref` en un
/// [_RouterRefreshListenable] que notifica a go_router cuando cambia la sesión.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final _RouterRefreshListenable refresh = _RouterRefreshListenable(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.buy,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) {
      final bool signedIn = ref.read(isSignedInProvider);
      final String location = state.matchedLocation;
      // Las rutas públicas del flujo de login (ingreso de teléfono y OTP) son
      // accesibles sin sesión.
      final bool goingToAuthFlow =
          location == AppRoutes.login || location == AppRoutes.otp;
      // Pestañas públicas: el visitante entra sin cuenta.
      final bool isPublic =
          goingToAuthFlow ||
          state.fullPath == AppRoutes.shareLink ||
          location == AppRoutes.buy ||
          location.startsWith('/comprar/c/') ||
          location.startsWith(AppRoutes.chat) ||
          location == AppRoutes.orders ||
          location == AppRoutes.account;

      // Sin sesión: el resto exige cuenta de revendedor (Pedidos solo
      // muestra los del propio celular).
      if (!signedIn) {
        return isPublic ? null : AppRoutes.login;
      }

      // Con sesión: no permanecer en el flujo de auth; ir a Comprar.
      if (goingToAuthFlow) {
        return AppRoutes.buy;
      }

      // Guard de "perfil incompleto" (tarea 1.13), compuesto con el de auth:
      // mientras el reseller no tenga nombre, redirige a completar perfil.
      // Cuando el estado del perfil es `complete`, deja de redirigir; en
      // `unknown` (aún no consultado) no se fuerza nada para no bloquear la
      // navegación antes de resolver `/reseller/me`.
      final ProfileStatus profileStatus = ref
          .read(profileControllerProvider)
          .status;
      final bool onCompleteProfile = location == AppRoutes.completeProfile;

      if (profileStatus == ProfileStatus.incomplete && !onCompleteProfile) {
        return AppRoutes.completeProfile;
      }

      // Perfil completo: no permanecer en la pantalla de completar perfil.
      if (profileStatus == ProfileStatus.complete && onCompleteProfile) {
        return AppRoutes.buy;
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
        builder: (BuildContext context, GoRouterState state) => const OtpPage(),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        name: 'completeProfile',
        builder: (BuildContext context, GoRouterState state) =>
            const CompleteProfilePage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell shell,
        ) => MainShell(navigationShell: shell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.buy,
                name: 'buy',
                builder: (BuildContext context, GoRouterState state) =>
                    const BuyPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.chat,
                name: 'chat',
                builder: (BuildContext context, GoRouterState state) =>
                    const ChatTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.orders,
                name: 'orders',
                builder: (BuildContext context, GoRouterState state) =>
                    const OrdersPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: AppRoutes.account,
                name: 'account',
                builder: (BuildContext context, GoRouterState state) =>
                    const AccountTab(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.accountSettings,
        name: 'accountSettings',
        builder: (BuildContext context, GoRouterState state) =>
            const AccountSettingsPage(),
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
        path: AppRoutes.conversation,
        builder: (BuildContext context, GoRouterState state) =>
            ConversationPage(
              conversationId: state.pathParameters['id'] ?? '',
              info: state.extra is ConversationInfo
                  ? state.extra! as ConversationInfo
                  : state.extra is String
                  ? ConversationInfo(title: state.extra! as String)
                  : null,
            ),
      ),
      GoRoute(
        path: AppRoutes.visitorCatalog,
        builder: (BuildContext context, GoRouterState state) =>
            VisitorCatalogPage(code: state.pathParameters['code'] ?? ''),
      ),
      GoRoute(
        path: AppRoutes.adjustPrices,
        name: 'adjustPrices',
        builder: (BuildContext context, GoRouterState state) {
          final PriceAdjustmentArgs args = state.extra! as PriceAdjustmentArgs;
          return PriceAdjustmentPage(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.banner,
        name: 'banner',
        builder: (BuildContext context, GoRouterState state) {
          final ResellerBannerState args = state.extra! as ResellerBannerState;
          return ResellerBannerPage(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.productDetail,
        name: 'productDetail',
        builder: (BuildContext context, GoRouterState state) {
          final ProductDetailArgs args = state.extra! as ProductDetailArgs;
          return ProductDetailPage(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.shareLink,
        builder: (BuildContext context, GoRouterState state) =>
            ShareLinkPage(id: state.pathParameters['id'] ?? ''),
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
