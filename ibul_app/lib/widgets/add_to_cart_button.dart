import 'package:flutter/material.dart';
import '../core/constants.dart';

/// Yeniden kullanılabilir Sepete Ekle butonu widget'ı
/// 
/// Bu widget, uygulama genelinde sepete ekleme işlemlerinde kullanılır.
/// State'i kendi içinde tutar ve callback'lerle dışarıya bilgi verir.
class AddToCartButton extends StatefulWidget {
  /// Buton genişliği (null ise parent'ın genişliğini alır)
  final double? width;
  
  /// Buton yüksekliği için padding
  final EdgeInsets? padding;
  
  /// Buton border radius
  final double borderRadius;
  
  /// Font büyüklüğü
  final double fontSize;
  
  /// İkon gösterilsin mi?
  final bool showIcon;
  
  /// İkon boyutu
  final double iconSize;
  
  /// Sepete eklendiğinde çağrılacak callback
  final VoidCallback? onAddToCart;
  
  /// Sepete git butonuna tıklandığında çağrılacak callback
  final VoidCallback? onGoToCart;
  
  /// Başlangıç durumu (sepette mi?)
  final bool isInitiallyInCart;

  const AddToCartButton({
    super.key,
    this.width,
    this.padding,
    this.borderRadius = 8.0,
    this.fontSize = 13.0,
    this.showIcon = false,
    this.iconSize = 20.0,
    this.onAddToCart,
    this.onGoToCart,
    this.isInitiallyInCart = false,
  });

  @override
  State<AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<AddToCartButton> {
  late bool _isAddedToCart;

  @override
  void initState() {
    super.initState();
    _isAddedToCart = widget.isInitiallyInCart;
  }

  void _handlePress() {
    if (_isAddedToCart) {
      // Sepete git
      widget.onGoToCart?.call();
    } else {
      // Sepete ekle
      setState(() {
        _isAddedToCart = true;
      });
      widget.onAddToCart?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: ElevatedButton(
        onPressed: _handlePress,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isAddedToCart ? Colors.green : AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
          padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 12),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.showIcon) ...[
              Icon(
                Icons.shopping_cart,
                color: Colors.white,
                size: widget.iconSize,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              _isAddedToCart ? 'SEPETE GİT' : 'SEPETE EKLE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: widget.fontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
