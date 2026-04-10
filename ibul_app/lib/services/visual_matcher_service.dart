import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../models/db_product.dart';

// Top-level function for isolate
ImageSignature createSignatureFromBytes(List<int> bytes) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) throw Exception('Failed to decode image');
  return _buildSignatureStatic(image);
}

// Top-level function for isolate
Map<String, ImageSignature> createBatchSignatures(Map<String, List<int>> batch) {
  final result = <String, ImageSignature>{};
  for (var entry in batch.entries) {
    try {
      final image = img.decodeImage(Uint8List.fromList(entry.value));
      if (image != null) {
        result[entry.key] = _buildSignatureStatic(image);
      }
    } catch (e) {
      // ignore
    }
  }
  return result;
}

ImageSignature _buildSignatureStatic(img.Image image) {
  final resized = img.copyResize(image, width: 32, height: 32);
  final hashImage = img.copyResize(image, width: 8, height: 8);
  final hash = _averageHashStatic(hashImage);
  final histogram = _colorHistogramStatic(resized);
  return ImageSignature(hash, histogram);
}

List<int> _averageHashStatic(img.Image image) {
  int sum = 0;
  final values = <int>[];
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final v = ((p.r + p.g + p.b) / 3).round();
      values.add(v);
      sum += v;
    }
  }
  final avg = sum / values.length;
  return values.map((v) => v >= avg ? 1 : 0).toList();
}

List<double> _colorHistogramStatic(img.Image image) {
  final bins = List<double>.filled(64, 0);
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final rBin = (p.r ~/ 64).clamp(0, 3);
      final gBin = (p.g ~/ 64).clamp(0, 3);
      final bBin = (p.b ~/ 64).clamp(0, 3);
      final index = rBin * 16 + gBin * 4 + bBin;
      bins[index] += 1;
    }
  }
  final total = image.width * image.height;
  if (total > 0) {
    for (int i = 0; i < bins.length; i++) {
      bins[i] = bins[i] / total;
    }
  }
  return bins;
}

class VisualMatcherService {
  // Singleton
  static final VisualMatcherService _instance = VisualMatcherService._internal();
  factory VisualMatcherService() => _instance;
  VisualMatcherService._internal();
  final Map<String, ImageSignature> _signatureCache = {};

  /// Finds the top N matching products for the given image file.
  Future<List<DBProduct>> findTopMatches(File imageFile, List<DBProduct> products, {int limit = 5}) async {
    debugPrint('VisualMatcher: Starting search for ${imageFile.path}');
    final Set<DBProduct> results = {}; // Use Set to avoid duplicates

    // 1. Try filename matching (Fast Path)
    final filename = imageFile.path.split('/').last.toLowerCase();
    final filenameTokens = _tokenize(filename);
    
    // Check for direct asset match
    for (var product in products) {
      final assetName = product.imageUrl.split('/').last.toLowerCase();
      if (filename == assetName) {
        debugPrint('VisualMatcher: Exact filename match found: ${product.name}');
        results.add(product);
      }
    }
    
    // Check for keyword match in filename
    List<MapEntry<DBProduct, int>> keywordMatches = [];
    for (var product in products) {
      final nameTokens = _tokenize(product.name);
      final brandTokens = _tokenize(product.brand);
      int score = 0;
      
      for (var token in filenameTokens) {
        if (token.length > 2 && nameTokens.contains(token)) {
          score += 3;
        }
        if (token.length > 2 && brandTokens.contains(token)) {
          score += 2;
        }
      }
      
      if (score > 0) {
        keywordMatches.add(MapEntry(product, score));
      }
    }
    
    // Sort keyword matches by score desc
    keywordMatches.sort((a, b) => b.value.compareTo(a.value));
    for (var entry in keywordMatches) {
      results.add(entry.key);
    }
    
    // If we have enough high-confidence text matches, return them
    if (results.length >= limit) {
      return results.take(limit).toList();
    }

    // 2. Pixel-based comparison (Slow Path)
    try {
      final userBytes = await imageFile.readAsBytes();
      final userSignature = await compute(createSignatureFromBytes, userBytes);
      
      // Prepare batch processing for assets
      final allPaths = <String>{};
      for (var p in products) {
        allPaths.addAll(_getProductImageCandidates(p));
      }
      
      // Filter paths that are not in cache
      final neededPaths = allPaths.where((p) => !_signatureCache.containsKey(p)).toList();
      
      // Process needed paths in batches
      const int batchSize = 10;
      for (int i = 0; i < neededPaths.length; i += batchSize) {
         final end = (i + batchSize < neededPaths.length) ? i + batchSize : neededPaths.length;
         final batchPaths = neededPaths.sublist(i, end);
         
         final batchBytes = <String, List<int>>{};
         for (var path in batchPaths) {
            try {
                final data = await rootBundle.load(path);
                batchBytes[path] = data.buffer.asUint8List();
            } catch (_) {}
         }
         
         if (batchBytes.isNotEmpty) {
             final signatures = await compute(createBatchSignatures, batchBytes);
             _signatureCache.addAll(signatures);
         }
         await Future.delayed(Duration.zero);
      }
      
      List<MapEntry<DBProduct, double>> visualScores = [];
      
      for (var product in products) {
        // Skip if already in results
        if (results.contains(product)) continue;

        final imageCandidates = _getProductImageCandidates(product);
        double bestProductScore = double.maxFinite;
        
        for (var imagePath in imageCandidates) {
          final assetSignature = _signatureCache[imagePath];
          if (assetSignature == null) continue;
          
          final score = _signatureDistance(userSignature, assetSignature);
          if (score < bestProductScore) {
            bestProductScore = score;
          }
        }
        
        if (bestProductScore != double.maxFinite) {
          visualScores.add(MapEntry(product, bestProductScore));
        }
      }
      
      // Sort visual matches by score ASC (lower is better distance)
      visualScores.sort((a, b) => a.value.compareTo(b.value));
      
      for (var entry in visualScores) {
        results.add(entry.key);
        if (results.length >= limit * 2) break; // Collect a bit more than needed
      }
      
    } catch (e) {
      debugPrint('VisualMatcher: Error in pixel comparison: $e');
    }

    return results.take(limit).toList();
  }

  /// Backward compatibility
  Future<DBProduct?> findBestMatch(File imageFile, List<DBProduct> products) async {
    final matches = await findTopMatches(imageFile, products, limit: 1);
    return matches.isNotEmpty ? matches.first : null;
  }
  
  List<String> _tokenize(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    return cleaned.split(' ').where((t) => t.trim().isNotEmpty).toList();
  }

  List<String> _getProductImageCandidates(DBProduct product) {
    final images = <String>{};
    if (product.imageUrl.isNotEmpty) {
      images.add(product.imageUrl);
    }
    final extra = product.imageUrls;
    if (extra != null && extra.isNotEmpty) {
      try {
        final decoded = json.decode(extra);
        if (decoded is List) {
          for (var item in decoded) {
            final path = item.toString().trim();
            if (path.isNotEmpty) images.add(path);
          }
        }
      } catch (_) {
        for (var part in extra.split(',')) {
          final path = part.trim();
          if (path.isNotEmpty) images.add(path);
        }
      }
    }
    return images.toList();
  }

  double _signatureDistance(ImageSignature a, ImageSignature b) {
    final hamming = _hammingDistance(a.hash, b.hash);
    final histDiff = _histogramDistance(a.histogram, b.histogram);
    // Tuned weights: Structure (hamming) vs Color (histogram)
    // Hamming max ~64, Histogram max ~2.0
    // Weighting them to be roughly balanced but prioritizing color slightly more for retail items
    return hamming * 5.0 + histDiff * 150.0;
  }

  int _hammingDistance(List<int> a, List<int> b) {
    int diff = 0;
    final len = min(a.length, b.length);
    for (int i = 0; i < len; i++) {
      if (a[i] != b[i]) diff++;
    }
    return diff + (a.length - len).abs();
  }

  double _histogramDistance(List<double> a, List<double> b) {
    final len = min(a.length, b.length);
    double diff = 0;
    for (int i = 0; i < len; i++) {
      diff += (a[i] - b[i]).abs();
    }
    return diff;
  }
}

class ImageSignature {
  final List<int> hash;
  final List<double> histogram;

  const ImageSignature(this.hash, this.histogram);
}
