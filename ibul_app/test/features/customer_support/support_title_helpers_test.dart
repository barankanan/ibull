import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/customer_support/helpers/support_title_helpers.dart';
import 'package:ibul_app/features/customer_support/models/customer_support_models.dart';

void main() {
  test('category auto title mapping', () {
    expect(
      supportAutoTitleForCategory('order_issue'),
      'Sipariş sorunu desteği',
    );
    expect(
      supportAutoTitleForCategory('technical_issue'),
      'Teknik sorun bildirimi',
    );
    expect(
      supportAutoTitleForCategory('other'),
      'Genel destek talebi',
    );
  });

  test('subcategory overrides auto title', () {
    expect(
      supportAutoTitle(
        categoryId: 'return_exchange',
        subcategory: 'İade ücretim yatmadı',
      ),
      'İade ücretim yatmadı',
    );
  });

  test('composer draft for category and subcategory', () {
    expect(
      supportComposerDraftForCategory('İade / Değişim'),
      'İade / Değişim konusunda destek almak istiyorum.',
    );
    expect(
      supportComposerDraftForSubcategory('İade ücretim yatmadı'),
      'İade ücretim yatmadı. Destek almak istiyorum.',
    );
  });

  test('applySupportComposerDraft sets text and cursor at end', () {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    applySupportComposerDraft(controller, 'Test mesajı');
    expect(controller.text, 'Test mesajı');
    expect(controller.selection.baseOffset, 'Test mesajı'.length);
  });

  test('empty send shows no outgoing message', () {
    expect(
      resolveOutgoingChatMessage(typedText: '', hasAttachments: false),
      '',
    );
  });

  test('image-only outgoing message uses default text', () {
    expect(
      resolveOutgoingChatMessage(typedText: '', hasAttachments: true),
      kSupportImageOnlyMessage,
    );
  });

  test('no category uses general support title', () {
    final meta = resolveNewTicketMeta();
    expect(meta.categoryId, kSupportDefaultCategoryId);
    expect(meta.subcategory, isNull);
    expect(meta.title, 'Genel destek talebi');
  });

  test('image-only outgoing message uses default text', () {
    expect(
      resolveOutgoingChatMessage(typedText: '', hasAttachments: true),
      kSupportImageOnlyMessage,
    );
  });

  test('composer enabled unless ticket closed', () {
    expect(isSupportComposerEnabled(null), isTrue);
    expect(isSupportComposerEnabled(CustomerSupportStatus.reviewing), isTrue);
    expect(isSupportComposerEnabled(CustomerSupportStatus.closed), isFalse);
  });
}
