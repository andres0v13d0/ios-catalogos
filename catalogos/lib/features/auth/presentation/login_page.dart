import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/phone.dart';
import 'auth_background.dart';
import 'auth_controller.dart';
import 'auth_gradient_button.dart';
import 'auth_palette.dart';
import 'auth_vector_icons.dart';
import 'login_hero_art.dart';

/// País seleccionable en el ingreso de teléfono.
///
/// Fase 1 soporta Colombia (default) y un par de códigos comunes de la región
/// para el selector; el número nacional se normaliza a E.164 con el código
/// elegido. [shortCode] es puramente de presentación (botón "CO +57" del
/// rediseño); la validación/normalización solo usa [dialCode].
class _Country {
  const _Country(this.flag, this.shortCode, this.name, this.dialCode);
  final String flag;
  final String shortCode;
  final String name;

  /// Código de país SIN el prefijo `+` (p. ej. `57`).
  final String dialCode;
}

const List<_Country> _countries = <_Country>[
  _Country('🇨🇴', 'CO', 'Colombia', '57'),
  _Country('🇲🇽', 'MX', 'México', '52'),
  _Country('🇵🇪', 'PE', 'Perú', '51'),
  _Country('🇪🇨', 'EC', 'Ecuador', '593'),
  _Country('🇺🇸', 'US', 'Estados Unidos', '1'),
];

/// Pantalla de ingreso de teléfono + solicitud del código WhatsApp (tarea 1.9).
///
/// Rediseño "B · Hoja inferior" (ver `docs/design/ingreso-b.html`): hero con
/// degradado de marca + tarjetas ilustrativas, hoja inferior con el
/// formulario. Es un cambio puramente visual: la lógica de autenticación
/// (selector de país, validación E.164, cooldown, manejo de errores) es la
/// misma que antes del rediseño.
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

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  late final AnimationController _introController;
  _Country _country = _countries.first;
  bool _navigatedToOtp = false;

  /// Error de formato local (p. ej. número inválido), calculado con la misma
  /// [_validatePhone]/`normalizeToE164` de siempre. Se muestra en el mismo
  /// lugar que los errores del backend (`auth.errorMessage`), como pide el
  /// rediseño; ver [_displayError].
  String? _formatError;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _phoneFocusNode.dispose();
    _phoneController.dispose();
    _introController.dispose();
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
    final String? formatError = _validatePhone(_phoneController.text);
    if (formatError != null) {
      setState(() => _formatError = formatError);
      return;
    }
    setState(() => _formatError = null);
    _navigatedToOtp = false;
    await ref.read(authControllerProvider.notifier).sendCode(
          rawPhone: _phoneController.text,
          countryCode: _country.dialCode,
        );
  }

  Future<void> _pickCountry() async {
    final _Country? selected = await showModalBottomSheet<_Country>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AuthPalette.fieldBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            for (final _Country country in _countries)
              ListTile(
                leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                title: Text(country.name),
                trailing: Text(
                  '+${country.dialCode}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.of(context).pop(country),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null) {
      setState(() => _country = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthFlowState auth = ref.watch(authControllerProvider);

    // Cuando el backend confirma el envío del código, navega a la pantalla de
    // verificación (una sola vez).
    ref.listen<AuthFlowState>(authControllerProvider, (previous, next) {
      if (next.stage == AuthFlowStage.codeSent && !_navigatedToOtp) {
        _navigatedToOtp = true;
        context.push(AppRoutes.otp);
      }
    });

    final String? displayError = _formatError ?? auth.errorMessage;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Stack(
          children: <Widget>[
            // Degradado de fondo a pantalla completa (continúa detrás de la
            // hoja inferior, igual que en docs/design/ingreso-b.html).
            const Positioned.fill(child: AuthGradientBackground(midStop: 0.6)),
            SafeArea(
              // `LayoutBuilder` da la altura total disponible (ya descuenta
              // el teclado): se usa para que la hoja NUNCA pida más que eso
              // (si su contenido natural no entra, se desplaza internamente
              // en vez de desbordar) mientras el hero toma el resto, incluso
              // si eso significa reducirse a 0 en pantallas muy pequeñas con
              // el teclado abierto.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: <Widget>[
                      // Hero: ocupa el espacio restante; se encoge/desvanece
                      // con el teclado (sin overflow) y escala por
                      // min(ancho/390, altoHero/450) vía BoxFit.contain.
                      Expanded(
                        child: ExcludeSemantics(
                          // Puramente decorativo/ilustrativo: no aporta
                          // información al lector de pantalla.
                          child: ClipRect(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                              child: AnimatedBuilder(
                                animation: _introController,
                                builder: (context, _) =>
                                    LoginHeroArt(t: _introController.value),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                        child: SingleChildScrollView(
                          // Ancla al final: si no cabe todo, lo que se oculta
                          // primero es el título/subtítulo, nunca el campo ni
                          // el botón "Enviar código".
                          reverse: true,
                          child: _BottomSheet(
                            introController: _introController,
                            country: _country,
                            onPickCountry: _pickCountry,
                            phoneController: _phoneController,
                            phoneFocusNode: _phoneFocusNode,
                            errorMessage: displayError,
                            isSending: auth.isSending,
                            onSubmit: _onSubmit,
                          ),
                        ),
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

class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.introController,
    required this.country,
    required this.onPickCountry,
    required this.phoneController,
    required this.phoneFocusNode,
    required this.errorMessage,
    required this.isSending,
    required this.onSubmit,
  });

  final AnimationController introController;
  final _Country country;
  final VoidCallback onPickCountry;
  final TextEditingController phoneController;
  final FocusNode phoneFocusNode;
  final String? errorMessage;
  final bool isSending;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final Animation<Offset> slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: introController, curve: Curves.easeOutCubic));

    return SlideTransition(
      position: slide,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color.fromRGBO(0, 10, 30, 0.35),
              offset: Offset(0, -20),
              blurRadius: 50,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AuthPalette.fieldBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Text(
              'Entra y empieza a vender',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                height: 1.3,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6, bottom: 16),
              child: Text(
                'Te enviaremos un código de 6 dígitos por WhatsApp.',
                style: TextStyle(
                  fontSize: 13,
                  color: AuthPalette.textMuted,
                  height: 1.5,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Número de celular',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CountryButton(country: country, onTap: onPickCountry),
                const SizedBox(width: 10),
                Expanded(
                  child: _PhoneField(
                    controller: phoneController,
                    focusNode: phoneFocusNode,
                    onSubmitted: onSubmit,
                  ),
                ),
              ],
            ),
            if (errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AuthPalette.errorRed,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: AuthGradientButton(
                label: 'Enviar código',
                iconPainter: const ArrowForwardPainter(color: AppColors.primary),
                enabled: !isSending,
                loading: isSending,
                onPressed: onSubmit,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Al continuar aceptas los Términos y la Política de privacidad',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AuthPalette.textMuted,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryButton extends StatelessWidget {
  const _CountryButton({required this.country, required this.onTap});

  final _Country country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cambiar país, actual ${country.name} +${country.dialCode}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52, minWidth: 48),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AuthPalette.countryFieldBackground,
              border: Border.all(color: AuthPalette.fieldBorder, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${country.shortCode} +${country.dialCode}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CustomPaint(painter: ChevronDownPainter(color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'Número de celular',
      child: SizedBox(
        height: 52,
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.phone,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9 ()\-+.]')),
          ],
          decoration: InputDecoration(
            isCollapsed: true,
            filled: true,
            fillColor: Colors.white,
            hintText: '300 123 4567',
            hintStyle: const TextStyle(color: AuthPalette.hint, fontWeight: FontWeight.w500),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AuthPalette.fieldBorder, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AuthPalette.fieldBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.secondary, width: 2),
            ),
          ),
          onFieldSubmitted: (_) => onSubmitted(),
        ),
      ),
    );
  }
}

