import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import 'auth_background.dart';
import 'auth_controller.dart';
import 'auth_gradient_button.dart';
import 'auth_palette.dart';
import 'auth_vector_icons.dart';
import 'otp_code_boxes.dart';
import 'otp_keypad.dart';

/// Duración del cooldown de reenvío de OTP (CA tarea 1.10).
const Duration kResendCooldown = Duration(seconds: 60);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Formatea un E.164 para mostrarlo al usuario. Puramente de presentación: no
/// toca la normalización/validación real (`core/utils/phone.dart`). Conoce el
/// agrupamiento 3-3-4 de Colombia (`+57`, mercado por defecto de la app); para
/// cualquier otro país muestra el E.164 tal cual, sin inventar un agrupamiento
/// que podría ser incorrecto.
String _formatPhoneForDisplay(String e164) {
  final String digits = e164.startsWith('+') ? e164.substring(1) : e164;
  if (digits.startsWith('57') && digits.length == 12) {
    final String national = digits.substring(2);
    return '+57 ${national.substring(0, 3)} ${national.substring(3, 6)} ${national.substring(6)}';
  }
  return e164;
}

/// Pantalla de verificación del código WhatsApp (tarea 1.10).
///
/// Rediseño "Código B" (ver `docs/design/codigo-b.html`): 6 casillas propias
/// + teclado numérico propio (sin `TextField` ni teclado del sistema). Es un
/// cambio puramente visual/de captura: la lógica de autenticación
/// (`AuthController.verifyCode`, `signInWithCustomToken`, cooldown de
/// reenvío, lockout, mensajes de error, `isNewProfile`) es exactamente la
/// misma que antes del rediseño.
class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage>
    with TickerProviderStateMixin {
  String _code = '';
  bool _hasError = false;
  String? _lastAnnouncedError;
  String? _pasteSuggestion;

  Timer? _timer;
  int _secondsRemaining = 0;

  late final AnimationController _introController;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    // El código ya fue enviado al llegar a esta pantalla: inicia el cooldown.
    // Honra el `resendAvailableInSeconds` que informó `request-code` (si lo
    // hay); si no, usa el cooldown por defecto de 60s.
    final seconds = ref.read(authControllerProvider).resendAvailableInSeconds;
    _startCooldown(seconds: seconds);
    _checkClipboardForCode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _introController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _startCooldown({int? seconds}) {
    _timer?.cancel();
    final total =
        (seconds != null && seconds > 0) ? seconds : kResendCooldown.inSeconds;
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

  Future<void> _checkClipboardForCode() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String digits = (data?.text ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (!mounted || digits.length != 6 || _code.isNotEmpty) return;
    setState(() => _pasteSuggestion = digits);
  }

  Future<void> _verify() async {
    if (_code.length != 6) return;
    await ref.read(authControllerProvider.notifier).verifyCode(_code);
  }

  void _consumePasteSuggestionIfAny() {
    if (_pasteSuggestion != null) {
      setState(() => _pasteSuggestion = null);
    }
  }

  void _onDigitPressed(String digit) {
    _consumePasteSuggestionIfAny();
    setState(() {
      if (_hasError) {
        _code = '';
        _hasError = false;
      }
      if (_code.length < 6) {
        _code += digit;
      }
    });
    if (_code.length == 6) {
      unawaited(_verify());
    }
  }

  void _onBackspacePressed() {
    _consumePasteSuggestionIfAny();
    setState(() {
      if (_hasError) {
        _code = '';
        _hasError = false;
      } else if (_code.isNotEmpty) {
        _code = _code.substring(0, _code.length - 1);
      }
    });
  }

  void _onClearAll() {
    _consumePasteSuggestionIfAny();
    setState(() {
      _code = '';
      _hasError = false;
    });
  }

  void _onPasteSuggestionTap() {
    final String? digits = _pasteSuggestion;
    if (digits == null) return;
    setState(() {
      _code = digits;
      _pasteSuggestion = null;
      _hasError = false;
    });
    unawaited(_verify());
  }

  Future<void> _onResend() async {
    if (!_canResend) return;
    setState(() {
      _code = '';
      _hasError = false;
    });
    await ref.read(authControllerProvider.notifier).resendCode();
    final seconds = ref.read(authControllerProvider).resendAvailableInSeconds;
    _startCooldown(seconds: seconds);
  }

  void _goBack() {
    ref.read(authControllerProvider.notifier).reset();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthFlowState auth = ref.watch(authControllerProvider);

    // Al autenticar, el guard de go_router redirige a /home automáticamente.
    ref.listen<AuthFlowState>(authControllerProvider, (previous, next) {
      if (next.stage == AuthFlowStage.signedIn) {
        context.go(AppRoutes.home);
        return;
      }
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        setState(() => _hasError = true);
        _shakeController.forward(from: 0);
        if (next.errorMessage != _lastAnnouncedError) {
          _lastAnnouncedError = next.errorMessage;
          final FlutterView? view = View.maybeOf(context);
          if (view != null) {
            SemanticsService.sendAnnouncement(
              view,
              next.errorMessage!,
              TextDirection.ltr,
            );
          }
        }
      }
    });

    final String phone = auth.phoneNumberE164 ?? 'tu número';
    final bool isVerifying = auth.isVerifying;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Stack(
          children: <Widget>[
            const Positioned.fill(child: AuthGradientBackground(midStop: 0.55)),
            const Positioned(
              left: -60,
              top: -40,
              width: 380,
              height: 380,
              child: AuthRadialGlow(color: Color(0x665DE0E6)), // rgba(93,224,230,0.4)
            ),
            const Positioned(
              right: -70,
              top: 420,
              width: 200,
              height: 200,
              child: AuthFlatGlow(color: Color(0x2400FF94)), // rgba(0,255,148,0.14)
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 0 = tamaño compacto (pantallas pequeñas / teclado), 1 =
                  // tamaño de referencia (844dp+). Solo compacta encabezado y
                  // casillas; las teclas del teclado NUNCA bajan de 52dp
                  // (accesibilidad, ya cumplen el mínimo de 48dp).
                  final double t =
                      ((constraints.maxHeight - 640) / (844 - 640)).clamp(0.0, 1.0);

                  return Column(
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 16, top: _lerp(6, 16, t)),
                          child: _BackButton(onTap: _goBack),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _Header(
                          iconSize: _lerp(40, 64, t),
                          iconRadius: _lerp(14, 20, t),
                          iconGlyphSize: _lerp(22, 34, t),
                          titleFontSize: _lerp(20, 28, t),
                          titleTopMargin: _lerp(6, 22, t),
                          subtitleFontSize: _lerp(12, 14, t),
                          phoneDisplay: _formatPhoneForDisplay(phone),
                          entrance: _introController,
                          onChangeNumber: _goBack,
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            OtpCodeBoxes(
                              code: _code,
                              hasError: _hasError,
                              shake: _shakeController,
                              entrance: _introController,
                              boxHeight: _lerp(42, 64, t),
                            ),
                            if (_pasteSuggestion != null) ...<Widget>[
                              const SizedBox(height: 12),
                              Center(
                                child: _PasteChip(onTap: _onPasteSuggestionTap),
                              ),
                            ],
                            SizedBox(height: _lerp(6, 8, t)),
                            if (auth.errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  auth.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AuthPalette.codeErrorText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            _CooldownOrResend(
                              canResend: _canResend,
                              secondsRemaining: _secondsRemaining,
                              onResend: _onResend,
                            ),
                            SizedBox(height: _lerp(10, 16, t)),
                            AuthGradientButton(
                              label: 'Verificar',
                              iconPainter: const CheckPainter(color: AppColors.primary),
                              enabled: _code.length == 6,
                              loading: isVerifying,
                              onPressed: _verify,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      OtpKeypad(
                        onDigit: _onDigitPressed,
                        onBackspace: _onBackspacePressed,
                        onClear: _onClearAll,
                        locked: isVerifying,
                        keyHeight: 52,
                        padding: EdgeInsets.fromLTRB(
                          _lerp(14, 20, t),
                          _lerp(8, 12, t),
                          _lerp(14, 20, t),
                          _lerp(10, 20, t),
                        ),
                        gap: _lerp(6, 8, t),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Visual 44x44 (fiel al mockup) dentro de un área táctil de 48x48
    // (accesibilidad: áreas táctiles ≥48dp).
    return Semantics(
      button: true,
      label: 'Volver',
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0x24FFFFFF), // rgba(255,255,255,0.14)
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CustomPaint(painter: ChevronLeftPainter(color: Colors.white)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.iconSize,
    required this.iconRadius,
    required this.iconGlyphSize,
    required this.titleFontSize,
    required this.titleTopMargin,
    required this.subtitleFontSize,
    required this.phoneDisplay,
    required this.entrance,
    required this.onChangeNumber,
  });

  final double iconSize;
  final double iconRadius;
  final double iconGlyphSize;
  final double titleFontSize;
  final double titleTopMargin;
  final double subtitleFontSize;
  final String phoneDisplay;
  final Animation<double> entrance;
  final VoidCallback onChangeNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedBuilder(
          animation: entrance,
          builder: (context, child) {
            // Entra girando suavemente hasta -6°, con fade+escala.
            final double t = Curves.easeOutBack.transform(
              (entrance.value / 0.6).clamp(0.0, 1.0),
            );
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: (-6 * (3.14159265 / 180)) * t,
                child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
              ),
            );
          },
          child: Container(
            width: iconSize,
            height: iconSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(iconRadius),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[AppColors.accent, AppColors.brand],
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color.fromRGBO(0, 255, 148, 0.35),
                  offset: Offset(0, 16),
                  blurRadius: 34,
                ),
              ],
            ),
            child: SizedBox(
              width: iconGlyphSize,
              height: iconGlyphSize,
              child: const CustomPaint(painter: WhatsAppPainter(color: AppColors.primary)),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: titleTopMargin),
          child: Text(
            'Revisa tu WhatsApp',
            style: TextStyle(
              fontSize: titleFontSize,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: subtitleFontSize,
                height: 1.5,
                color: AuthPalette.textMutedOnDark,
              ),
              children: <InlineSpan>[
                const TextSpan(text: 'Escribe el código de 6 dígitos que enviamos al '),
                TextSpan(
                  text: phoneDisplay,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Cambiar número',
          // Enlace secundario (no es uno de los controles primarios que pide
          // ≥48dp): área táctil ampliada con padding en vez de un mínimo
          // fijo de 48dp, para no inflar el alto del encabezado en pantallas
          // pequeñas.
          child: InkWell(
            onTap: onChangeNumber,
            child: const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                'Cambiar número',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CooldownOrResend extends StatelessWidget {
  const _CooldownOrResend({
    required this.canResend,
    required this.secondsRemaining,
    required this.onResend,
  });

  final bool canResend;
  final int secondsRemaining;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    if (!canResend) {
      final int m = secondsRemaining ~/ 60;
      final int s = secondsRemaining % 60;
      final String mmss = '$m:${s.toString().padLeft(2, '0')}';
      return Text.rich(
        TextSpan(
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: AuthPalette.textMutedOnDark,
          ),
          children: <InlineSpan>[
            const TextSpan(text: 'Puedes pedir otro código en '),
            TextSpan(
              text: mmss,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      );
    }

    return Center(
      child: Semantics(
        button: true,
        label: 'Reenviar código',
        // Enlace secundario: área táctil ampliada con padding (igual
        // criterio que "Cambiar número"), no un mínimo fijo de 48dp.
        child: InkWell(
          onTap: onResend,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Reenviar código',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasteChip extends StatelessWidget {
  const _PasteChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Pegar código',
      child: Material(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.content_paste_rounded, size: 16, color: Colors.white),
                SizedBox(width: 6),
                Text(
                  'Pegar código',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
