import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cropperx/cropperx.dart';

class ImageCropperWidget extends StatefulWidget {
  final Uint8List imageData;
  final void Function(Uint8List croppedData) onCropped;
  final double? aspectRatio;
  final double? suggestedWidth;

  const ImageCropperWidget({
    Key? key,
    required this.imageData,
    required this.onCropped,
    this.aspectRatio,
    this.suggestedWidth,
  }) : super(key: key);

  @override
  State<ImageCropperWidget> createState() => _ImageCropperWidgetState();
}

class _ImageCropperWidgetState extends State<ImageCropperWidget> {
  final GlobalKey _cropperKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final double aspectRatio = widget.aspectRatio ?? 1.0;
    
    // Initial width calculation (max 850 or 90% of screen)
    double dialogWidth = widget.suggestedWidth ?? (screenSize.width > 950 ? 850 : screenSize.width * 0.9);
    
    // Check width constraint (never exceed screen width - padding)
    if (dialogWidth > screenSize.width * 0.95) {
      dialogWidth = screenSize.width * 0.95;
    }
    
    // Calculate height based on aspect ratio
    double contentHeight = dialogWidth / aspectRatio;
    
    // Check height constraints
    // UI overhead approx 180px (Title + Spacing + Text + Buttons + Padding)
    const double uiOverhead = 180.0; 
    final double maxHeight = screenSize.height * 0.85;
    
    if (contentHeight + uiOverhead > maxHeight) {
      contentHeight = maxHeight - uiOverhead;
      // Adjust width to maintain aspect ratio
      dialogWidth = contentHeight * aspectRatio;
    }

    // Ensure minimum dimensions
    if (dialogWidth < 300) dialogWidth = 300;
    if (contentHeight < 200) contentHeight = 200;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        height: contentHeight + uiOverhead,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              "Gorseli kirpin",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Cropper(
                cropperKey: _cropperKey,
                image: Image.memory(widget.imageData),
                overlayType: OverlayType.rectangle,
                aspectRatio: widget.aspectRatio ?? 1.0,
                zoomScale: 3.0,
                overlayColor: Colors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Kare kirpma alani 512x512 px icin uygundur. Resmi iki parmaginizla yakinlastirip konumlandirabilirsiniz.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    backgroundColor: Colors.grey.shade700,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("İptal", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final cropped = await Cropper.crop(cropperKey: _cropperKey);
                    if (cropped != null) {
                      widget.onCropped(cropped);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  child: const Text("Bitti", style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
