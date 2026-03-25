import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';

class Product360Viewer extends StatefulWidget {
  final List<String> imageUrls;
  final bool autoRotate;
  final Duration rotationDuration;
  final double sensitivity;

  const Product360Viewer({
    super.key,
    required this.imageUrls,
    this.autoRotate = false,
    this.rotationDuration = const Duration(milliseconds: 100),
    this.sensitivity = 1.0,
  });

  @override
  State<Product360Viewer> createState() => _Product360ViewerState();
}

class _Product360ViewerState extends State<Product360Viewer> {
  int _currentIndex = 0;
  double _dragAccumulator = 0.0;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Precache images could be done here or handled by the framework
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheImages();
    });
  }

  void _precacheImages() {
    // Basic precaching logic
    for (var url in widget.imageUrls) {
      if (url.startsWith('http')) {
        final provider = OptimizedImage.buildContextAwareProvider(
          context: context,
          imageUrlOrPath: url,
        );
        if (provider != null) {
          precacheImage(provider, context);
        }
      } else {
        precacheImage(AssetImage(url), context);
      }
    }
    setState(() {
      _isLoaded = true;
    });
  }

  void _handleDrag(DragUpdateDetails details) {
    setState(() {
      _dragAccumulator += details.delta.dx * widget.sensitivity;
      
      // Threshold to change image (e.g., every 10 pixels of drag)
      const double threshold = 10.0;
      
      if (_dragAccumulator.abs() >= threshold) {
        int steps = (_dragAccumulator / threshold).truncate();
        
        // Update index (negative steps for dragging left, positive for right)
        // If we drag left (negative dx), we want to rotate "right" (show next images)
        // or depends on how the images were taken. Usually:
        // Drag Left -> Next Image
        // Drag Right -> Previous Image
        
        _currentIndex = (_currentIndex - steps) % widget.imageUrls.length;
        if (_currentIndex < 0) {
          _currentIndex += widget.imageUrls.length;
        }
        
        // Reset accumulator but keep the remainder for smooth feeling
        _dragAccumulator -= steps * threshold;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return const Center(child: Text('Görsel bulunamadı'));
    }

    return GestureDetector(
      onHorizontalDragUpdate: _handleDrag,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main Image
          _buildImage(widget.imageUrls[_currentIndex]),
          
          // 360 Indicator / Hint
          Positioned(
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.threesixty, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Çevirmek için sürükleyin',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(String url) {
    // Keep aspect ratio or fit logic consistent with your app
    if (url.startsWith('http')) {
      return OptimizedImage(
        imageUrlOrPath: url,
        gaplessPlayback: true, // Important for smooth transitions
        fit: BoxFit.contain,
        priority: OptimizedImagePriority.lazy,
      );
    } else {
      return Image.asset(
        url,
        gaplessPlayback: true,
        fit: BoxFit.contain,
      );
    }
  }
}
