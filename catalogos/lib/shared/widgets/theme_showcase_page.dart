import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'fly_primary_button.dart';

/// Pantalla de muestra de la identidad visual FlyStock (tarea 0.3).
///
/// Renderiza tipografía (Poppins vía el tema) y la paleta de color de marca,
/// además del [FlyPrimaryButton] con gradiente. Sirve como verificación visual
/// del criterio de aceptación de la tarea 0.3 y como referencia para el resto
/// de pantallas.
class ThemeShowcasePage extends StatelessWidget {
  const ThemeShowcasePage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('FlyStock — Identidad')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text('Tipografía Poppins', style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Encabezados, cuerpo y etiquetas usan la familia Poppins.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          Text('Paleta de marca', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          const _ColorSwatchRow(),
          const SizedBox(height: 32),

          Text('Botón primario', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          FlyPrimaryButton(
            label: 'Continuar',
            icon: Icons.arrow_forward,
            onPressed: () {},
          ),
          const SizedBox(height: 16),
          const FlyPrimaryButton(
            label: 'Deshabilitado',
            onPressed: null,
          ),
        ],
      ),
    );
  }
}

/// Fila con muestras de los colores de marca.
class _ColorSwatchRow extends StatelessWidget {
  const _ColorSwatchRow();

  @override
  Widget build(BuildContext context) {
    const List<(String, Color)> swatches = <(String, Color)>[
      ('Primario', AppColors.primary),
      ('Secundario', AppColors.secondary),
      ('Acento', AppColors.accent),
      ('Brand', AppColors.brand),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        for (final (String name, Color color) in swatches)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
              ),
              const SizedBox(height: 4),
              Text(name, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
      ],
    );
  }
}
