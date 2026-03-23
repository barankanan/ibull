import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

ImageProvider<Object> xFileImageProvider(XFile file) {
  return NetworkImage(file.path);
}

