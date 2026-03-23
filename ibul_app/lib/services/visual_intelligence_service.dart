import '../core/config/app_feature_flags.dart';

class VisualIntelligenceResultPayload {
  final String previewToken;
  final String detectedProduct;
  final String missingPart;

  const VisualIntelligenceResultPayload({
    required this.previewToken,
    required this.detectedProduct,
    required this.missingPart,
  });
}

class VisualIntelligenceService {
  const VisualIntelligenceService._();

  static VisualIntelligenceResultPayload capturePlaceholder() {
    if (!AppFeatureFlags.enableDemoVisualIntelligence) {
      return const VisualIntelligenceResultPayload(
        previewToken: '',
        detectedProduct: 'Tespit Edilemedi',
        missingPart: 'Bilinmiyor',
      );
    }

    return const VisualIntelligenceResultPayload(
      previewToken: 'mock_image_path',
      detectedProduct: 'Bisiklet',
      missingPart: 'Bisiklet Koltuğu',
    );
  }
}
