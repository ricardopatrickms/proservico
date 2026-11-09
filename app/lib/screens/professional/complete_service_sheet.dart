import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/service_request.dart';
import '../../services/api_exception.dart';
import '../../services/app_image_picker.dart';
import '../../services/service_request_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/helpers.dart';

const completionChecklistItems = <String, String>{
  'service_done': 'Serviço concluído conforme combinado',
  'site_ok': 'Local deixado em ordem',
  'client_informed': 'Cliente informado da conclusão',
};

Future<ServiceRequest?> showCompleteServiceSheet({
  required BuildContext context,
  required ServiceRequest request,
}) {
  return showModalBottomSheet<ServiceRequest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _CompleteServiceSheet(request: request),
    ),
  );
}

class _CompleteServiceSheet extends StatefulWidget {
  final ServiceRequest request;

  const _CompleteServiceSheet({required this.request});

  @override
  State<_CompleteServiceSheet> createState() => _CompleteServiceSheetState();
}

class _CompleteServiceSheetState extends State<_CompleteServiceSheet> {
  static const _maxPhotos = 8;
  static const _maxPhotoBytes = 5 * 1024 * 1024;

  final _notes = TextEditingController();
  final _materials = TextEditingController();
  final Map<String, bool> _checklist = {
    for (final key in completionChecklistItems.keys) key: false,
  };
  /// null = ainda não respondeu; true = Sim; false = Não.
  bool? _materialsUsed;
  final List<XFile> _photos = [];
  bool _submitting = false;
  bool _attempted = false;

  @override
  void dispose() {
    _notes.dispose();
    _materials.dispose();
    super.dispose();
  }

  bool get _checklistOk => _checklist.values.every((checked) => checked);
  bool get _materialsAnswered => _materialsUsed != null;
  bool get _materialsListOk =>
      _materialsUsed != true || _materials.text.trim().isNotEmpty;
  bool get _materialsOk => _materialsAnswered && _materialsListOk;
  bool get _photosOk => _photos.isNotEmpty;

  Future<ImageSource?> _askPhotoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Como deseja enviar a foto?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (AppImagePicker.isCameraAvailable)
                  ListTile(
                    leading: const Icon(
                      Icons.photo_camera_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Câmera'),
                    subtitle: const Text('Tirar uma foto agora'),
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Galeria'),
                  subtitle: const Text('Selecionar imagem da galeria'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= _maxPhotos) {
      showAppSnackBar(context, 'Limite de $_maxPhotos fotos');
      return;
    }

    final source = await _askPhotoSource();
    if (source == null || !mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    try {
      final image = await AppImagePicker.pickImage(
        source: source,
        maxWidth: 1920,
      );
      if (image == null || !mounted) return;

      final bytes = await image.length();
      if (!mounted) return;
      if (bytes > _maxPhotoBytes) {
        showAppSnackBar(context, 'Cada foto deve ter no máximo 5 MB');
        return;
      }

      setState(() => _photos.add(image));
    } on CameraUnavailableException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } on MediaPermissionDeniedException catch (e) {
      if (!mounted) return;
      showMediaPermissionSnackBar(context, e);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível adicionar a foto.');
    }
  }

  Future<void> _submit() async {
    setState(() => _attempted = true);
    if (!_checklistOk || !_materialsOk || !_photosOk) {
      showAppSnackBar(
        context,
        !_checklistOk
            ? 'Marque todos os itens do checklist.'
            : !_materialsAnswered
                ? 'Responda se usou materiais: Sim ou Não.'
                : !_materialsListOk
                    ? 'Descreva os materiais usados.'
                    : 'Envie ao menos uma foto da conclusão.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final updated = await ServiceRequestService.instance.complete(
        widget.request.id,
        checklist: {
          ..._checklist,
          'materials_used': _materialsUsed!,
        },
        photoPaths: _photos.map((p) => p.path).toList(),
        notes: _notes.text,
        materials: _materialsUsed == true ? _materials.text : null,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, e.displayMessage);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, 'Não foi possível finalizar o serviço.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Finalizar serviço',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              widget.request.title,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Checklist',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...completionChecklistItems.entries.map((entry) {
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _checklist[entry.key] ?? false,
                onChanged: _submitting
                    ? null
                    : (value) {
                        setState(() => _checklist[entry.key] = value ?? false);
                      },
                title: Text(
                  entry.value,
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }),
            if (_attempted && !_checklistOk)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Marque todos os itens para continuar.',
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Usou materiais neste serviço? *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _materialsUsed,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: _submitting
                      ? null
                      : (value) {
                          setState(() => _materialsUsed = value);
                        },
                ),
                GestureDetector(
                  onTap: _submitting
                      ? null
                      : () => setState(() => _materialsUsed = true),
                  child: const Text('Sim', style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 16),
                Radio<bool>(
                  value: false,
                  groupValue: _materialsUsed,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: _submitting
                      ? null
                      : (value) {
                          setState(() {
                            _materialsUsed = value;
                            _materials.clear();
                          });
                        },
                ),
                GestureDetector(
                  onTap: _submitting
                      ? null
                      : () => setState(() {
                            _materialsUsed = false;
                            _materials.clear();
                          }),
                  child: const Text('Não', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
            if (_attempted && !_materialsAnswered)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Responda Sim ou Não.',
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            if (_materialsUsed == true) ...[
              TextField(
                controller: _materials,
                enabled: !_submitting,
                maxLines: 2,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: 'Quais materiais foram usados? *',
                  hintText: 'Ex.: parafusos, fita isolante, silicone',
                  alignLabelWithHint: true,
                  errorText: _attempted && !_materialsListOk
                      ? 'Descreva os materiais usados'
                      : null,
                ),
                onChanged: (_) {
                  if (_attempted) setState(() {});
                },
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Fotos da conclusão *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._photos.asMap().entries.map((entry) {
                  final index = entry.key;
                  final photo = entry.value;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(photo.path),
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: _submitting
                              ? null
                              : () => setState(() => _photos.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                if (_photos.length < _maxPhotos)
                  InkWell(
                    onTap: _submitting ? null : _addPhoto,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _attempted && !_photosOk
                              ? AppColors.danger
                              : AppColors.border,
                        ),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
            if (_attempted && !_photosOk)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Envie ao menos uma foto.',
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              enabled: !_submitting,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Observações (opcional)',
                hintText: 'Detalhes sobre a conclusão do serviço',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmar finalização'),
            ),
            TextButton(
              onPressed: _submitting ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}
