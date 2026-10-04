import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/widgets/fly_primary_button.dart';
import 'auth_controller.dart';

/// Duración del cooldown de reenvío de OTP (CA tarea 1.10).
const Duration kResendCooldown = Duration(seconds: 60);

/// Pantalla de verificación del código WhatsApp (tarea 1.10).
///
/// - Campo para el código de 6 dígitos; al enviar, [AuthController.verifyCode]
///   llama a `verify-code` y, con el `customToken`, hace
///   `signInWithCustomToken` para abrir la sesión (obtiene `idToken`).
/// - Código correcto → navega a `/home` (vía el guard que reacciona al estado
///   de sesión). Código incorrecto/expirado (400) o lockout (429) → muestra el
///   error mapeado.
/// - Botón de reenvío con cooldown de 60s (`resend-code`): deshabilitado
///   durante la cuenta regresiva, mostrando los segundos restantes. Honra
///   también el `resendAvailableInSeconds` que el backend devuelve en los 429.
class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final TextEditingController _codeController = TextEditingController();
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    // El código ya fue enviado al llegar a esta pantalla: inicia el cooldown.
    // Honra el `resendAvailableInSeconds` que informó `request-code` (si lo
    // hay); si no, usa el cooldown por defecto de 60s.
    final seconds =
        ref.read(authControllerProvider).resendAvailableInSeconds;
    _startCooldown(seconds: seconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown({int? seconds}) {
    _timer?.cancel();
    final total = (seconds != null && seconds > 0)
        ? seconds
        : kResendCooldown.inSeconds;
    setState(() => _secondsRemaining = total);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  bool get _canResend => _secondsRemaining == 0;

  Future<void> _onVerify() async {
    FocusScope.of(context).unfocus();
    final code = _codeController.text.trim();
    if (code.length < 6) {
      // Dejar que el controlador/validación muestren el error de longitud.
      return;
    }
    await ref.read(authControllerProvider.notifier).verifyCode(code);
  }

  Future<void> _onResend() async {
    if (!_canResend) return;
    await ref.read(authControllerProvider.notifier).resendCode();
    // Reinicia el cooldown con los segundos que informó el backend (p. ej. tras
    // un 429 el `resendAvailableInSeconds` puede ser mayor), o 60s por defecto.
    final seconds = ref.read(authControllerProvider).resendAvailableInSeconds;
    _startCooldown(seconds: seconds);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final AuthFlowState auth = ref.watch(authControllerProvider);

    // Al autenticar, el guard de go_router redirige a /home automáticamente.
    // Como el flujo de login usa push, aseguramos volver a la raíz autenticada.
    ref.listen<AuthFlowState>(authControllerProvider, (previous, next) {
      if (next.stage == AuthFlowStage.signedIn) {
        context.go(AppRoutes.home);
      }
    });

    final String phone = auth.phoneNumberE164 ?? 'tu número';

    return Scaffold(
      appBar: AppBar(title: const Text('Verificación')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Ingresa el código',
                  style: textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enviamos un código de 6 dígitos por WhatsApp a $phone.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _codeController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _onVerify(),
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
                if (auth.isVerifying)
                  const Center(child: CircularProgressIndicator())
                else
                  FlyPrimaryButton(
                    label: 'Verificar',
                    icon: Icons.check_circle_outline,
                    onPressed: _onVerify,
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _canResend ? _onResend : null,
                  child: Text(
                    _canResend
                        ? 'Reenviar código'
                        : 'Reenviar código en ${_secondsRemaining}s',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
