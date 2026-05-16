import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../utils/pick_image_file.dart';
import '../../../utils/xfile_image_provider.dart';
import '../../../widgets/optimized_image.dart';
import 'product_quick_edit_models.dart';

class ProductQuickEditRow extends StatefulWidget {
  const ProductQuickEditRow({
    super.key,
    required this.draft,
    required this.categoryLabel,
    required this.imageColumnWidth,
    required this.priceColumnWidth,
    required this.stockColumnWidth,
    required this.statusColumnWidth,
    required this.actionsColumnWidth,
    required this.onChanged,
    required this.onSave,
    required this.onCancel,
  });

  final ProductQuickEditDraft draft;
  final String categoryLabel;
  final double imageColumnWidth;
  final double priceColumnWidth;
  final double stockColumnWidth;
  final double statusColumnWidth;
  final double actionsColumnWidth;
  final ValueChanged<ProductQuickEditDraft> onChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  State<ProductQuickEditRow> createState() => _ProductQuickEditRowState();
}

class _ProductQuickEditRowState extends State<ProductQuickEditRow> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name);
    _priceController = TextEditingController(text: widget.draft.priceText);
    _stockController = TextEditingController(text: widget.draft.stockText);
    _nameController.addListener(_handleTextChanged);
    _priceController.addListener(_handleTextChanged);
    _stockController.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(covariant ProductQuickEditRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.name != _nameController.text) {
      _nameController.text = widget.draft.name;
    }
    if (widget.draft.priceText != _priceController.text) {
      _priceController.text = widget.draft.priceText;
    }
    if (widget.draft.stockText != _stockController.text) {
      _stockController.text = widget.draft.stockText;
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleTextChanged);
    _priceController.removeListener(_handleTextChanged);
    _stockController.removeListener(_handleTextChanged);
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    widget.onChanged(
      widget.draft.copyWith(
        name: _nameController.text,
        priceText: _priceController.text,
        stockText: _stockController.text,
        errorMessage: null,
        successMessage: null,
      ),
    );
  }

  Future<void> _pickImage() async {
    if (widget.draft.isSaving) return;
    try {
      final picked = await pickImageFile();
      if (picked == null) return;
      final XFile image = XFile.fromData(
        picked.bytes,
        name: picked.name,
        mimeType: 'image/jpeg',
      );
      widget.onChanged(
        widget.draft.copyWith(
          selectedImageFile: image,
          errorMessage: null,
          successMessage: null,
        ),
      );
    } catch (_) {}
  }

  InputDecoration _inputDecoration({String? hintText, String? prefixText}) {
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(9)),
        borderSide: BorderSide(color: Color(0xFF0F766E), width: 1.2),
      ),
    );
  }

  Widget _buildImageBox() {
    final localImage = widget.draft.selectedImageFile;
    final previewImageUrl = widget.draft.previewImageUrl;
    final hasImage =
        localImage != null || (previewImageUrl?.isNotEmpty ?? false);

    Widget child;
    if (localImage != null) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: xFileImageProvider(localImage),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else if (hasImage) {
      child = OptimizedImage(
        imageUrlOrPath: previewImageUrl!,
        fit: BoxFit.cover,
        cacheWidth: 160,
        cacheHeight: 160,
        errorWidget: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: Colors.grey.shade500),
            const SizedBox(height: 4),
            Text(
              'Tekrar seç',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    } else {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade600),
          const SizedBox(height: 6),
          Text(
            'Görsel Ekle',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: widget.imageColumnWidth,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageText(String? value, Color color) {
    if (value == null || value.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final hasError =
        draft.errorMessage != null && draft.errorMessage!.isNotEmpty;
    final hasSuccess =
        draft.successMessage != null && draft.successMessage!.isNotEmpty;
    final backgroundColor = hasError
        ? const Color(0xFFFEF2F2)
        : hasSuccess
        ? const Color(0xFFF0FDF4)
        : draft.isDirty
        ? const Color(0xFFF8FAFC)
        : Colors.white;
    final borderColor = hasError
        ? const Color(0xFFFCA5A5)
        : hasSuccess
        ? const Color(0xFF86EFAC)
        : draft.isDirty
        ? const Color(0xFFBFDBFE)
        : Colors.grey.shade100;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildImageBox(),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameController,
                  enabled: !draft.isSaving,
                  decoration: _inputDecoration(hintText: 'Ürün adı'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      'SKU: ${draft.originalProduct.sku}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (draft.isDirty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Değiştirildi',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                  ],
                ),
                if (draft.hasPendingImageSelection) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Gorsel secimi hazir bekler. Hizli kaydet sirasinda gorsel yuklenmez.',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.categoryLabel,
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: widget.priceColumnWidth,
            child: TextField(
              controller: _priceController,
              enabled: !draft.isSaving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: _inputDecoration(prefixText: '₺ '),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: widget.stockColumnWidth,
            child: TextField(
              controller: _stockController,
              enabled: !draft.isSaving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _inputDecoration(hintText: '0'),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: widget.statusColumnWidth,
            child: DropdownButtonFormField<String>(
              initialValue: draft.statusOptions.contains(draft.status)
                  ? draft.status
                  : draft.statusOptions.first,
              items: draft.statusOptions
                  .map(
                    (status) => DropdownMenuItem<String>(
                      value: status,
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: draft.isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      widget.onChanged(
                        draft.copyWith(
                          status: value,
                          errorMessage: null,
                          successMessage: null,
                        ),
                      );
                    },
              decoration: _inputDecoration(),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: widget.actionsColumnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: draft.isSaving || !draft.hasPersistableChanges
                      ? null
                      : widget.onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: draft.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Kaydet',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                OutlinedButton(
                  onPressed: draft.isSaving ? null : widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text(
                    'İptal',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildMessageText(draft.errorMessage, const Color(0xFFB91C1C)),
                _buildMessageText(
                  draft.successMessage,
                  const Color(0xFF15803D),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
