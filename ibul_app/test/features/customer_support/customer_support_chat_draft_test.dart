import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/features/customer_support/data/support_category_catalog.dart';
import 'package:ibul_app/features/customer_support/helpers/support_title_helpers.dart';
import 'package:ibul_app/features/customer_support/widgets/support_chat_bubble.dart';

void main() {
  testWidgets('category selection fills composer without user bubble', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    SupportCategoryOption? selectedCategory;
    String? selectedSubcategory;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        const SupportChatBubble(
                          message: 'Merhaba 👋 Size nasıl yardımcı olabiliriz?',
                          alignment: SupportBubbleAlignment.left,
                        ),
                        Wrap(
                          children: supportCategoryCatalog.map((category) {
                            return ActionChip(
                              label: Text(category.title),
                              onPressed: () {
                                setState(() {
                                  selectedCategory = category;
                                  selectedSubcategory = null;
                                });
                                applySupportComposerDraft(
                                  controller,
                                  supportComposerDraftForCategory(category.title),
                                );
                              },
                            );
                          }).toList(),
                        ),
                        if (selectedCategory != null)
                          Wrap(
                            children: selectedCategory!.subcategories.map((item) {
                              return ChoiceChip(
                                label: Text(item),
                                selected: selectedSubcategory == item,
                                onSelected: (_) {
                                  setState(() => selectedSubcategory = item);
                                  applySupportComposerDraft(
                                    controller,
                                    supportComposerDraftForSubcategory(item),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                  TextField(
                    key: const Key('composer'),
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Mesajını yaz...'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('İade / Değişim'));
    await tester.pumpAndSettle();

    expect(
      controller.text,
      'İade / Değişim konusunda destek almak istiyorum.',
    );
    expect(find.byType(SupportChatBubble), findsOneWidget);

    await tester.tap(find.text('İade ücretim yatmadı'));
    await tester.pumpAndSettle();

    expect(
      controller.text,
      'İade ücretim yatmadı. Destek almak istiyorum.',
    );
    expect(find.byType(SupportChatBubble), findsOneWidget);
  });
}
