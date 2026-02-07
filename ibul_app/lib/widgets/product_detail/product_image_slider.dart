import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/product_detail_viewmodel.dart';
import '../../core/constants.dart';
import '../../screens/product_features_page.dart';
import '../../screens/compare_page.dart';
import '../../models/product_model.dart';

class ProductImageSlider extends StatelessWidget {
  const ProductImageSlider({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<ProductDetailViewModel>(context);
    final images = viewModel.images;

    return Stack(
      children: [
        SizedBox(
          height: 350,
          child: PageView.builder(
            onPageChanged: viewModel.updateImageIndex,
            itemCount: images.length,
            itemBuilder: (context, index) {
              final imageUrl = images[index];
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                            ),
                          );
                        },
                      )
                    : Image.asset(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                            ),
                          );
                        },
                      ),
              );
            },
          ),
        ),
        // Indicator
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: viewModel.currentImageIndex == index
                      ? AppColors.primary
                      : Colors.grey[300],
                ),
              );
            }),
          ),
        ),
        // Overlay Buttons (Video & Features)
        Positioned(
          bottom: 30, // Adjusted to be above the indicator
          left: 16,
          child: _buildOverlayButton(context, 'Ürün Videosu', Icons.arrow_forward_ios),
        ),
        Positioned(
          bottom: 30, // Adjusted to be above the indicator
          right: 16,
          child: _buildOverlayButton(context, 'Tüm Özellikler', Icons.arrow_forward_ios),
        ),
        // Action icons on right side
        Positioned(
          top: 10,
          right: 16,
          child: Column(
            children: [
              _buildIconButton(
                icon: Icons.share_outlined,
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              _buildIconButton(
                icon: viewModel.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                onPressed: () => _showListSelectionBottomSheet(context, viewModel),
              ),
              const SizedBox(height: 12),
              _buildIconButton(
                icon: Icons.compare_arrows,
                onPressed: () => _showComparisonBottomSheet(context, viewModel),
              ),
              const SizedBox(height: 12),
              _buildIconButton(
                icon: viewModel.isFavorite ? Icons.favorite : Icons.favorite_border,
                iconColor: viewModel.isFavorite ? Colors.red : AppColors.primary,
                onPressed: viewModel.toggleFavorite,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color iconColor = AppColors.primary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: iconColor, size: 18),
        onPressed: onPressed,
      ),
    );
  }

  void _showListSelectionBottomSheet(BuildContext context, ProductDetailViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return AnimatedBuilder(
          animation: viewModel.appState,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Listeye Ekle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (viewModel.appState.userLists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Henüz bir listeniz yok.'),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: viewModel.appState.userLists.length,
                        itemBuilder: (context, index) {
                          final list = viewModel.appState.userLists[index];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: list['coverImage'].startsWith('http')
                                      ? NetworkImage(list['coverImage'])
                                      : AssetImage(list['coverImage']) as ImageProvider,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(list['name']),
                            subtitle: Text('${list['itemCount']} ürün'),
                            onTap: () {
                              viewModel.addProductToList(list['id']);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Ürün ${list['name']} listesine eklendi'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () {
                      _showCreateListDialog(context, viewModel);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Liste Oluştur'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateListDialog(BuildContext context, ProductDetailViewModel viewModel) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Liste Oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Liste Adı',
                labelText: 'Liste Adı',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                hintText: 'Açıklama',
                labelText: 'Açıklama',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                viewModel.appState.createUserList(nameController.text, descController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayButton(BuildContext context, String text, IconData icon) {
    return GestureDetector(
      onTap: () {
        if (text == 'Tüm Özellikler') {
          final viewModel = Provider.of<ProductDetailViewModel>(context, listen: false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductFeaturesPage(product: viewModel.initialProduct),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 10, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  void _showComparisonBottomSheet(BuildContext context, ProductDetailViewModel viewModel) {
    final favorites = viewModel.appState.favorites;
    final Set<Product> selectedProducts = {};

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Karşılaştır',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: selectedProducts.isNotEmpty
                              ? () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ComparePage(
                                        baseProduct: viewModel.initialProduct,
                                        comparisonProducts: selectedProducts.toList(),
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          child: const Text('Karşılaştır'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  if (favorites.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Karşılaştırılacak favori ürününüz yok.\nÖnce ürünleri favorilere ekleyin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final product = favorites[index];
                          // Don't show the current product in the list
                          if (product.name == viewModel.initialProduct.name) return const SizedBox.shrink();

                          final isSelected = selectedProducts.contains(product);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  if (selectedProducts.length < 2) {
                                    selectedProducts.add(product);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('En fazla 2 ürün ekleyebilirsiniz'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                } else {
                                  selectedProducts.remove(product);
                                }
                              });
                            },
                            secondary: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                                image: DecorationImage(
                                  image: product.images.isNotEmpty 
                                      ? (product.images.first.startsWith('http') 
                                          ? NetworkImage(product.images.first) 
                                          : AssetImage(product.images.first) as ImageProvider)
                                      : const AssetImage('assets/placeholder.png'),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            title: Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              product.price,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            activeColor: AppColors.primary,
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
