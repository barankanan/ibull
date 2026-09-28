import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../core/constants.dart';
import '../../../widgets/image_cropper_widget.dart';
import '../models/vehicle_enums.dart';

class VehicleDocumentDraft {
  const VehicleDocumentDraft({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

Future<VehicleDocumentDraft?> showVehicleDocumentPreview({
  required BuildContext context,
  required VehicleDocumentType type,
  required Uint8List bytes,
  required String fileName,
}) {
  return showModalBottomSheet<VehicleDocumentDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => _VehicleDocumentPreviewSheet(
      type: type,
      bytes: bytes,
      fileName: fileName,
    ),
  );
}

class _VehicleDocumentPreviewSheet extends StatefulWidget {
  const _VehicleDocumentPreviewSheet({
    required this.type,
    required this.bytes,
    required this.fileName,
  });

  final VehicleDocumentType type;
  final Uint8List bytes;
  final String fileName;

  @override
  State<_VehicleDocumentPreviewSheet> createState() =>
      _VehicleDocumentPreviewSheetState();
}

class _VehicleDocumentPreviewSheetState
    extends State<_VehicleDocumentPreviewSheet> {
  late Uint8List _bytes = widget.bytes;
  late String _fileName = widget.fileName;
  Uint8List? _original;

  bool get _isImage {
    final name = _fileName.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp');
  }

  Future<void> _crop() async {
    if (!_isImage) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ImageCropperWidget(
        imageData: _bytes,
        aspectRatio: 1.586,
        title: '${widget.type.labelTr} kırp',
        helpText: 'Kimlik/ehliyet kartını çerçeveye yerleştirin.',
        onCropped: (cropped) {
          setState(() {
            _original ??= Uint8List.fromList(_bytes);
            _bytes = cropped;
            if (!_fileName.toLowerCase().contains('.')) {
              _fileName = '$_fileName.jpg';
            }
          });
        },
      ),
    );
  }

  void _rotate() {
    if (!_isImage) return;
    final decoded = img.decodeImage(_bytes);
    if (decoded == null) return;
    final rotated = img.copyRotate(decoded, angle: 90);
    setState(() {
      _original ??= Uint8List.fromList(_bytes);
      _bytes = Uint8List.fromList(img.encodeJpg(rotated, quality: 85));
      if (!_fileName.toLowerCase().endsWith('.jpg') &&
          !_fileName.toLowerCase().endsWith('.jpeg')) {
        _fileName = '${_fileName.replaceAll(RegExp(r'\.[^.]+$'), '')}.jpg';
      }
    });
  }

  void _reset() {
    if (_original == null) return;
    setState(() {
      _bytes = _original!;
      _original = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.86;
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            Text(
              widget.type.labelTr,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isImage
                      ? Image.memory(_bytes, fit: BoxFit.contain)
                      : const Center(
                          child: Icon(Icons.picture_as_pdf_outlined, size: 48),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Yeniden Seç'),
                ),
                if (_isImage)
                  OutlinedButton(onPressed: _crop, child: const Text('Kırp')),
                if (_isImage)
                  OutlinedButton(onPressed: _rotate, child: const Text('Döndür')),
                if (_original != null)
                  TextButton(onPressed: _reset, child: const Text('Sıfırla')),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  VehicleDocumentDraft(bytes: _bytes, fileName: _fileName),
                ),
                child: const Text('BU BELGEYİ KULLAN'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
