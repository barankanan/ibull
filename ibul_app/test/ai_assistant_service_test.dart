import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/services/ai_assistant_service.dart';

void main() {
  test('returns greeting response for greeting keywords', () {
    expect(AiAssistantService.buildResponse('Merhaba'), contains('Merhaba'));
  });

  test('returns phone guidance for phone-related query', () {
    expect(
      AiAssistantService.buildResponse('Telefon öner'),
      contains('Telefon'),
    );
  });

  test('returns fallback demo response for unknown query', () {
    expect(
      AiAssistantService.buildResponse('Bilinmeyen bir konu'),
      contains('demo'),
    );
  });
}
