import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants.dart';
import '../models/support_pending_attachment.dart';

class SupportChatComposer extends StatelessWidget {
  const SupportChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.attachments,
    required this.onSend,
    required this.onPickImage,
    required this.onRemoveAttachment,
    this.disabledHint,
    this.embedded = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final List<SupportPendingAttachment> attachments;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final ValueChanged<int> onRemoveAttachment;
  final String? disabledHint;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: embedded
          ? BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            )
          : BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!enabled && disabledHint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  disabledHint!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
            if (attachments.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: attachments.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = attachments[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            item.bytes,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: enabled ? () => onRemoveAttachment(index) : null,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: enabled &&
                          attachments.length < kMaxSupportAttachments &&
                          !sending
                      ? onPickImage
                      : null,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  color: AppColors.primary,
                  tooltip: 'Görsel ekle',
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled && !sending,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: enabled && !sending ? (_) => onSend() : null,
                    decoration: InputDecoration(
                      hintText: 'Mesajını yaz...',
                      filled: true,
                      fillColor: const Color(0xFFF5F4FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: enabled ? AppColors.primary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    onTap: enabled && !sending ? onSend : null,
                    borderRadius: BorderRadius.circular(22),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> pickSupportChatImage({
  required ImagePicker picker,
  required List<SupportPendingAttachment> current,
  required void Function(SupportPendingAttachment) onPicked,
  required void Function(String) onError,
}) async {
  if (current.length >= kMaxSupportAttachments) {
    onError('En fazla $kMaxSupportAttachments görsel ekleyebilirsin.');
    return;
  }

  final file = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 85,
  );
  if (file == null) return;

  final bytes = await file.readAsBytes();
  final fileName = file.name.isNotEmpty ? file.name : 'ekran-goruntusu.jpg';
  final mimeType = supportAttachmentMimeFromName(fileName) ?? 'image/jpeg';

  onPicked(
    SupportPendingAttachment(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    ),
  );
}
