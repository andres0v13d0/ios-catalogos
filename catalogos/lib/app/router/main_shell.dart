import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

/// Contenedor de las pestañas. Branches: 0 Comprar, 1 Chat, 2 Pedidos, 3 Cuenta.
/// Las pantallas de detalle son rutas
/// de nivel superior, así que tapan la barra inferior.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<(IconData, String)> _all = <(IconData, String)>[
    (LucideIcons.store, 'Comprar'),
    (LucideIcons.messageCircle, 'Chat'),
    (LucideIcons.receiptText, 'Pedidos'),
    (LucideIcons.user, 'Cuenta'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int selected = navigationShell.currentIndex;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Todas las pestañas tienen cabecera azul: iconos del sistema en blanco.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 72,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shadowColor: AppColors.primary,
            elevation: 8,
            indicatorColor: AppColors.secondary,
            indicatorShape: const StadiumBorder(),
            iconTheme: WidgetStateProperty.resolveWith(
              (Set<WidgetState> s) => IconThemeData(
                size: 22,
                color: s.contains(WidgetState.selected)
                    ? Colors.white
                    : const Color(0xFF5B6B84),
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (Set<WidgetState> s) => TextStyle(
                fontSize: 11,
                fontWeight: s.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: s.contains(WidgetState.selected)
                    ? AppColors.secondary
                    : const Color(0xFF5B6B84),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (int i) => navigationShell.goBranch(
              i,
              // Tocar la pestaña activa vuelve a su raíz.
              initialLocation: i == navigationShell.currentIndex,
            ),
            destinations: <NavigationDestination>[
              for (final (IconData, String) d in _all)
                NavigationDestination(icon: Icon(d.$1), label: d.$2),
            ],
          ),
        ),
      ),
    );
  }
}
