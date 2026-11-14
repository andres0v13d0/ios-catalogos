import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/phone.dart';
import '../../auth/presentation/auth_palette.dart';
import '../../auth/presentation/auth_state_provider.dart';
import '../../../shared/models/reseller.dart';
import '../../../shared/widgets/brand_header.dart';
import '../../account/account_widgets.dart';
import 'profile_controller.dart';

/// Pantalla "Cuenta": número del revendedor + cerrar sesión / eliminar
/// cuenta. Se abre desde el ícono de engranaje de "Tus catálogos" (antes
/// estas dos acciones vivían en un menú sobre el pill "Salir"; ahora tienen
/// pantalla propia).
class AccountSettingsPage extends ConsumerWidget {
  const AccountSettingsPage({super.key, this.showBack = true});

  /// `false` cuando vive como pestaña (no hay a dónde volver).
  final bool showBack;

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.buy);
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
      if (context.mounted) context.go(AppRoutes.buy);
    }
  }

  /// Confirma y ejecuta el borrado de cuenta (Apple/Google guideline
  /// 5.1.1(v)): `DELETE /reseller/me` y, si el backend confirma, cierra la
  /// sesión local (Firebase + almacenamiento) igual que [_confirmLogout].
  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
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

    final bool deleted = await ref
        .read(profileControllerProvider.notifier)
        .deleteAccount();
    if (!context.mounted) return;

    if (!deleted) {
      final String? message = ref.read(profileControllerProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'No pudimos eliminar tu cuenta.')),
      );
      return;
    }

    await ref.read(authStateProvider.notifier).logout();
    if (context.mounted) context.go(AppRoutes.buy);
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final TextEditingController ctrl = TextEditingController(
      text: ref.read(profileControllerProvider).reseller?.nombre ?? '',
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext d) => AlertDialog(
        title: const Text('Tu nombre (opcional)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Cómo te llamas'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(profileControllerProvider.notifier).saveName(name);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Reseller? me = ref.watch(profileControllerProvider).reseller;
    final String? phoneE164 = me?.telefonoE164;
    final String phoneDisplay = (phoneE164 == null || phoneE164.isEmpty)
        ? '—'
        : formatPhoneForDisplay(phoneE164);
    final String name = (me?.nombre ?? '').trim();

    return Scaffold(
      backgroundColor: kSheetTint,
      body: Column(
        children: <Widget>[
          BrandHeader(
            title: 'Cuenta',
            sheetColor: kSheetTint,
            leading: showBack
                ? BrandHeaderButton(
                    icon: LucideIcons.chevronLeft,
                    label: 'Volver',
                    onTap: () => _goBack(context),
                  )
                : null,
            child: Row(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: name.isEmpty
                      ? const Icon(LucideIcons.user, color: Colors.white)
                      : Text(
                          name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name.isEmpty ? 'Revendedor' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        phoneDisplay,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFCFE0F7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: <Widget>[
                AccountGroup(
                  title: 'TU CUENTA',
                  children: <Widget>[
                    AccountRow(
                      icon: LucideIcons.pencil,
                      label: 'Nombre',
                      value: name.isEmpty ? 'Opcional' : name,
                      onTap: () => _editName(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const LegalSection(),
                const SizedBox(height: 24),
                Semantics(
                  button: true,
                  label: 'Cerrar sesión',
                  child: FilledButton(
                    onPressed: () => _confirmLogout(context, ref),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.secondary,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Cerrar sesión'),
                  ),
                ),
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  label: 'Eliminar cuenta',
                  child: OutlinedButton(
                    onPressed: () => _confirmDeleteAccount(context, ref),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFF3C1BC)),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Eliminar cuenta',
                      style: TextStyle(
                        color: Color(0xFFB42318),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                          side: const BorderSide(
                            color: AuthPalette.fieldBorder,
                          ),
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
