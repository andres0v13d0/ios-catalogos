import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// "Aprende a organizar tu catálogo en FLY+": https://youtu.be/znO7gc7MhX0
const String _kOnboardingVideoId = 'znO7gc7MhX0';

/// Marca si el modal del video ya se mostró automáticamente (primera
/// apertura de la app). Clave independiente de [SessionStore]: debe
/// sobrevivir al cierre de sesión, así que no se usa su `clear()`.
class OnboardingVideoSeenStore {
  OnboardingVideoSeenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _kSeen = 'onboarding.video_seen';

  Future<bool> hasSeen() async => (await _storage.read(key: _kSeen)) != null;

  Future<void> markSeen() => _storage.write(key: _kSeen, value: '1');
}

/// Provider del [OnboardingVideoSeenStore] (secure storage). Los tests lo
/// sobreescriben para no tocar el almacenamiento seguro del SO.
final Provider<OnboardingVideoSeenStore> onboardingVideoSeenStoreProvider =
    Provider<OnboardingVideoSeenStore>(
      (Ref ref) => OnboardingVideoSeenStore(),
    );

/// Abre el modal del video de onboarding. Se usa tanto en la primera
/// apertura automática como en el botón de play junto a ajustes.
Future<void> showOnboardingVideoModal(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (BuildContext context) => const _OnboardingVideoDialog(),
  );
}

class _OnboardingVideoDialog extends StatefulWidget {
  const _OnboardingVideoDialog();

  @override
  State<_OnboardingVideoDialog> createState() =>
      _OnboardingVideoDialogState();
}

class _OnboardingVideoDialogState extends State<_OnboardingVideoDialog> {
  late final YoutubePlayerController _controller =
      YoutubePlayerController.fromVideoId(
        videoId: _kOnboardingVideoId,
        autoPlay: true,
      );

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.topRight,
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: YoutubePlayer(controller: _controller),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
