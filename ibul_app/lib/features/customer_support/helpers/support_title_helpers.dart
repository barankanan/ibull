import 'package:flutter/material.dart';

import '../models/customer_support_models.dart';

String supportAutoTitleForCategory(String categoryId) {
  switch (categoryId) {
    case 'order_issue':
      return 'Sipariş sorunu desteği';
    case 'return_exchange':
      return 'İade / Değişim desteği';
    case 'payment_issue':
      return 'Ödeme sorunu desteği';
    case 'store_complaint':
      return 'Mağaza / Satıcı şikayeti';
    case 'technical_issue':
      return 'Teknik sorun bildirimi';
    case 'account_security':
      return 'Hesap ve güvenlik desteği';
    case 'suggestion':
      return 'Öneri / istek';
    case 'other':
      return 'Genel destek talebi';
    default:
      return 'Destek talebi';
  }
}

String supportAutoTitle({
  required String categoryId,
  String? subcategory,
}) {
  if (subcategory != null && subcategory.trim().isNotEmpty) {
    return subcategory.trim();
  }
  return supportAutoTitleForCategory(categoryId);
}

String supportCategoryUserMessage(String categoryTitle) {
  return '$categoryTitle konusunda destek almak istiyorum.';
}

String supportSubcategoryComposerMessage(String subcategory) {
  return '${subcategory.trim()}. Destek almak istiyorum.';
}

String supportComposerDraftForCategory(String categoryTitle) {
  return supportCategoryUserMessage(categoryTitle);
}

String supportComposerDraftForSubcategory(String subcategory) {
  return supportSubcategoryComposerMessage(subcategory);
}

void applySupportComposerDraft(TextEditingController controller, String text) {
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}

const String kSupportEmptySendWarning =
    'Lütfen mesaj yazın veya görsel ekleyin.';

const String kSupportDefaultCategoryId = 'other';
const String kSupportImageOnlyMessage =
    'Görsel ekledim, destek almak istiyorum.';

bool isSupportComposerEnabled(CustomerSupportStatus? status) {
  if (status == null) return true;
  return status != CustomerSupportStatus.closed &&
      status != CustomerSupportStatus.resolved &&
      status != CustomerSupportStatus.rejected;
}

String resolveOutgoingChatMessage({
  required String typedText,
  required bool hasAttachments,
}) {
  final trimmed = typedText.trim();
  if (trimmed.isNotEmpty) return trimmed;
  if (hasAttachments) return kSupportImageOnlyMessage;
  return '';
}

({String categoryId, String? subcategory, String title}) resolveNewTicketMeta({
  String? categoryId,
  String? subcategory,
  String? customTitle,
}) {
  final resolvedCategory = categoryId ?? kSupportDefaultCategoryId;
    final resolvedSubcategory =
        (subcategory == null || subcategory.trim().isEmpty)
        ? null
        : subcategory.trim();
  final title = customTitle?.trim().isNotEmpty == true
      ? customTitle!.trim()
      : supportAutoTitle(
          categoryId: resolvedCategory,
          subcategory: resolvedSubcategory,
        );
  return (
    categoryId: resolvedCategory,
    subcategory: resolvedSubcategory,
    title: title,
  );
}
