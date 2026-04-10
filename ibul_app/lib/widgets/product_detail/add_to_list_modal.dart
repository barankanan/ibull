import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../../models/product_model.dart';
import '../../models/product_list_model.dart';
import '../../core/interaction_feedback.dart';

class AddToListModal extends StatefulWidget {
  final Product product;
  final List<ProductList> userLists;
  final bool Function(String listId) onAddToList;
  final bool Function(String listName, ProductListVisibility visibility)
  onCreateNewList;

  const AddToListModal({
    super.key,
    required this.product,
    required this.userLists,
    required this.onAddToList,
    required this.onCreateNewList,
  });

  @override
  State<AddToListModal> createState() => _AddToListModalState();
}

class _AddToListModalState extends State<AddToListModal> {
  final TextEditingController _newListController = TextEditingController();
  bool _showNewListInput = false;
  ProductListVisibility _selectedVisibility = ProductListVisibility.private;

  @override
  void dispose() {
    _newListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text(
                  'Listeye Ekle',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lists
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                ...widget.userLists.map((list) => _buildListTile(list)),

                // Yeni Liste Oluştur Button
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add, color: Color(0xFF7C4DFF)),
                  ),
                  title: const Text(
                    'Yeni Liste Oluştur',
                    style: TextStyle(
                      color: Color(0xFF7C4DFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _showNewListInput = true;
                    });
                  },
                ),

                // Yeni Liste Input
                if (_showNewListInput)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _newListController,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Liste adı',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: ProductListVisibility.values.map((
                            visibility,
                          ) {
                            final isSelected =
                                _selectedVisibility == visibility;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right:
                                      visibility ==
                                          ProductListVisibility.private
                                      ? 8
                                      : 0,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedVisibility = visibility;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(
                                              0xFF7C4DFF,
                                            ).withValues(alpha: 0.12)
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF7C4DFF)
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          visibility.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: isSelected
                                                ? const Color(0xFF7C4DFF)
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          visibility ==
                                                  ProductListVisibility.private
                                              ? 'Sadece sen görürsün'
                                              : 'Uygulamadaki herkes görebilir',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _showNewListInput = false;
                                  _newListController.clear();
                                  _selectedVisibility =
                                      ProductListVisibility.private;
                                });
                              },
                              child: const Text('İptal'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                if (_newListController.text.trim().isNotEmpty) {
                                  final added = widget.onCreateNewList(
                                    _newListController.text.trim(),
                                    _selectedVisibility,
                                  );
                                  if (!added) {
                                    InteractionFeedback.forInteraction(
                                      InteractionFeedbackType.errorState,
                                      channel: 'create_list_error',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Bu urun yeni listenin kurallarina gore eklenemedi.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  InteractionFeedback.forInteraction(
                                    InteractionFeedbackType.successState,
                                    channel: 'create_list_success',
                                  );
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Liste oluşturuldu: ${_newListController.text.trim()}',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C4DFF),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Oluştur'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildListTile(ProductList list) {
    final isProductInList = list.products.any(
      (product) =>
          product.name == widget.product.name &&
          product.brand == widget.product.brand &&
          product.store == widget.product.store,
    );

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: list.iconUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: list.iconUrl!.startsWith('http')
                    ? OptimizedImage(
                        imageUrlOrPath: list.iconUrl!,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(list.iconUrl!, fit: BoxFit.cover),
              )
            : Icon(Icons.list, color: Colors.grey[600]),
      ),
      title: Text(
        list.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${list.visibility.label} • ${list.description ?? '${list.productIds.length} ürün'}',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: isProductInList
          ? const Icon(Icons.check_circle, color: Color(0xFF7C4DFF))
          : const Icon(Icons.add_circle_outline, color: Colors.grey),
      onTap: () {
        final added = widget.onAddToList(list.id);
        if (!added) {
          InteractionFeedback.forInteraction(
            InteractionFeedbackType.errorState,
            channel: 'add_to_list_error',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bu urun sadece ayni kategoride urunlerden olusan listelere eklenebilir.',
              ),
            ),
          );
          return;
        }
        InteractionFeedback.forInteraction(
          InteractionFeedbackType.successState,
          channel: 'add_to_list_success',
        );
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${list.name} listesine eklendi'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}
