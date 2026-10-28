import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/marketplace_paths.dart';
import '../../core/app_state.dart';
import '../../core/constants.dart';
import '../../models/product_list_model.dart';
import '../../models/product_model.dart';
import '../../models/product_pricing.dart';

class CartSelectionPage extends StatefulWidget {
  const CartSelectionPage({super.key});

  @override
  State<CartSelectionPage> createState() => _CartSelectionPageState();
}

class _CartSelectionPageState extends State<CartSelectionPage> {
  final AppState _appState = AppState();
  final Set<String> _selected = {};

  List<Product> get _products => _appState.cart;

  @override
  void initState() {
    super.initState();
    _appState.addListener(_refresh);
  }

  @override
  void dispose() {
    _appState.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  String _key(Product product) {
    final id = product.productId?.trim() ?? '';
    return id.isNotEmpty ? id : '${product.brand}|${product.name}';
  }

  List<Product> get _selectedProducts =>
      _products.where((product) => _selected.contains(_key(product))).toList();

  Future<void> _share() async {
    final selected = _selectedProducts;
    if (selected.isEmpty) return;
    await Share.share(cartSelectionShareText(selected));
  }

  Future<void> _addToList() async {
    final selected = _selectedProducts;
    if (selected.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddToListSheet(
        products: selected,
        lists: _appState.productLists,
        onExisting: (listId) {
          var added = 0;
          for (final product in selected) {
            if (_appState.addToProductList(listId, product)) added++;
          }
          Navigator.pop(context);
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(content: Text('$added ürün listeye eklendi')),
          );
        },
        onCreate: (name, visibility) {
          final id = _appState.createProductList(
            name,
            visibility: visibility,
            description: 'Sepetten oluşturuldu',
          );
          for (final product in selected) {
            _appState.addToProductList(id, product);
          }
          Navigator.pop(context);
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(content: Text('Liste oluşturuldu')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _products;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sepette Seç',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: products.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sepetinde listeye ekleyebileceğin ürün yok',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textGrey),
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        '${_selected.length} ürün seçildi',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(_selected.clear),
                        child: const Text('Seçimi Temizle'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final selected = _selected.contains(_key(product));
                      return _SelectionTile(
                        product: product,
                        selected: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value) {
                              _selected.add(_key(product));
                            } else {
                              _selected.remove(_key(product));
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: products.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _selected.isEmpty ? null : _addToList,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('Listeye Ekle'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selected.isEmpty ? null : _share,
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Paylaş'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({
    required this.product,
    required this.selected,
    required this.onChanged,
  });

  final Product product;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final image = product.images.isEmpty ? null : product.images.first;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                color: selected ? AppColors.primary : AppColors.iconMuted,
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 56,
                  height: 56,
                  color: const Color(0xFFF4F0FF),
                  child: image != null && image.startsWith('http')
                      ? Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.image_outlined,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(
                          Icons.image_outlined,
                          color: AppColors.primary,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${product.category ?? 'Ürün'} · ${product.brand}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textGrey,
                      ),
                    ),
                    Text(
                      'Stokta var',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                product.price,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddToListSheet extends StatefulWidget {
  const _AddToListSheet({
    required this.products,
    required this.lists,
    required this.onExisting,
    required this.onCreate,
  });

  final List<Product> products;
  final List<ProductList> lists;
  final ValueChanged<String> onExisting;
  final void Function(String name, ProductListVisibility visibility) onCreate;

  @override
  State<_AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends State<_AddToListSheet> {
  final _name = TextEditingController();
  var _creating = false;
  var _visibility = ProductListVisibility.private;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seçili Ürünlerle İşlem Yap',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.products.length} ürün seçildi.',
              style: const TextStyle(color: AppColors.textGrey),
            ),
            const SizedBox(height: 12),
            if (!_creating) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.list_alt, color: AppColors.primary),
                title: const Text('Mevcut Listeye Ekle'),
                subtitle: const Text('Seçili ürünleri bir listeye ekle'),
                onTap: widget.lists.isEmpty
                    ? null
                    : () => _pickExisting(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add, color: AppColors.primary),
                title: const Text('Yeni Liste Oluştur'),
                subtitle: const Text('Seçili ürünlerle yeni bir liste oluştur'),
                onTap: () => setState(() => _creating = true),
              ),
            ] else ...[
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: 'Liste adı',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Özel'),
                    selected: _visibility == ProductListVisibility.private,
                    onSelected: (_) => setState(
                      () => _visibility = ProductListVisibility.private,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Herkese Açık'),
                    selected: _visibility == ProductListVisibility.public,
                    onSelected: (_) => setState(
                      () => _visibility = ProductListVisibility.public,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  if (_name.text.trim().isEmpty) {
                    setState(() => _error = 'Liste adı zorunlu');
                    return;
                  }
                  widget.onCreate(_name.text.trim(), _visibility);
                },
                child: const Text('Listeyi Oluştur'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickExisting(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final list in widget.lists)
              ListTile(
                title: Text(list.name),
                subtitle: Text('${list.productCount} ürün'),
                onTap: () => Navigator.pop(context, list.id),
              ),
          ],
        ),
      ),
    );
    if (id != null) widget.onExisting(id);
  }
}

String cartSelectionShareText(List<Product> products) {
  final lines = products.map((product) {
    final id = product.productId?.trim() ?? '';
    final price = product.price.trim();
    final label = price.isEmpty ? product.name : '${product.name} — $price';
    if (id.isEmpty) return '• $label';
    return '• $label\n${MarketplacePaths.product(id, slug: product.name)}';
  });
  return "İBUL'da seçtiğim ürünler:\n${lines.join('\n')}";
}

double cartSelectionPrice(Product product) {
  return ProductPriceCalculator.parsePriceValue(product.price);
}
