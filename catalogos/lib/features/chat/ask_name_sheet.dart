import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';

/// Pregunta (sin obligar) cómo se llama quien va a escribir. Devuelve el
/// nombre, o `null` si lo omite o cierra la hoja.
Future<String?> showAskNameSheet(
  BuildContext context, {
  String? providerName,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (BuildContext c) => _AskName(providerName: providerName),
);

class _AskName extends StatefulWidget {
  const _AskName({this.providerName});

  final String? providerName;

  @override
  State<_AskName> createState() => _AskNameState();
}

class _AskNameState extends State<_AskName> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, _ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    final String who = (widget.providerName ?? '').trim().isEmpty
        ? 'el proveedor'
        : widget.providerName!.trim();
    return Padding(
      // Sube con el teclado.
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DCE8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[AppColors.secondary, AppColors.accent],
                  ),
                ),
                child: const Icon(
                  LucideIcons.messageCircle,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¿Cómo te llamas?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Así te verá $who cuando le escribas. Es opcional.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF5B6B84),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ctrl,
              autofocus: true,
              maxLength: 60,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _done(),
              style: const TextStyle(fontSize: 16, color: AppColors.primary),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'Tu nombre',
                hintStyle: const TextStyle(color: Color(0xFF8A97AB)),
                prefixIcon: const Icon(
                  LucideIcons.user,
                  size: 20,
                  color: AppColors.secondary,
                ),
                filled: true,
                fillColor: const Color(0xFFEEF3FB),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.secondary,
                    width: 1.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _done,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Continuar'),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Omitir',
                style: TextStyle(color: Color(0xFF5B6B84)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
