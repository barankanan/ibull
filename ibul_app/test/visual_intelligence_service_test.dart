import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/visual_intelligence_service.dart';

void main() {
  test('capturePlaceholder returns stable demo payload', () {
    final payload = VisualIntelligenceService.capturePlaceholder();

    expect(payload.previewToken, isNotEmpty);
    expect(payload.detectedProduct, 'Bisiklet');
    expect(payload.missingPart, 'Bisiklet Koltuğu');
  });
}
