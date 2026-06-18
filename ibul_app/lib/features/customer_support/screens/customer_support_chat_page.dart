import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../data/support_category_catalog.dart';
import '../helpers/support_title_helpers.dart';
import '../models/customer_support_models.dart';
import '../models/support_pending_attachment.dart';
import '../services/customer_support_service.dart';
import '../widgets/support_chat_bubble.dart';
import '../widgets/support_chat_composer.dart';
import '../widgets/support_responsive_center.dart';
import '../widgets/support_status_badge.dart';

class CustomerSupportChatPage extends StatefulWidget {
  const CustomerSupportChatPage({
    super.key,
    this.ticketId,
  });

  final String? ticketId;

  @override
  State<CustomerSupportChatPage> createState() => _CustomerSupportChatPageState();
}

class _CustomerSupportChatPageState extends State<CustomerSupportChatPage> {
  final _service = CustomerSupportService.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  CustomerSupportTicketDetail? _detail;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  SupportCategoryOption? _selectedCategory;
  String? _selectedSubcategory;
  String? _activeTicketId;
  final List<SupportPendingAttachment> _pendingAttachments = [];
  final List<String> _systemNotices = [];

  bool get _isExistingTicket => widget.ticketId != null;

  @override
  void initState() {
    super.initState();
    _activeTicketId = widget.ticketId;
    if (_isExistingTicket) {
      _loadDetail();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _service.getTicketDetail(_activeTicketId!);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _selectedCategory = findSupportCategory(detail.ticket.category);
        _selectedSubcategory = detail.ticket.subcategory.isEmpty
            ? null
            : detail.ticket.subcategory;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _selectCategory(SupportCategoryOption category) {
    if (_activeTicketId != null) return;
    setState(() {
      _selectedCategory = category;
      _selectedSubcategory = null;
    });
    applySupportComposerDraft(
      _messageController,
      supportComposerDraftForCategory(category.title),
    );
    _scrollToBottom();
  }

  void _selectSubcategory(String subcategory) {
    if (_activeTicketId != null) return;
    setState(() => _selectedSubcategory = subcategory);
    applySupportComposerDraft(
      _messageController,
      supportComposerDraftForSubcategory(subcategory),
    );
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    await pickSupportChatImage(
      picker: _picker,
      current: _pendingAttachments,
      onPicked: (item) => setState(() => _pendingAttachments.add(item)),
      onError: _showSnack,
    );
  }

  Future<void> _sendMessage() async {
    final outgoing = resolveOutgoingChatMessage(
      typedText: _messageController.text,
      hasAttachments: _pendingAttachments.isNotEmpty,
    );
    if (outgoing.isEmpty) {
      _showSnack(kSupportEmptySendWarning);
      return;
    }

    if (!isSupportComposerEnabled(_detail?.ticket.status)) return;

    setState(() => _sending = true);
    try {
      if (_activeTicketId == null) {
        final meta = resolveNewTicketMeta(
          categoryId: _selectedCategory?.id,
          subcategory: _selectedSubcategory,
        );
        final user = Supabase.instance.client.auth.currentUser;

        final ticket = await _service.createTicket(
          CreateCustomerSupportTicketInput(
            category: meta.categoryId,
            subcategory: meta.subcategory,
            title: meta.title,
            message: outgoing,
            priority: CustomerSupportPriority.normal,
            contactPreference: CustomerSupportContactPreference.inApp,
            userEmail: user?.email,
          ),
        );

        _activeTicketId = ticket.id;
        final uploadErrors = await _uploadPendingAttachments(ticket.id);

        _messageController.clear();
        setState(() => _pendingAttachments.clear());

        if (uploadErrors.isEmpty) {
          setState(() {
            _systemNotices.add(
              'Talebin alındı. İBUL ekibi buradan cevap verecek.',
            );
          });
        } else {
          _showSnack('Talebin oluşturuldu ancak görsel yüklenemedi.');
        }
        await _loadDetail();
      } else {
        await _service.addUserMessage(
          ticketId: _activeTicketId!,
          message: outgoing,
        );
        final uploadErrors = await _uploadPendingAttachments(_activeTicketId!);
        _messageController.clear();
        setState(() => _pendingAttachments.clear());
        if (uploadErrors.isNotEmpty) {
          _showSnack('Mesaj gönderildi ancak görsel yüklenemedi.');
        }
        await _loadDetail();
      }
    } catch (error) {
      _showSnack(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<List<String>> _uploadPendingAttachments(String ticketId) async {
    final errors = <String>[];
    for (final attachment in _pendingAttachments) {
      try {
        await _service.uploadAttachment(
          ticketId: ticketId,
          fileName: attachment.fileName,
          mimeType: attachment.mimeType,
          bytes: attachment.bytes,
        );
      } catch (error) {
        errors.add(error.toString());
      }
    }
    return errors;
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.watch<AppState>().isLoggedIn;
    final composerEnabled =
        loggedIn && isSupportComposerEnabled(_detail?.ticket.status);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FA),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Mesajla Destek', style: TextStyle(fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          if (_detail != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: SupportStatusBadge(
                  status: _detail!.ticket.status,
                  compact: true,
                ),
              ),
            ),
        ],
      ),
      body: !loggedIn
          ? const Center(child: Text('Mesajla destek için giriş yapmalısın.'))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : SupportResponsiveCenter(
                      maxWidth: kSupportChatMaxWidth,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: _buildChatShell(
                        composerEnabled: composerEnabled,
                      ),
                    ),
    );
  }

  Widget _buildChatShell({required bool composerEnabled}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            Expanded(child: _buildChatMessages(context)),
            SupportChatComposer(
              controller: _messageController,
              enabled: composerEnabled,
              sending: _sending,
              attachments: _pendingAttachments,
              onSend: _sendMessage,
              onPickImage: _pickImage,
              onRemoveAttachment: (index) =>
                  setState(() => _pendingAttachments.removeAt(index)),
              disabledHint: composerEnabled ? null : 'Bu talep kapatıldı.',
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessages(BuildContext context) {
    final bubbleMaxWidth = MediaQuery.sizeOf(context).width > 600 ? 340.0 : 280.0;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      children: [
        if (_isExistingTicket && _detail != null)
          ..._buildExistingMessages(_detail!, bubbleMaxWidth)
        else
          ..._buildNewChatFlow(bubbleMaxWidth),
      ],
    );
  }

  List<Widget> _buildExistingMessages(
    CustomerSupportTicketDetail detail,
    double bubbleMaxWidth,
  ) {
    final ticket = detail.ticket;
    final widgets = <Widget>[];

    if (detail.messages.isEmpty) {
      widgets.add(
        SupportChatBubble(
          message: ticket.message,
          alignment: SupportBubbleAlignment.right,
          maxBubbleWidth: bubbleMaxWidth,
          createdAt: ticket.createdAt,
        ),
      );
    } else {
      for (final message in detail.messages) {
        widgets.add(
          SupportChatBubble(
            message: message.message,
            alignment: message.isAdmin
                ? SupportBubbleAlignment.left
                : SupportBubbleAlignment.right,
            label: message.isAdmin ? 'İBUL Destek' : null,
            createdAt: message.createdAt,
            maxBubbleWidth: bubbleMaxWidth,
          ),
        );
      }
    }

    if (detail.attachments.isNotEmpty) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_buildAttachmentPreview(detail.attachments));
    }

    return widgets;
  }

  List<Widget> _buildNewChatFlow(double bubbleMaxWidth) {
    final widgets = <Widget>[
      SupportChatBubble(
        message: 'Merhaba 👋 Size nasıl yardımcı olabiliriz?',
        alignment: SupportBubbleAlignment.left,
        label: 'İBUL Destek',
        maxBubbleWidth: bubbleMaxWidth,
      ),
      const SizedBox(height: 8),
      if (_activeTicketId == null) _buildCategoryChips(),
      if (_activeTicketId == null) ...[
        const SizedBox(height: 10),
        _buildAiCard(),
      ],
    ];

    if (_selectedCategory != null && _activeTicketId == null) {
      widgets.add(const SizedBox(height: 8));
      widgets.add(_buildSubcategoryChips(_selectedCategory!));
    }

    if (_detail != null) {
      widgets.addAll(_buildExistingMessages(_detail!, bubbleMaxWidth));
    }

    for (final notice in _systemNotices) {
      widgets.add(
        SupportChatBubble(
          message: notice,
          alignment: SupportBubbleAlignment.center,
          maxBubbleWidth: bubbleMaxWidth,
        ),
      );
    }

    return widgets;
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: supportCategoryCatalog.map((category) {
        final selected = _selectedCategory?.id == category.id;
        return ActionChip(
          label: Text(category.title, style: const TextStyle(fontSize: 12)),
          backgroundColor:
              selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
          side: BorderSide(
            color: selected ? AppColors.primary : const Color(0xFFE5E7EB),
          ),
          onPressed: () => _selectCategory(category),
        );
      }).toList(),
    );
  }

  Widget _buildSubcategoryChips(SupportCategoryOption category) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: category.subcategories.map((item) {
        final selected = _selectedSubcategory == item;
        return ChoiceChip(
          label: Text(item, style: const TextStyle(fontSize: 12)),
          selected: selected,
          onSelected: (_) => _selectSubcategory(item),
          selectedColor: AppColors.primary.withValues(alpha: 0.12),
        );
      }).toList(),
    );
  }

  Widget _buildAttachmentPreview(List<CustomerSupportAttachment> attachments) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((file) {
        final isImage = (file.fileType ?? '').startsWith('image/');
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: isImage
              ? Image.network(
                  file.fileUrl,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                )
              : Container(
                  width: 88,
                  height: 88,
                  color: const Color(0xFFF3F4F6),
                  child: const Icon(Icons.attach_file),
                ),
        );
      }).toList(),
    );
  }

  Widget _buildAiCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EAF2)),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology_outlined, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI Destek Asistanı — Yakında',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ),
          OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Yakında', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
