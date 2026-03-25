import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import 'package:image_picker/image_picker.dart';

ImageProvider<Object> xFileImageProvider(XFile file) {
  return ResizeImage.resizeIfNeeded(
    OptimizedImage.webMaxDecodeDimension,
    OptimizedImage.webMaxDecodeDimension,
    NetworkImage(file.path),
  );
}
