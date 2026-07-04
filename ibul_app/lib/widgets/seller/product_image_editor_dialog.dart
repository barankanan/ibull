import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
import '../../services/product_image_background_removal_service.dart';
import '../../utils/product_image_composer.dart';
import 'product_square_cropper.dart';

class ProductImageDownloadException implements Exception {
  @override
  String toString() => 'Bu görsel düzenleme için indirilemedi.';
}

Future<Uint8List> loadProductImageBytes({
  XFile? file,
  String? imageUrl,
}) async {
  if (file != null) {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('Görsel dosyası boş.');
    }
    return bytes;
  }

  final url = imageUrl?.trim();
  if (url == null || url.isEmpty) {
    throw StateError('Düzenlenecek görsel bulunamadı.');
  }

  final uri = Uri.tryParse(url);
  if (uri == null) {
    throw ProductImageDownloadException();
  }

  final response = await http.get(uri);
  if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
    throw ProductImageDownloadException();
  }
  return response.bodyBytes;
}

Future<Uint8List?> showProductImageEditorDialog(
  BuildContext context, {
  required Uint8List initialBytes,
}) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ProductImageEditorDialog(initialBytes: initialBytes),
  );
}

class ProductImageEditorDialog extends StatefulWidget {
  const ProductImageEditorDialog({super.key, required this.initialBytes});

  final Uint8List initialBytes;

  @override
  State<ProductImageEditorDialog> createState() =>
      _ProductImageEditorDialogState();
}

class _ProductImageEditorDialogState extends State<ProductImageEditorDialog> {
  static const Duration _previewDebounce = Duration(milliseconds: 350);
  static const double _previewCapturePixelRatio = 1.0;
  static const double _finalCapturePixelRatio = 3.0;

  final GlobalKey _cropperKey = GlobalKey();
  final GlobalKey<ProductSquareCropperState> _squareCropperKey =
      GlobalKey<ProductSquareCropperState>();
  final ProductImageBackgroundRemovalService _backgroundRemovalService =
      ProductImageBackgroundRemovalService();
  final ValueNotifier<Uint8List?> _previewBytesNotifier =
      ValueNotifier<Uint8List?>(null);
  final ValueNotifier<bool> _previewLoadingNotifier = ValueNotifier<bool>(false);

  Uint8List? _editorBytes;

  ProductImageBackgroundChoice _backgroundChoice =
      ProductImageBackgroundChoice.white;
  Color _customBackgroundColor = const Color(0xFFFFFFFF);
  double _bgRemovalTolerance = 50;

  bool _isPreparingEditor = true;
  bool _isRemovingBackground = false;
  bool _isFinishing = false;
  bool _advancedExpanded = false;
  bool _previewRefreshPending = false;

  Timer? _previewDebounceTimer;
  int _previewRequestId = 0;

  @override
  void initState() {
    super.initState();
    _prepareEditorImage();
  }

  @override
  void dispose() {
    _previewDebounceTimer?.cancel();
    _previewBytesNotifier.dispose();
    _previewLoadingNotifier.dispose();
    super.dispose();
  }

  Future<void> _prepareEditorImage() async {
    setState(() => _isPreparingEditor = true);
    try {
      final Uint8List prepared =
          await ProductImageComposer.prepareEditorImageBytes(
        widget.initialBytes,
      );
      if (!mounted) return;
      setState(() {
        _editorBytes = prepared;
        _isPreparingEditor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _editorBytes = widget.initialBytes;
        _isPreparingEditor = false;
      });
    }
  }

  Future<void> _prepareEditorFromBytes(Uint8List bytes) async {
    setState(() {
      _isPreparingEditor = true;
      _previewBytesNotifier.value = null;
    });
    try {
      final Uint8List prepared =
          await ProductImageComposer.prepareEditorImageBytes(bytes);
      if (!mounted) return;
      setState(() {
        _editorBytes = prepared;
        _isPreparingEditor = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _editorBytes = bytes;
        _isPreparingEditor = false;
      });
    }
  }

  void _onCropperReady() {
    _squareCropperKey.currentState?.fillCrop();
    _schedulePreviewRefresh();
  }

  void _schedulePreviewRefresh({bool immediate = false}) {
    _previewDebounceTimer?.cancel();
    if (immediate) {
      unawaited(_refreshPreview());
      return;
    }
    _previewDebounceTimer = Timer(_previewDebounce, () {
      unawaited(_refreshPreview());
    });
  }

  Future<void> _refreshPreview() async {
    if (!mounted || _isPreparingEditor || _editorBytes == null) return;
    if (_previewRefreshPending) return;

    final int requestId = ++_previewRequestId;
    _previewRefreshPending = true;
    _previewLoadingNotifier.value = true;

    try {
      await Future<void>.delayed(Duration.zero);
      if (!mounted || requestId != _previewRequestId) return;

      final Uint8List? cropped = await ProductSquareCropper.capture(
        cropperKey: _cropperKey,
        pixelRatio: _previewCapturePixelRatio,
      );
      if (cropped == null || !mounted || requestId != _previewRequestId) {
        return;
      }

      final Uint8List preview = ProductImageComposer.finalizeProductImage(
        croppedBytes: cropped,
        background: _backgroundChoice,
        customColor: _customBackgroundColor,
        targetSize: ProductImageComposer.previewSnapshotSize,
      );
      if (!mounted || requestId != _previewRequestId) return;
      _previewBytesNotifier.value = preview;
    } catch (_) {
      // Önizleme isteğe bağlı; cropper henüz hazır olmayabilir.
    } finally {
      if (mounted && requestId == _previewRequestId) {
        _previewLoadingNotifier.value = false;
        _previewRefreshPending = false;
      }
    }
  }

  Future<void> _removeBackground() async {
    if (_isRemovingBackground || _editorBytes == null) return;
    setState(() => _isRemovingBackground = true);
    try {
      final Uint8List source = _editorBytes!;
      final Uint8List result = await _backgroundRemovalService.removeBackground(
        source,
        tolerance: _bgRemovalTolerance,
      );
      if (!mounted) return;
      await _prepareEditorFromBytes(result);
      if (!mounted) return;
      _showMessage('Arka plan temizlendi. Konumu ayarlayıp Bitti diyebilirsiniz.');
    } on ProductImageBackgroundRemovalException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isRemovingBackground = false);
    }
  }

  Future<void> _pickCustomColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) => _SimpleColorPickerDialog(
        initial: _customBackgroundColor,
      ),
    );
    if (color == null || !mounted) return;
    setState(() {
      _customBackgroundColor = color;
      _backgroundChoice = ProductImageBackgroundChoice.custom;
    });
    _schedulePreviewRefresh();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _finish() async {
    if (_isFinishing || _isPreparingEditor || _editorBytes == null) return;
    setState(() => _isFinishing = true);
    try {
      final Uint8List? cropped = await ProductSquareCropper.capture(
        cropperKey: _cropperKey,
        pixelRatio: _finalCapturePixelRatio,
      );
      if (cropped == null) {
        if (mounted) {
          _showMessage('Görsel kırpılamadı. Lütfen tekrar deneyin.');
        }
        return;
      }
      final Uint8List output = ProductImageComposer.finalizeProductImage(
        croppedBytes: cropped,
        background: _backgroundChoice,
        customColor: _customBackgroundColor,
      );
      if (!mounted) return;
      Navigator.of(context).pop(output);
    } catch (_) {
      if (mounted) {
        _showMessage('Görsel kaydedilemedi. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  ({double width, double height}) _cropperSize(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    const aspectRatio = 1.0;
    const uiOverhead = 220.0;
    final wide = screenSize.width >= 900;

    double dialogWidth = wide
        ? (screenSize.width > 1100 ? 900.0 : screenSize.width * 0.82)
        : (screenSize.width > 950 ? 850 : screenSize.width * 0.92);

    if (dialogWidth > screenSize.width * 0.95) {
      dialogWidth = screenSize.width * 0.95;
    }

    double contentHeight = (wide ? dialogWidth * 0.55 : dialogWidth) / aspectRatio;
    final maxHeight = screenSize.height * 0.72;

    if (contentHeight + uiOverhead > maxHeight) {
      contentHeight = maxHeight - uiOverhead;
      if (!wide) {
        dialogWidth = contentHeight * aspectRatio;
      }
    }

    if (dialogWidth < 300) dialogWidth = 300;
    if (contentHeight < 240) contentHeight = 240;

    return (width: dialogWidth, height: contentHeight);
  }

  Widget _buildCropperLoading(double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(height: 12),
            Text(
              'Görsel hazırlanıyor...',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCropper(double width, double height) {
    if (_isPreparingEditor || _editorBytes == null) {
      return _buildCropperLoading(width, height);
    }

    final int cacheSize = (width * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(256, ProductImageComposer.editorMaxEdge);

    return SizedBox(
      width: width,
      height: height,
      child: ProductSquareCropper(
        key: _squareCropperKey,
        cropperKey: _cropperKey,
        onReady: _onCropperReady,
        image: Image.memory(
          _editorBytes!,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          cacheWidth: cacheSize,
          cacheHeight: cacheSize,
        ),
      ),
    );
  }

  Widget _buildFitToolbar() {
    final bool cropperBusy = _isPreparingEditor || _editorBytes == null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: cropperBusy
              ? null
              : () => _squareCropperKey.currentState?.fitInside(),
          icon: const Icon(Icons.fit_screen_outlined, size: 16),
          label: const Text('Sığdır'),
        ),
        OutlinedButton.icon(
          onPressed: cropperBusy
              ? null
              : () => _squareCropperKey.currentState?.fillCrop(),
          icon: const Icon(Icons.crop_square_outlined, size: 16),
          label: const Text('Doldur'),
        ),
        OutlinedButton.icon(
          onPressed: cropperBusy
              ? null
              : () => _squareCropperKey.currentState?.centerImage(),
          icon: const Icon(Icons.center_focus_strong_outlined, size: 16),
          label: const Text('Ortala'),
        ),
        OutlinedButton.icon(
          onPressed: cropperBusy || _isRemovingBackground
              ? null
              : _removeBackground,
          icon: _isRemovingBackground
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.layers_clear_outlined, size: 16),
          label: Text(
            _isRemovingBackground ? 'Arka plan siliniyor...' : 'Arka Plan Sil',
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Önizleme', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: ValueListenableBuilder<bool>(
            valueListenable: _previewLoadingNotifier,
            builder: (context, isLoading, _) {
              return ValueListenableBuilder<Uint8List?>(
                valueListenable: _previewBytesNotifier,
                builder: (context, previewBytes, child) {
                  if (previewBytes != null) {
                    return Image.memory(previewBytes, fit: BoxFit.contain);
                  }
                  if (isLoading || _isPreparingEditor) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Önizleme hazırlanıyor',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const Center(
                    child: Text(
                      'Önizleme hazırlanıyor',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedPanel() {
    return ExpansionTile(
      initiallyExpanded: _advancedExpanded,
      onExpansionChanged: (value) => setState(() => _advancedExpanded = value),
      title: const Text(
        'Gelişmiş seçenekler',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Tolerans'),
                  Expanded(
                    child: Slider(
                      value: _bgRemovalTolerance,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: _bgRemovalTolerance.round().toString(),
                      onChanged: (value) =>
                          setState(() => _bgRemovalTolerance = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Arka plan rengi',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _bgChip('Beyaz', ProductImageBackgroundChoice.white),
                  _bgChip('Açık gri', ProductImageBackgroundChoice.lightGray),
                  _bgChip('Siyah', ProductImageBackgroundChoice.black),
                  _bgChip('Şeffaf', ProductImageBackgroundChoice.transparent),
                  ActionChip(
                    label: const Text('Özel renk'),
                    avatar: CircleAvatar(
                      backgroundColor: _customBackgroundColor,
                      radius: 8,
                    ),
                    onPressed: _pickCustomColor,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _isPreparingEditor
                      ? null
                      : () => _schedulePreviewRefresh(immediate: true),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Önizlemeyi güncelle'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bgChip(String label, ProductImageBackgroundChoice choice) {
    return ChoiceChip(
      label: Text(label),
      selected: _backgroundChoice == choice,
      onSelected: (_) {
        setState(() => _backgroundChoice = choice);
        _schedulePreviewRefresh();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cropSize = _cropperSize(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: cropSize.width + 48,
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Görseli Kırp',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ürün kartlarında en iyi görünüm için görseli kare alana yerleştirin.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildCropper(
                                cropSize.width * 0.62,
                                cropSize.height,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPreviewTile(),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: 280,
                                  child: _buildAdvancedPanel(),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Center(
                              child: _buildCropper(
                                cropSize.width,
                                cropSize.height,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPreviewTile(),
                            _buildAdvancedPanel(),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              _buildFitToolbar(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isFinishing ? null : () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isFinishing || _isPreparingEditor
                        ? null
                        : _finish,
                    child: _isFinishing
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Görsel hazırlanıyor...'),
                            ],
                          )
                        : const Text('Bitti'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleColorPickerDialog extends StatelessWidget {
  const _SimpleColorPickerDialog({required this.initial});

  final Color initial;

  static const _swatches = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFF3F4F6),
    Color(0xFFE5E7EB),
    Color(0xFF111827),
    Color(0xFFFEF3C7),
    Color(0xFFDBEAFE),
    Color(0xFFFCE7F3),
    Color(0xFFD1FAE5),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Özel renk seç'),
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: _swatches
            .map(
              (color) => InkWell(
                onTap: () => Navigator.pop(context, color),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(
                      color: color == initial ? AppColors.primary : Colors.grey,
                      width: color == initial ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
      ],
    );
  }
}

XFile editedBytesToXFile(Uint8List bytes, {int? slotIndex}) {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final isPng = ProductImageComposer.bytesLookLikePng(bytes);
  final ext = isPng ? 'png' : 'jpg';
  final name = slotIndex == null
      ? 'product_edited_$stamp.$ext'
      : 'product_edited_${slotIndex}_$stamp.$ext';
  return XFile.fromData(
    bytes,
    name: name,
    mimeType: isPng ? 'image/png' : 'image/jpeg',
  );
}
