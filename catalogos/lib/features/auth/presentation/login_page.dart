import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/utils/phone.dart';
import '../../../shared/widgets/fly_primary_button.dart';
import 'auth_controller.dart';

/// País seleccionable en el ingreso de teléfono.
///
/// Fase 1 soporta Colombia (default) y un par de códigos comunes de la región
/// para el selector; el número nacional se normaliza a E.164 con el código
/// elegido.
class _Country {
  const _Country(this.flag, this.name, this.dialCode);
  final String flag;
  final String name;

  /// Código de país SIN el prefijo `+` (p. ej. `57`).
  final String dialCode;
}

const List<_Country> _countries = <_Country>[
  _Country('🇨🇴', 'Colombia', '57'),
  _Country('🇲🇽', 'México', '52'),
  _Country('🇵🇪', 'Perú', '51'),
  _Country('🇪🇨', 'Ecuador', '593'),
  _Country('🇺🇸', 'Estados Unidos', '1'),
];

/// Pantalla de ingreso de teléfono + solicitud del código WhatsApp (tarea 1.9).
///
/// - Selector de país con default +57 (Colombia).
/// - Campo de número local editable, validado/normalizado a E.164 con
///   `normalizeToE164`; muestra errores de formato inline.
/// - Al pulsar "Enviar código" invoca [AuthController.sendCode], que llama a
///   `POST /auth/reseller/request-code`; cuando el backend confirma el envío
///   (`codeSent`) navega a la pantalla de verificación. Errores de formato y de
///   rate-limit (429 con cooldown) se muestran inline.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  _Country _country = _countries.first;
  bool _navigatedToOtp = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    final e164 = normalizeToE164(value, countryCode: _country.dialCode);
    if (e164 == null || !isValidE164(e164)) {
      return 'Ingresa un número de teléfono válido.';
    }
    return null;
  }

  Future<void> _onSubmit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    _navigatedToOtp = false;
    await ref.read(authControllerProvider.notifier).sendCode(
          rawPhone: _phoneController.text,
          countryCode: _country.dialCode,
        );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AuthFlowState auth = ref.watch(authControllerProvider);

    // Cuando el backend confirma el envío del código, navega a la pantalla de
    // verificación (una sola vez).
    ref.listen<AuthFlowState>(authControllerProvider, (previous, next) {
      if (next.stage == AuthFlowStage.codeSent && !_navigatedToOtp) {
        _navigatedToOtp = true;
        context.push(AppRoutes.otp);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Revendedores',
                    style: textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingresa tu número de celular para recibir un código de '
                    'verificación.',
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _CountryDropdown(
                        value: _country,
                        onChanged: (c) => setState(() => _country = c),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          autofocus: true,
                          keyboardType: TextInputType.phone,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9 ()\-+.]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Número de celular',
                            hintText: '300 123 4567',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validatePhone,
                          onFieldSubmitted: (_) => _onSubmit(),
                        ),
                      ),
                    ],
                  ),
                  if (auth.errorMessage != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      auth.errorMessage!,
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (auth.isSending)
                    const Center(child: CircularProgressIndicator())
                  else
                    FlyPrimaryButton(
                      label: 'Enviar código',
                      icon: Icons.sms_outlined,
                      onPressed: _onSubmit,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryDropdown extends StatelessWidget {
  const _CountryDropdown({required this.value, required this.onChanged});

  final _Country value;
  final ValueChanged<_Country> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<_Country>(
        value: value,
        onChanged: (c) {
          if (c != null) onChanged(c);
        },
        items: _countries
            .map(
              (c) => DropdownMenuItem<_Country>(
                value: c,
                child: Text('${c.flag} +${c.dialCode}'),
              ),
            )
            .toList(),
      ),
    );
  }
}
