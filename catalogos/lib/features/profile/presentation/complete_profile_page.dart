import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/widgets/fly_primary_button.dart';
import 'profile_controller.dart';

/// Pantalla de "completar perfil" tras el primer login (tarea 1.13).
///
/// Si el reseller no tiene `nombre`, el guard del router redirige aquí.
/// Al guardar (`PATCH /reseller/me { nombre }`) el estado del perfil pasa a
/// `complete`, el guard deja de redirigir y navegamos a `/home`.
class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Prellena con el nombre conocido si existe.
    final reseller = ref.read(profileControllerProvider).reseller;
    if (reseller?.nombre != null) {
      _nameController.text = reseller!.nombre!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .saveName(_nameController.text);
    if (ok && mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProfileState state = ref.watch(profileControllerProvider);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('¿Cómo te llamas?', style: textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Usaremos tu nombre para personalizar tu cuenta.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.words,
                  enabled: !state.isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Tu nombre completo',
                  ),
                  validator: (String? value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Ingresa tu nombre.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                if (state.errorMessage != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FlyPrimaryButton(
                  label: state.isLoading ? 'Guardando…' : 'Continuar',
                  onPressed: state.isLoading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
