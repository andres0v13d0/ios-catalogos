import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/phone.dart';
import '../../auth/presentation/auth_palette.dart';
import '../../auth/presentation/auth_state_provider.dart';
import 'profile_controller.dart';

/// Pantalla "Cuenta": número del revendedor + cerrar sesión / eliminar
/// cuenta. Se abre desde el ícono de engranaje de "Tus catálogos" (antes
/// estas dos acciones vivían en un menú sobre el pill "Salir"; ahora tienen
/// pantalla propia).
class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({super.key});

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => _ConfirmDialog(
        title: '¿Cerrar sesión?',
        message: 'Vas a salir de tu cuenta de FLY+ en este dispositivo.',
        confirmLabel: 'Salir',
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authStateProvider.notifier).logout();
      // El guard del router reacciona a `authStateProvider`, pero se navega
      // explícito aquí también: sin esto, en algunos dispositivos la pantalla
      // se quedaba montada hasta reabrir la app.
      if (context.mounted) context.go(AppRoutes.login);
    }
  }

  /// Confirma y ejecuta el borrado de cuenta (Apple/Google guideline
  /// 5.1.1(v)): `DELETE /reseller/me` y, si el backend confirma, cierra la
  /// sesión local (Firebase + almacenamiento) igual que [_confirmLogout].
  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => _ConfirmDialog(
        title: '¿Eliminar tu cuenta?',
        message:
            'Se borrará tu cuenta de FLY+ y tu catálogo general propio, '
            'si lo armaste. Esta acción no se puede deshacer.',
        confirmLabel: 'Eliminar',
        confirmColor: Colors.red,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true) return;

    final bool deleted =
        await ref.read(profileControllerProvider.notifier).deleteAccount();
    if (!context.mounted) return;

    if (!deleted) {
      final String? message = ref.read(profileControllerProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'No pudimos eliminar tu cuenta.')),
      );
      return;
    }

    await ref.read(authStateProvider.notifier).logout();
    if (context.mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? phoneE164 = ref.watch(profileControllerProvider).reseller?.telefonoE164;
    final String phoneDisplay = (phoneE164 == null || phoneE164.isEmpty)
        ? '—'
        : formatPhoneForDisplay(phoneE164);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 4),
              child: Row(
                children: <Widget>[
                  Semantics(
                    button: true,
                    label: 'Volver',
                    child: IconButton(
                      onPressed: () => _goBack(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                  ),
                  const Text(
                    'Cuenta',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 12),
                  const Text(
                    'Tu número',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AuthPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phoneDisplay,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Semantics(
                    button: true,
                    label: 'Cerrar sesión',
                    child: OutlinedButton(
                      onPressed: () => _confirmLogout(context, ref),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: AuthPalette.fieldBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cerrar sesión',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Eliminar cuenta',
                    child: OutlinedButton(
                      onPressed: () => _confirmDeleteAccount(context, ref),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Eliminar cuenta',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de confirmación compartido por "Cerrar sesión" y "Eliminar
/// cuenta" (mismo layout, solo cambian título/mensaje/color del botón).
class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.confirmColor = AppColors.primary,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      namesRoute: true,
      label: '$title, diálogo de confirmación',
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AuthPalette.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: 'Cancelar',
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: AuthPalette.fieldBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: confirmLabel,
                      child: FilledButton(
                        onPressed: onConfirm,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: confirmColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(confirmLabel),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
