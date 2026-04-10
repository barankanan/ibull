import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../widgets/add_to_cart_button.dart';
import 'home_screen.dart';

class TryProductPage extends StatefulWidget {
  final Product product;

  const TryProductPage({super.key, required this.product});

  @override
  State<TryProductPage> createState() => _TryProductPageState();
}

class _TryProductPageState extends State<TryProductPage> {
  int _selectedAccessoryIndex = 0;
  double _scale = 1.0;
  double _baseScale = 1.0;
  final double _rotation = 0.0;
  final bool _showInterface = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ürünü Dene',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Info box at top
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ürünü Dene Dijital Ürünleri Kolayca Olduğunuz Yerden, Cihazın Ara Yüzüne Erişip Kontrol Etmenizi Sağlar.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: Row(
              children: [
                // Left side - Accessories
                if (widget.product.accessories != null && widget.product.accessories!.isNotEmpty)
                  SizedBox(
                    width: 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 80),
                        ...List.generate(
                          widget.product.accessories!.length,
                          (index) {
                            final isSelected = _selectedAccessoryIndex == index;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAccessoryIndex = index;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16, left: 8, right: 8),
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isSelected 
                                          ? AppColors.primary.withValues(alpha: 0.3)
                                          : Colors.black.withValues(alpha: 0.05),
                                      blurRadius: isSelected ? 8 : 4,
                                      spreadRadius: isSelected ? 1 : 0,
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Icon(
                                        Icons.watch,
                                        size: 36,
                                        color: isSelected ? AppColors.primary : Colors.grey[400],
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                // Center - Product with interface
                Expanded(
                  child: Stack(
                    children: [
                      // Product display area - centered
                      Center(
                        child: GestureDetector(
                          onScaleStart: (details) {
                            setState(() {
                              _baseScale = _scale;
                            });
                          },
                          onScaleUpdate: (details) {
                            setState(() {
                              _scale = (_baseScale * details.scale).clamp(0.5, 2.5);
                            });
                          },
                          child: SizedBox(
                            height: 300,
                            width: 300,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Product image
                                Transform.scale(
                                  scale: _scale,
                                  child: Transform.rotate(
                                    angle: _rotation,
                                    child: Container(
                                      width: 200,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(100),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 20,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: _showInterface
                                          ? Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '00:28',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.w300,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.battery_full, color: Colors.white, size: 14),
                                                    Text(
                                                      ' 57% ',
                                                      style: TextStyle(color: Colors.white, fontSize: 11),
                                                    ),
                                                    Icon(Icons.favorite, color: Colors.red, size: 14),
                                                    Text(
                                                      ' 0',
                                                      style: TextStyle(color: Colors.white, fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          : Center(
                                              child: Text(
                                                '00\n28',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 48,
                                                  fontWeight: FontWeight.w200,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                
                                // Interactive dots around product
                                if (_showInterface) ...[
                                  Positioned(
                                    top: 30,
                                    right: 60,
                                    child: _buildInteractiveDot(Colors.purple),
                                  ),
                                  Positioned(
                                    right: 40,
                                    child: _buildInteractiveDot(Colors.purple),
                                  ),
                                  Positioned(
                                    bottom: 60,
                                    right: 70,
                                    child: _buildInteractiveDot(Colors.purple),
                                  ),
                                  Positioned(
                                    bottom: 100,
                                    child: _buildInteractiveDot(Colors.purple),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Canlı Göster button - positioned at bottom left
                      Positioned(
                        bottom: 16,
                        left: 16,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                          ),
                          icon: const Icon(Icons.videocam_outlined, color: AppColors.primary, size: 18),
                          label: const Text(
                            'Canlı Göster',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Product name and Add to Cart button
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product.name.split(' ')[0],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AddToCartButton(
                        borderRadius: 8,
                        fontSize: 13,
                        onGoToCart: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(initialIndex: 3),
                            ),
                            (route) => false,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Action buttons row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 16),
                        label: const Text(
                          'Yakında Ara',
                          style: TextStyle(color: AppColors.primary, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.share_outlined, color: AppColors.primary, size: 16),
                        label: const Text(
                          'Paylaş',
                          style: TextStyle(color: AppColors.primary, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                        label: const Text(
                          'Ürün Bilgileri',
                          style: TextStyle(color: AppColors.primary, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveDot(Color color) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
