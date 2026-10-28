import 'dart:math';

part 'visual_search_models_format.dart';

enum VisualSearchJobType {
  visualSearch,
  damageAnalysis,
  missingPartsAnalysis,
  combined,
}

enum VisualSearchJobStatus { pending, processing, completed, failed }

enum VisualSearchPhase {
  idle,
  selectingImage,
  uploading,
  analyzing,
  success,
  empty,
  error,
}

enum VisualSearchHistoryFilter {
  all,
  visualSearch,
  intelligence,
  damage,
  missingParts,
}

enum ProductMatchType { exact, similar, alternative }

enum VisualSearchErrorCode {
  emptyFile,
  fileTooLarge,
  unsupportedType,
  analysisFailed,
  notFound,
}

class VisualSearchException implements Exception {
  const VisualSearchException(this.code, this.message);

  final VisualSearchErrorCode code;
  final String message;

  @override
  String toString() => message;
}

class VisualSearchRemoteUnavailable implements Exception {
  const VisualSearchRemoteUnavailable();
}

class BoundingBox {
  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'w': width,
    'h': height,
  };

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      x: _asDouble(json['x']),
      y: _asDouble(json['y']),
      width: _asDouble(json['w']),
      height: _asDouble(json['h']),
    );
  }
}

class DamageDetection {
  const DamageDetection({
    required this.id,
    required this.label,
    required this.confidence,
    required this.bbox,
    required this.description,
  });

  final String id;
  final String label;
  final double confidence;
  final BoundingBox bbox;
  final String description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'confidence': confidence,
    'bbox': bbox.toJson(),
    'description': description,
  };

  factory DamageDetection.fromJson(Map<String, dynamic> json) {
    return DamageDetection(
      id: json['id']?.toString() ?? newVisualSearchId(),
      label: json['label']?.toString() ?? 'Hasar',
      confidence: _asDouble(json['confidence']),
      bbox: BoundingBox.fromJson(_asMap(json['bbox'])),
      description: json['description']?.toString() ?? '',
    );
  }
}

class MissingPartDetection {
  const MissingPartDetection({
    required this.id,
    required this.partName,
    required this.confidence,
    required this.bbox,
    required this.details,
  });

  final String id;
  final String partName;
  final double confidence;
  final BoundingBox bbox;
  final String details;

  Map<String, dynamic> toJson() => {
    'id': id,
    'part_name': partName,
    'confidence': confidence,
    'bbox': bbox.toJson(),
    'details': details,
  };

  factory MissingPartDetection.fromJson(Map<String, dynamic> json) {
    return MissingPartDetection(
      id: json['id']?.toString() ?? newVisualSearchId(),
      partName: json['part_name']?.toString() ?? 'Parça',
      confidence: _asDouble(json['confidence']),
      bbox: BoundingBox.fromJson(_asMap(json['bbox'])),
      details: json['details']?.toString() ?? '',
    );
  }
}

class ProductMatch {
  const ProductMatch({
    required this.id,
    required this.productId,
    required this.name,
    required this.brand,
    required this.store,
    required this.price,
    required this.category,
    required this.similarityScore,
    required this.matchType,
    this.imageUrl = '',
    this.rating = 0,
    this.reviewCount = 0,
  });

  final String id;
  final String productId;
  final String name;
  final String brand;
  final String store;
  final String price;
  final String category;
  final String imageUrl;
  final double similarityScore;
  final ProductMatchType matchType;
  final double rating;
  final int reviewCount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'name': name,
    'brand': brand,
    'store': store,
    'price': price,
    'category': category,
    'image_url': imageUrl,
    'similarity_score': similarityScore,
    'match_type': matchType.name,
    'rating': rating,
    'review_count': reviewCount,
  };

  factory ProductMatch.fromJson(Map<String, dynamic> json) {
    return ProductMatch(
      id: json['id']?.toString() ?? newVisualSearchId(),
      productId: json['product_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Ürün',
      brand: json['brand']?.toString() ?? '',
      store: json['store']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      similarityScore: _asDouble(json['similarity_score']),
      matchType: ProductMatchType.values.firstWhere(
        (value) => value.name == json['match_type'],
        orElse: () => ProductMatchType.similar,
      ),
      rating: _asDouble(json['rating']),
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class VisualCatalogItem {
  const VisualCatalogItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.description,
    required this.store,
    required this.price,
    this.imageUrl = '',
    this.rating = 4.5,
    this.reviewCount = 0,
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final String description;
  final String store;
  final String price;
  final String imageUrl;
  final double rating;
  final int reviewCount;
}

class VisualSearchAnalysis {
  const VisualSearchAnalysis({
    required this.summary,
    required this.confidence,
    this.damages = const [],
    this.missingParts = const [],
    this.matches = const [],
    this.usedMock = false,
  });

  final String summary;
  final double confidence;
  final List<DamageDetection> damages;
  final List<MissingPartDetection> missingParts;
  final List<ProductMatch> matches;
  final bool usedMock;

  VisualSearchAnalysis copyWith({bool? usedMock}) {
    return VisualSearchAnalysis(
      summary: summary,
      confidence: confidence,
      damages: damages,
      missingParts: missingParts,
      matches: matches,
      usedMock: usedMock ?? this.usedMock,
    );
  }

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'confidence': confidence,
    'used_mock': usedMock,
    'damages': damages.map((item) => item.toJson()).toList(),
    'missing_parts': missingParts.map((item) => item.toJson()).toList(),
    'matches': matches.map((item) => item.toJson()).toList(),
  };

  factory VisualSearchAnalysis.fromJson(Map<String, dynamic> json) {
    return VisualSearchAnalysis(
      summary: json['summary']?.toString() ?? '',
      confidence: _asDouble(json['confidence']),
      usedMock: json['used_mock'] == true,
      damages: _asList(json['damages'])
          .map((item) => DamageDetection.fromJson(_asMap(item)))
          .toList(),
      missingParts: _asList(json['missing_parts'])
          .map((item) => MissingPartDetection.fromJson(_asMap(item)))
          .toList(),
      matches: _asList(json['matches'])
          .map((item) => ProductMatch.fromJson(_asMap(item)))
          .toList(),
    );
  }
}

class VisualSearchFeedback {
  const VisualSearchFeedback({
    required this.id,
    required this.jobId,
    required this.feedbackType,
    required this.createdAt,
    this.userId,
    this.note,
  });

  final String id;
  final String? userId;
  final String jobId;
  final String feedbackType;
  final String? note;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'job_id': jobId,
    'feedback_type': feedbackType,
    'note': note,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

class VisualSearchJob {
  const VisualSearchJob({
    required this.id,
    required this.fileName,
    required this.jobType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.imageUrl,
    this.previewDataUrl,
    this.analysis,
    this.errorMessage,
    this.savedRemotely = false,
  });

  final String id;
  final String? userId;
  final String fileName;
  final String? imageUrl;
  final String? previewDataUrl;
  final VisualSearchJobType jobType;
  final VisualSearchJobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final VisualSearchAnalysis? analysis;
  final String? errorMessage;
  final bool savedRemotely;

  bool get isProductSearch => jobType == VisualSearchJobType.visualSearch;

  bool get isEmptyResult {
    final result = analysis;
    if (result == null || status != VisualSearchJobStatus.completed) {
      return false;
    }
    if (isProductSearch) return result.matches.isEmpty;
    return result.damages.isEmpty &&
        result.missingParts.isEmpty &&
        result.matches.isEmpty;
  }

  VisualSearchJob copyWith({
    VisualSearchJobStatus? status,
    DateTime? updatedAt,
    String? imageUrl,
    String? previewDataUrl,
    VisualSearchAnalysis? analysis,
    String? errorMessage,
    bool? savedRemotely,
    bool clearError = false,
  }) {
    return VisualSearchJob(
      id: id,
      userId: userId,
      fileName: fileName,
      jobType: jobType,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      previewDataUrl: previewDataUrl ?? this.previewDataUrl,
      analysis: analysis ?? this.analysis,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      savedRemotely: savedRemotely ?? this.savedRemotely,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'file_name': fileName,
    'image_url': imageUrl,
    'preview_data_url': previewDataUrl,
    'job_type': jobType.wireName,
    'status': status.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'analysis_result_json': analysis?.toJson(),
    'error_message': errorMessage,
    'saved_remotely': savedRemotely,
  };

  factory VisualSearchJob.fromJson(Map<String, dynamic> json) {
    final analysisJson = json['analysis_result_json'];
    return VisualSearchJob(
      id: json['id']?.toString() ?? newVisualSearchId(),
      userId: json['user_id']?.toString(),
      fileName: json['file_name']?.toString() ?? 'gorsel.jpg',
      imageUrl: json['image_url']?.toString(),
      previewDataUrl: json['preview_data_url']?.toString(),
      jobType: VisualSearchJobTypeWire.fromWire(json['job_type']?.toString()),
      status: VisualSearchJobStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => VisualSearchJobStatus.pending,
      ),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      analysis: analysisJson is Map
          ? VisualSearchAnalysis.fromJson(Map<String, dynamic>.from(analysisJson))
          : null,
      errorMessage: json['error_message']?.toString(),
      savedRemotely: json['saved_remotely'] == true,
    );
  }
}

double _asDouble(Object? value) => (value as num?)?.toDouble() ?? 0;

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const {};
}

List<dynamic> _asList(Object? value) => value is List ? value : const [];
