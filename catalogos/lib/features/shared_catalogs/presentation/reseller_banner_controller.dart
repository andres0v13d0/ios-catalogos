import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../data/reseller_banner_repository.dart';
import '../domain/reseller_banner.dart';

/// Proveedor del [ImagePicker]. Se sobreescribe en tests con un fake para no
/// depender del selector del sistema.
final Provider<ImagePicker> imagePickerProvider = Provider<ImagePicker>(
  (Ref ref) => ImagePicker(),
);

/// Fase de la pantalla "Banner del catálogo".
enum ResellerBannerPhase { idle, uploading, error }

/// Estado de la pantalla de banner: el [banner] (con/sin imagen propia), la
/// [phase] (reposo/subiendo/error) y un [errorMessage] en español para la UI.
@immutable
class ResellerBannerUiState {
  const ResellerBannerUiState({
    required this.banner,
    this.phase = ResellerBannerPhase.idle,
    this.errorMessage,
    this.permissionDenied = false,
  });

  final ResellerBannerState banner;
  final ResellerBannerPhase phase;
  final String? errorMessage;

  /// `true` si el sistema devolvió acceso denegado/limitado a fotos: la UI
  /// ofrece "Abrir ajustes".
  final bool permissionDenied;

  bool get isUploading => phase == ResellerBannerPhase.uploading;

  ResellerBannerUiState copyWith({
    ResellerBannerState? banner,
    ResellerBannerPhase? phase,
    String? errorMessage,
    bool clearError = false,
    bool? permissionDenied,
  }) {
    return ResellerBannerUiState(
      banner: banner ?? this.banner,
      phase: phase ?? this.phase,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }
}

/// Controla la selección (image_picker, selector del sistema — SIN permisos de
/// galería), subida (multipart) y borrado del banner del revendedor.
///
/// La compresión en el celular es solo un aligeramiento previo (maxWidth/
/// maxHeight 1600, quality 85 de image_picker); el servidor reprocesa con su
/// pipeline. El archivo temporal se borra tras subir.
class ResellerBannerController extends Notifier<ResellerBannerUiState> {
  ResellerBannerController(this._args);

  final ResellerBannerState _args;

  ResellerBannerRepository get _repo => ref.read(resellerBannerRepositoryProvider);
  ImagePicker get _picker => ref.read(imagePickerProvider);

  @override
  ResellerBannerUiState build() {
    return ResellerBannerUiState(banner: _args);
  }

  /// Abre el selector del sistema y, si el usuario elige una imagen, la sube.
  /// Si cancela: no muestra error, vuelve al estado anterior.
  Future<void> pickAndUpload() async {
    state = state.copyWith(clearError: true, permissionDenied: false, phase: ResellerBannerPhase.idle);

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
    } catch (e) {
      // El selector no se pudo abrir: típicamente acceso denegado/limitado en
      // dispositivos antiguos. Mensaje amable con opción de ajustes.
      state = state.copyWith(
        phase: ResellerBannerPhase.error,
        permissionDenied: true,
        errorMessage: 'No pudimos abrir tus fotos. Revisa los permisos de FLYmovil en Ajustes.',
      );
      return;
    }

    if (picked == null) {
      // Cancelado: sin error, estado anterior intacto.
      return;
    }

    await _uploadFile(picked.path);
  }

  /// Reintenta la última operación de subida no es posible sin re-elegir, así
  /// que "Reintentar" vuelve a abrir el selector.
  Future<void> retry() => pickAndUpload();

  Future<void> _uploadFile(String path) async {
    // Validación de tamaño en el celular (≤5MB) antes de subir, con mensaje
    // claro; el servidor igual valida.
    final file = File(path);
    try {
      final length = await file.length();
      if (length > 5 * 1024 * 1024) {
        state = state.copyWith(
          phase: ResellerBannerPhase.error,
          errorMessage: 'La imagen pesa más de 5 MB. Elige una más liviana.',
        );
        await _deleteTemp(file);
        return;
      }
    } catch (_) {
      // Si no se puede medir, se deja que el servidor valide.
    }

    state = state.copyWith(phase: ResellerBannerPhase.uploading, clearError: true, permissionDenied: false);

    final Result<ResellerBannerResult> result = await _repo.uploadBanner(state.banner.catalogId, path);
    await _deleteTemp(file);

    switch (result) {
      case Ok<ResellerBannerResult>(:final value):
        state = state.copyWith(
          phase: ResellerBannerPhase.idle,
          clearError: true,
          banner: state.banner.copyWith(
            ownBannerUrl: value.ogImageUrl,
            shareLink: value.enlace ?? state.banner.shareLink,
          ),
        );
      case Err<ResellerBannerResult>(:final failure):
        state = state.copyWith(
          phase: ResellerBannerPhase.error,
          errorMessage: _messageFor(failure),
        );
    }
  }

  /// Quita el banner propio (vuelve a verse la imagen del proveedor).
  Future<void> removeBanner() async {
    state = state.copyWith(phase: ResellerBannerPhase.uploading, clearError: true);
    final Result<ResellerBannerResult> result = await _repo.deleteBanner(state.banner.catalogId);
    switch (result) {
      case Ok<ResellerBannerResult>(:final value):
        state = state.copyWith(
          phase: ResellerBannerPhase.idle,
          clearError: true,
          banner: state.banner.copyWith(
            clearOwnBanner: true,
            shareLink: value.enlace ?? state.banner.shareLink,
          ),
        );
      case Err<ResellerBannerResult>(:final failure):
        state = state.copyWith(
          phase: ResellerBannerPhase.error,
          errorMessage: _messageFor(failure),
        );
    }
  }

  Future<void> _deleteTemp(File file) async {
    // No dejar copias temporales de la foto en el almacenamiento del celular.
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Mejor esfuerzo; si falla no es crítico.
    }
  }

  String _messageFor(Failure failure) {
    if (failure is NetworkFailure) {
      return 'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.';
    }
    return failure.message;
  }
}

final resellerBannerControllerProvider =
    NotifierProvider.family<ResellerBannerController, ResellerBannerUiState, ResellerBannerState>(
      ResellerBannerController.new,
    );
