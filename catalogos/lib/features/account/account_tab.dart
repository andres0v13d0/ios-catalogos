import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/widgets/brand_header.dart';
import '../auth/presentation/auth_state_provider.dart';
import '../profile/presentation/account_settings_page.dart';
import 'account_widgets.dart';

/// Pestaña "Cuenta": ajustes de la cuenta, o invitación a iniciar sesión
/// (cualquiera puede: revendedor o comprador, se distingue por sus catálogos).
class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isSignedInProvider)) {
      return const AccountSettingsPage(showBack: false);
    }
    return Scaffold(
      backgroundColor: kSheetTint,
      body: Column(
        children: <Widget>[
          const BrandHeader(
            title: 'Cuenta',
            subtitle: 'Estás navegando sin cuenta',
            sheetColor: kSheetTint,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Inicia sesión con tu número de celular para guardar tus '
                    'catálogos y ver tus pedidos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF5B6B84)),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.login),
                  icon: const Icon(LucideIcons.logIn),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: AppColors.secondary,
                    shape: const StadiumBorder(),
                  ),
                  label: const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 24),
                const LegalSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
