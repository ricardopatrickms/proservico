import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Seletor de imagens com permissões explícitas (estilo Telegram).
///
/// - **Galeria**: pede acesso à fototeca (selecionar fotos / acesso total / negar).
/// - **Câmera**: pede permissão de câmera antes de abrir.
class AppImagePicker {
  AppImagePicker._();

  static final ImagePicker _picker = ImagePicker();

  static bool get isCameraAvailable =>
      !kIsWeb && _picker.supportsImageSource(ImageSource.camera);

  static String get cameraUnavailableMessage {
    if (!kIsWeb && Platform.isIOS && !isCameraAvailable) {
      return 'A câmera não está disponível no simulador. Use Galeria ou teste em um iPhone físico.';
    }
    return 'Câmera indisponível neste aparelho. Use a Galeria.';
  }

  static Future<XFile?> pickImage({
    required ImageSource source,
    int imageQuality = 85,
    double? maxWidth,
  }) async {
    if (source == ImageSource.camera) {
      if (!isCameraAvailable) {
        throw CameraUnavailableException(cameraUnavailableMessage);
      }
      final allowed = await _ensureCameraPermission();
      if (!allowed.granted) {
        throw MediaPermissionDeniedException(
          allowed.permanentlyDenied
              ? 'Permissão da câmera negada. Toque em Ajustes para permitir o acesso.'
              : 'Permissão da câmera negada.',
          permanentlyDenied: allowed.permanentlyDenied,
        );
      }
    } else {
      final allowed = await _ensurePhotosPermission();
      if (!allowed.granted) {
        throw MediaPermissionDeniedException(
          allowed.permanentlyDenied
              ? 'Permissão da galeria negada. Toque em Ajustes para permitir o acesso.'
              : 'Permissão da galeria negada.',
          permanentlyDenied: allowed.permanentlyDenied,
        );
      }
    }

    return _picker.pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      requestFullMetadata: true,
    );
  }

  static Future<_PermissionResult> _ensurePhotosPermission() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      return const _PermissionResult(granted: true);
    }

    var status = await Permission.photos.status;
    if (_photosAllowed(status)) return const _PermissionResult(granted: true);

    if (status.isPermanentlyDenied) {
      return const _PermissionResult(granted: false, permanentlyDenied: true);
    }

    status = await Permission.photos.request();
    if (_photosAllowed(status)) return const _PermissionResult(granted: true);

    return _PermissionResult(
      granted: false,
      permanentlyDenied: status.isPermanentlyDenied,
    );
  }

  static bool _photosAllowed(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  static Future<_PermissionResult> _ensureCameraPermission() async {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      return const _PermissionResult(granted: true);
    }

    var status = await Permission.camera.status;
    if (status.isGranted) return const _PermissionResult(granted: true);

    if (status.isPermanentlyDenied) {
      return const _PermissionResult(granted: false, permanentlyDenied: true);
    }

    status = await Permission.camera.request();
    if (status.isGranted) return const _PermissionResult(granted: true);

    return _PermissionResult(
      granted: false,
      permanentlyDenied: status.isPermanentlyDenied,
    );
  }
}

class _PermissionResult {
  final bool granted;
  final bool permanentlyDenied;

  const _PermissionResult({
    required this.granted,
    this.permanentlyDenied = false,
  });
}

class CameraUnavailableException implements Exception {
  final String message;
  const CameraUnavailableException(this.message);

  @override
  String toString() => message;
}

class MediaPermissionDeniedException implements Exception {
  final String message;
  final bool permanentlyDenied;

  const MediaPermissionDeniedException(
    this.message, {
    this.permanentlyDenied = false,
  });

  @override
  String toString() => message;
}
