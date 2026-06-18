import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../data/support_category_catalog.dart';
import '../models/customer_support_models.dart';
import '../models/support_pending_attachment.dart';
import '../services/customer_support_service.dart';

class CustomerSupportTicketForm extends StatefulWidget {
  const CustomerSupportTicketForm({
    super.key,
    required this.formSectionKey,
    required this.attachmentSectionKey,
    this.selectedCategory,
    this.selectedSubcategory,
    this.onSubmitted,
  });

  final GlobalKey formSectionKey;
  final GlobalKey attachmentSectionKey;
  final SupportCategoryOption? selectedCategory;
  final String? selectedSubcategory;
  final VoidCallback? onSubmitted;

  @override
  State<CustomerSupportTicketForm> createState() =>
      _CustomerSupportTicketFormState();
}

class _CustomerSupportTicketFormState extends State<CustomerSupportTicketForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _referenceController = TextEditingController();
  final _picker = ImagePicker();

  bool _showAdvanced = false;
  bool _submitting = false;
  bool _uploadingImages = false;
  CustomerSupportPriority _priority = CustomerSupportPriority.normal;
  CustomerSupportContactPreference _contactPreference =
      CustomerSupportContactPreference.inApp;
  String? _localSubcategory;
  final List<SupportPendingAttachment> _pendingAttachments = [];

  @override
  void didUpdateWidget(covariant CustomerSupportTicketForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSubcategory != null &&
        widget.selectedSubcategory != oldWidget.selectedSubcategory) {
      _localSubcategory = widget.selectedSubcategory;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = widget.selectedSubcategory!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    if (_pendingAttachments.length >= kMaxSupportAttachments) {
      _showSnack('En fazla $kMaxSupportAttachments görsel ekleyebilirsin.');
      return;
    }

    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final fileName = file.name.isNotEmpty ? file.name : 'ekran-goruntusu.jpg';
    final mimeType = supportAttachmentMimeFromName(fileName) ?? 'image/jpeg';

    if (!mounted) return;
    setState(() {
      _pendingAttachments.add(
        SupportPendingAttachment(
          bytes: bytes,
          fileName: fileName,
          mimeType: mimeType,
        ),
      );
    });
  }

  void removeAttachment(int index) {
    setState(() => _pendingAttachments.removeAt(index));
  }

  Future<void> submit() async {
    if (!_formKey.currentState!.validate()) return;

    final category = widget.selectedCategory;
    if (category == null) {
      _showSnack('Lütfen bir konu seç.');
      return;
    }

    final subcategory =
        _localSubcategory ??
        widget.selectedSubcategory ??
        category.subcategories.first;

    setState(() {
      _submitting = true;
      _uploadingImages = _pendingAttachments.isNotEmpty;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final ticket = await CustomerSupportService.instance.createTicket(
        CreateCustomerSupportTicketInput(
          category: category.id,
          subcategory: subcategory,
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          priority: _priority,
          contactPreference: _contactPreference,
          relatedReference: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          userEmail: user?.email,
        ),
      );

      final uploadErrors = <String>[];
      for (final attachment in _pendingAttachments) {
        try {
          await CustomerSupportService.instance.uploadAttachment(
            ticketId: ticket.id,
            fileName: attachment.fileName,
            mimeType: attachment.mimeType,
            bytes: attachment.bytes,
          );
        } catch (error) {
          uploadErrors.add(error.toString().replaceFirst('Exception: ', ''));
        }
      }

      if (!mounted) return;

      if (uploadErrors.isEmpty) {
        _showSnack(
          'Talebin alındı. İBUL ekibi en kısa sürede cevaplayacak.',
          success: true,
        );
      } else {
        _showSnack(
          'Talebin oluşturuldu ancak görsel yüklenemedi.',
        );
      }

      _titleController.clear();
      _messageController.clear();
      _referenceController.clear();
      setState(() {
        _pendingAttachments.clear();
        _showAdvanced = false;
        _localSubcategory = null;
      });
      widget.onSubmitted?.call();
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        'Talep gönderilemedi. Lütfen bağlantını kontrol edip tekrar dene.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _uploadingImages = false;
        });
      }
    }
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? const Color(0xFF059669) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AppState>().isLoggedIn;
    if (!loggedIn) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Talep göndermek için giriş yapmalısın.'),
        ),
      );
    }

    final category = widget.selectedCategory;

    return KeyedSubtree(
      key: widget.formSectionKey,
      child: _card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Destek talebi',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  category == null
                      ? 'Önce yukarıdan bir konu seç.'
                      : 'Seçili konu: ${category.title}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Başlık',
                    hintText: 'Kısaca ne oldu?',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Başlık gerekli' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  minLines: 4,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Mesaj',
                    hintText:
                        'Sorunu detaylı anlat. Ekran görüntüsü varsa ekleyebilirsin.',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Mesaj gerekli';
                    if (text.length < 10) return 'En az 10 karakter yaz';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildAttachmentSection(),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                  child: Row(
                    children: [
                      Icon(
                        _showAdvanced
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Daha fazla detay ekle',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showAdvanced) ...[
                  const SizedBox(height: 12),
                  if (category != null)
                    DropdownButtonFormField<String>(
                      initialValue: _localSubcategory ?? widget.selectedSubcategory,
                      decoration: const InputDecoration(
                        labelText: 'Alt başlık',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: category.subcategories
                          .map(
                            (item) => DropdownMenuItem(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _localSubcategory = value),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Sipariş no / mağaza / ürün',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CustomerSupportContactPreference>(
                    initialValue: _contactPreference,
                    decoration: const InputDecoration(
                      labelText: 'İletişim tercihi',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: CustomerSupportContactPreference.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _contactPreference = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CustomerSupportPriority>(
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Aciliyet',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: CustomerSupportPriority.values
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _priority = value);
                    },
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withValues(
                                alpha: _uploadingImages ? 1 : 0.9,
                              ),
                            ),
                          )
                        : const Text(
                            'Talebi Gönder',
                            style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildAttachmentSection() {
    return Container(
      key: widget.attachmentSectionKey,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Görsel ekle',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Ekran görüntüsü veya fotoğraf ekleyerek sorunu daha hızlı anlatabilirsin.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (_pendingAttachments.isNotEmpty)
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingAttachments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _pendingAttachments[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          item.bytes,
                          width: 78,
                          height: 78,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => removeAttachment(index),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
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
                },
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pendingAttachments.length >= kMaxSupportAttachments
                ? null
                : pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(
              _pendingAttachments.isEmpty
                  ? 'Görsel Seç'
                  : '${_pendingAttachments.length}/$kMaxSupportAttachments',
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
