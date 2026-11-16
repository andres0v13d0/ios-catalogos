import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/theme/app_colors.dart';
import 'visitor_catalogs.dart';

/// Abre la cámara y devuelve el texto del primer QR que parezca un enlace o
/// código de catálogo (ver [parseCatalogCode]); `null` si se cierra sin leer.
class ScanQrPage extends StatefulWidget {
  const ScanQrPage({super.key});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  final MobileScannerController _ctrl = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  bool _invalid = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_done) return;
    for (final Barcode b in cap.barcodes) {
      final String? raw = b.rawValue;
      if (raw != null && parseCatalogCode(raw) != null) {
        _done = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
    if (!_invalid) setState(() => _invalid = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
            errorBuilder: (BuildContext context, MobileScannerException e) =>
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      e.errorCode == MobileScannerErrorCode.permissionDenied
                          ? 'Necesitamos permiso de cámara para escanear. Actívalo en los ajustes del teléfono.'
                          : 'No pudimos abrir la cámara.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.secondary, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x),
                  tooltip: 'Cerrar',
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 60,
            child: Text(
              _invalid
                  ? 'Ese QR no es de un catálogo. Prueba con otro.'
                  : 'Apunta al código QR del catálogo',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
