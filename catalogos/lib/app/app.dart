import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/notifications/push_service.dart';
import '../features/visitor/visitor_catalogs.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Raíz de la aplicación: tema FlyStock, go_router y avisos push.
class RevendedoresApp extends ConsumerStatefulWidget {
  const RevendedoresApp({super.key});

  @override
  ConsumerState<RevendedoresApp> createState() => _RevendedoresAppState();
}

class _RevendedoresAppState extends ConsumerState<RevendedoresApp> {
  @override
  void initState() {
    super.initState();
    // Tras el primer frame el router ya existe y puede recibir rutas de avisos.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final GoRouter router = ref.read(appRouterProvider);
      ref.read(pushServiceProvider)
        ..bindNavigator(router.push)
        ..start();
    });
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = ref.watch(appRouterProvider);
    // Catálogo agregado/quitado → suscribe/baja su tema de productos nuevos.
    ref.listen(
      visitorCatalogsProvider,
      (_, List<VisitorCatalog> next) =>
          ref.read(pushServiceProvider).syncTopics(next),
    );

    return MaterialApp.router(
      title: 'FLY+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      routerConfig: router,
    );
  }
}
