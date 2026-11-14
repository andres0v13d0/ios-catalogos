import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_colors.dart';
import '../../core/config/legal_links.dart';

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    // Sin navegador disponible: no hay nada útil que mostrar.
  }
}

/// Grupo de filas blancas redondeadas de la pantalla Cuenta.
class AccountGroup extends StatelessWidget {
  const AccountGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: .5,
            color: Color(0xFF5B6B84),
          ),
        ),
      ),
      Material(
        color: Colors.white,
        elevation: 1.5,
        shadowColor: const Color(0x14001634),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0)
                const Divider(height: 1, indent: 56, color: Color(0xFFE3E9F3)),
              children[i],
            ],
          ],
        ),
      ),
    ],
  );
}

class AccountRow extends StatelessWidget {
  const AccountRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.primary),
            ),
          ),
          if (value != null)
            Flexible(
              child: Text(
                value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B84)),
              ),
            ),
          const SizedBox(width: 6),
          const Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: Color(0xFF9AA8BF),
          ),
        ],
      ),
    ),
  );
}

/// Términos, privacidad, tratamiento de datos y soporte (mismos enlaces que Flymovil).
class LegalSection extends StatelessWidget {
  const LegalSection({super.key});

  @override
  Widget build(BuildContext context) => AccountGroup(
    title: 'AYUDA Y LEGAL',
    children: <Widget>[
      AccountRow(
        icon: LucideIcons.lifeBuoy,
        label: 'Soporte',
        onTap: () => _open(LegalLinks.support),
      ),
      AccountRow(
        icon: LucideIcons.fileText,
        label: 'Términos y condiciones',
        onTap: () => _open(LegalLinks.terms),
      ),
      AccountRow(
        icon: LucideIcons.shieldCheck,
        label: 'Política de privacidad',
        onTap: () => _open(LegalLinks.privacy),
      ),
      AccountRow(
        icon: LucideIcons.database,
        label: 'Tratamiento de datos',
        onTap: () => _open(LegalLinks.dataPolicy),
      ),
    ],
  );
}
